import Foundation
import CoreBluetooth
import Combine

// UUIDs pulled straight from MainActivity.java of the decompiled Gsic app.
enum ScooterUUIDs {
    // The controller advertises a service that reuses the SPP 16-bit UUID (0x1101).
    static let service       = CBUUID(string: "00001101-0000-1000-8000-00805F9B34FB")
    // Write + read use the same characteristic (FFE1).
    static let writeChar     = CBUUID(string: "0000FFE1-0000-1000-8000-00805F9B34FB")
    // Notifications with live telemetry come from FFE4.
    static let notifyChar    = CBUUID(string: "0000FFE4-0000-1000-8000-00805F9B34FB")
    // Extra short-form for peripherals advertising only the 16-bit form.
    static let service16     = CBUUID(string: "1101")
    static let writeChar16   = CBUUID(string: "FFE1")
    static let notifyChar16  = CBUUID(string: "FFE4")
}

struct DiscoveredDevice: Identifiable, Hashable {
    let id: UUID
    let name: String
    let rssi: Int
    let peripheral: CBPeripheral

    static func == (l: DiscoveredDevice, r: DiscoveredDevice) -> Bool { l.id == r.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum ConnectionState: Equatable {
    case idle
    case scanning
    case connecting(String)
    case discovering
    case ready
    case failed(String)
}

final class BLEManager: NSObject, ObservableObject {

    // Public state
    @Published var state: ConnectionState = .idle
    @Published var devices: [DiscoveredDevice] = []
    @Published var scooter = ScooterState()

    // BLE core
    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writeCh: CBCharacteristic?
    private var notifyCh: CBCharacteristic?

    // Keepalive / rebride loop
    private var keepAliveTimer: Timer?
    private var keepAlivePeriod: TimeInterval = 1.0   // 1s ; anti-shortcut mode ⇒ 0.5s

    // Log
    private weak var log: LogStore?

    // Forward nested ObservableObject changes so views re-render.
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
        scooter.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func attach(log: LogStore) {
        self.log = log
        log.info("0xst4ck booted")
    }

    // MARK: — Scan

    func startScan() {
        guard central.state == .poweredOn else {
            log?.warn("BLE not powered on yet ; state=\(central.state.rawValue)")
            return
        }
        devices.removeAll()
        state = .scanning
        // Some Chinese controllers don't advertise their service UUID —
        // scan wide, filter by name+services in didDiscover.
        central.scanForPeripherals(withServices: nil,
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        log?.info("scan started")
    }

    func stopScan() {
        central.stopScan()
        if case .scanning = state { state = .idle }
        log?.info("scan stopped")
    }

    // MARK: — Connect

    func connect(_ dev: DiscoveredDevice) {
        stopScan()
        peripheral = dev.peripheral
        peripheral?.delegate = self
        state = .connecting(dev.name)
        log?.info("connecting to \(dev.name) [\(dev.id.uuidString.prefix(8))]")
        central.connect(dev.peripheral, options: nil)
    }

    func disconnect(gracefully: Bool = true) {
        stopKeepAlive()
        if gracefully, scooter.antiShortcutEnabled, let peripheral, let writeCh {
            // Final "legal-lock" push before we drop the link.
            var p = scooter.params
            p.speedLimit = 20
            p.strongLimit = 1
            p.isLocked = true
            p.flags.insert(.speedLimit)
            let frame = ProtocolCodec.buildConfig(p)
            peripheral.writeValue(frame, for: writeCh, type: .withoutResponse)
            log?.tx(frame, tag: "graceful-lock")
            log?.sec("sent legal-lock frame before disconnect")
        }
        if let p = peripheral { central.cancelPeripheralConnection(p) }
    }

    // MARK: — Send helpers

    func sendConfig(_ params: ConfigParams? = nil, tag: String = "config") {
        guard let peripheral, let writeCh else { return }
        let frame = ProtocolCodec.buildConfig(params ?? scooter.params)
        peripheral.writeValue(frame, for: writeCh, type: .withoutResponse)
        log?.tx(frame, tag: tag)
        scooter.lastTxAt = Date()
        scooter.txCount += 1
    }

    func sendAuth() {
        guard let peripheral, let writeCh else { return }
        let frame = ProtocolCodec.buildAuth(masterPass: scooter.masterPass,
                                            guestPass: scooter.guestPass)
        peripheral.writeValue(frame, for: writeCh, type: .withoutResponse)
        log?.tx(frame, tag: "auth")
        scooter.lastTxAt = Date()
        scooter.txCount += 1
    }

    func sendRaw(_ data: Data, tag: String = "raw") {
        guard let peripheral, let writeCh else {
            log?.warn("no writable characteristic")
            return
        }
        peripheral.writeValue(data, for: writeCh, type: .withoutResponse)
        log?.tx(data, tag: tag)
        scooter.lastTxAt = Date()
        scooter.txCount += 1
    }

    // MARK: — Keepalive loop

    private func startKeepAlive() {
        stopKeepAlive()
        keepAlivePeriod = scooter.antiShortcutEnabled ? 0.5 : 1.0
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: keepAlivePeriod, repeats: true) { [weak self] _ in
            self?.keepAliveTick()
        }
        log?.info("keepalive loop ↺ \(Int(keepAlivePeriod * 1000))ms")
    }

    private func stopKeepAlive() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil
    }

    private func keepAliveTick() {
        var p = scooter.params

        if scooter.legalMode {
            p.speedLimit = 20
            p.flags.insert(.speedLimit)
        }

        // Punish overspeed by temporarily locking
        if scooter.punishOnOverspeed && scooter.driverSpeed > scooter.overspeedThreshold {
            p.isLocked = true
            log?.sec("OVERSPEED \(scooter.driverSpeed) > \(scooter.overspeedThreshold) → lock")
        }

        sendConfig(p, tag: "tick")

        // Send auth periodically to keep the controller session alive (~ every 5s).
        if scooter.txCount % 5 == 0 {
            sendAuth()
        }
    }

    func updateKeepAliveRate() {
        if keepAliveTimer != nil { startKeepAlive() }
    }
}

// MARK: — Central delegate

extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        log?.info("central state = \(central.state.rawValue)")
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "unknown"
        // Filter obvious noise
        guard name != "unknown" || RSSI.intValue > -80 else { return }

        let dev = DiscoveredDevice(id: peripheral.identifier, name: name,
                                    rssi: RSSI.intValue, peripheral: peripheral)
        if !devices.contains(where: { $0.id == dev.id }) {
            devices.append(dev)
            devices.sort { $0.rssi > $1.rssi }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        log?.info("connected ; discovering services…")
        state = .discovering
        peripheral.discoverServices([ScooterUUIDs.service, ScooterUUIDs.service16])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        state = .failed(error?.localizedDescription ?? "connect failed")
        log?.error("connect failed: \(error?.localizedDescription ?? "?")")
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        stopKeepAlive()
        writeCh = nil
        notifyCh = nil
        scooter.authOK = false
        state = .idle
        log?.warn("disconnected")
    }
}

// MARK: — Peripheral delegate

extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for s in peripheral.services ?? [] {
            log?.info("service \(s.uuid.uuidString)")
            peripheral.discoverCharacteristics(nil, for: s)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for c in service.characteristics ?? [] {
            let u = c.uuid
            log?.info("  char \(u.uuidString) props=\(c.properties.rawValue)")
            if u == ScooterUUIDs.writeChar || u == ScooterUUIDs.writeChar16 {
                writeCh = c
            }
            if u == ScooterUUIDs.notifyChar || u == ScooterUUIDs.notifyChar16 {
                notifyCh = c
                peripheral.setNotifyValue(true, for: c)
            }
        }
        if writeCh != nil && notifyCh != nil {
            state = .ready
            log?.info("link ready")
            sendAuth()
            startKeepAlive()
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard let data = characteristic.value else { return }
        log?.rx(data)
        scooter.lastRxAt = Date()
        scooter.rxCount += 1
        if let frame = ProtocolCodec.parse(data) {
            switch frame {
            case .authOK:
                scooter.authOK = true
                log?.info("auth OK")
            case .configResponse(let p):
                scooter.applyConfigResponse(p)
                log?.info("config response ; SpeedLimit=\(p.speedLimit) StrongLimit=\(p.strongLimit)")
            case .status(let s):
                scooter.applyStatus(s)
            case .unknown(let op):
                log?.warn("unknown opcode 0x\(String(op, radix: 16, uppercase: true))")
            }
        } else {
            log?.warn("invalid/short frame")
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let e = error { log?.error("write err: \(e.localizedDescription)") }
    }
}
