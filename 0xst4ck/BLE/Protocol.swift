import Foundation

// ─────────────────────────────────────────────────────────────
//  Reverse-engineered protocol for the Gsic/Speedmaster/WCH
//  scooter controller. Frame is fixed 20 bytes:
//
//    [0]  0xAA header
//    [1]  opcode
//    [2]  arg
//    [3]  flags (bit0 MPH, bit1 NonZero, bit2 Cruise, bit3 SpeedLimit)
//    [4]  Battery cells
//    [5]  Pole num
//    [6]  Pole num 2
//    [7]  Pole operation status
//    [8]  Speed limit (km/h)
//    [9]  Odo clear
//    [14] Wheel size (1/10 inch)
//    [15] Strong limit (torque cap)
//    [16] Config OK
//    [17] Lock flag (1 = lock, 2 = unlock)
//    [18] Checksum = sum(bytes 0..17) mod 256
//    [19] 0x55 footer
// ─────────────────────────────────────────────────────────────

enum Opcode: UInt8 {
    case config          = 0xCC  // set params + lock/unlock
    case setPassword     = 0xDD
    case bleName         = 0xFF
    case auth            = 0xEE
    case configResponse  = 0xBB
}

struct FrameFlags: OptionSet {
    let rawValue: UInt8
    static let mph        = FrameFlags(rawValue: 1 << 0)
    static let nonZero    = FrameFlags(rawValue: 1 << 1)
    static let cruise     = FrameFlags(rawValue: 1 << 2)
    static let speedLimit = FrameFlags(rawValue: 1 << 3)
}

struct ConfigParams {
    var speedLimit: UInt8       = 20
    var strongLimit: UInt8      = 3
    var wheelSize: UInt8        = 100
    var batteryNum: UInt8       = 13
    var poleNum: UInt8          = 14
    var poleNum2: UInt8         = 28
    var poleOpStatus: UInt8     = 0
    var flags: FrameFlags       = [.nonZero, .speedLimit]
    var isLocked: Bool          = false
    var odoClear: Bool          = false
    var configOK: Bool          = true
}

enum ProtocolCodec {

    // MARK: — Frame builders

    static func buildConfig(_ p: ConfigParams,
                            opcode: UInt8 = Opcode.config.rawValue,
                            arg: UInt8 = 0) -> Data {
        var b = [UInt8](repeating: 0, count: 20)
        b[0]  = 0xAA
        b[1]  = opcode
        b[2]  = arg
        b[3]  = p.flags.rawValue
        b[4]  = p.batteryNum
        b[5]  = p.poleNum
        b[6]  = p.poleNum2
        b[7]  = p.poleOpStatus
        b[8]  = p.speedLimit
        b[9]  = p.odoClear ? 1 : 0
        b[14] = p.wheelSize
        b[15] = p.strongLimit
        b[16] = p.configOK ? 1 : 0
        b[17] = p.isLocked ? 1 : 2
        b[19] = 0x55
        b[18] = 0
        var sum: UInt8 = 0
        for i in 0..<18 { sum = sum &+ b[i] }
        b[18] = sum
        return Data(b)
    }

    /// Auth frame — opcode 0xEE. Sends the 4-digit password concatenated
    /// with its derived 6-digit slave password, then the 6-char guest pass.
    static func buildAuth(masterPass: String, guestPass: String) -> Data {
        var b = [UInt8](repeating: 0, count: 20)
        b[0]  = 0xAA
        b[1]  = Opcode.auth.rawValue
        b[19] = 0x55

        let slave = SlavePassword.derive(from: masterPass)
        let combined = Array((masterPass + slave).utf8)
        if combined.count == 10 {
            for i in 0..<10 { b[2 + i] = combined[i] }
        }
        let g = Array(guestPass.utf8)
        if g.count == 6 {
            for i in 0..<6 { b[12 + i] = g[i] }
        }
        var sum: UInt8 = 0
        for i in 0..<18 { sum = sum &+ b[i] }
        b[18] = sum
        return Data(b)
    }

    /// Password-write frame — opcode 0xDD. bArr[6..9] carries the new 4-byte pass.
    static func buildSetPassword(newPass: String, currentPass: String, isLocked: Bool) -> Data {
        var b = [UInt8](repeating: 0, count: 20)
        b[0] = 0xAA
        b[1] = Opcode.setPassword.rawValue
        let cur = Array(currentPass.utf8)
        if cur.count >= 4 { for i in 0..<4 { b[2 + i] = cur[i] } }
        let np = Array(newPass.utf8)
        if np.count >= 4 { for i in 0..<4 { b[6 + i] = np[i] } }
        b[17] = isLocked ? 1 : 2
        b[19] = 0x55
        var sum: UInt8 = 0
        for i in 0..<18 { sum = sum &+ b[i] }
        b[18] = sum
        return Data(b)
    }

    // MARK: — Frame parsers

    static func validate(_ data: Data) -> Bool {
        guard data.count == 20 else { return false }
        let b = [UInt8](data)
        guard b[0] == 0xAA, b[19] == 0x55 else { return false }
        var sum: UInt8 = 0
        for i in 0..<18 { sum = sum &+ b[i] }
        return sum == b[18]
    }

    enum RxFrame {
        case authOK
        case configResponse(ConfigParams)
        case status(StatusReading)
        case unknown(opcode: UInt8)
    }

    static func parse(_ data: Data) -> RxFrame? {
        guard validate(data) else { return nil }
        let b = [UInt8](data)
        switch b[1] {
        case Opcode.auth.rawValue:
            return .authOK
        case Opcode.configResponse.rawValue:
            var p = ConfigParams()
            p.flags = FrameFlags(rawValue: b[3])
            p.batteryNum = b[4]
            p.poleNum = b[5]
            p.poleNum2 = b[6]
            p.speedLimit = b[8]
            p.wheelSize = b[9]
            p.strongLimit = b[10]
            return .configResponse(p)
        default:
            var s = StatusReading()
            s.runSpeed = b[3]
            s.driverSpeed = (UInt16(b[4]) << 8) | UInt16(b[5])
            s.lampStatus = b[6]
            s.driverVolt = (UInt16(b[7]) << 8) | UInt16(b[8])
            s.tripKm = float32LE([b[9], b[10], b[11], b[12]])
            s.odoKm  = float32LE([b[13], b[14], b[15], b[16]])
            s.isLocked = (b[17] & 0xFF) == 1
            return .status(s)
        }
    }

    private static func float32LE(_ b: [UInt8]) -> Float {
        let bits = (UInt32(b[0])) |
                   (UInt32(b[1]) << 8) |
                   (UInt32(b[2]) << 16) |
                   (UInt32(b[3]) << 24)
        return Float(bitPattern: bits)
    }
}

struct StatusReading {
    var runSpeed: UInt8 = 0
    var driverSpeed: UInt16 = 0
    var lampStatus: UInt8 = 0
    var driverVolt: UInt16 = 0
    var tripKm: Float = 0
    var odoKm: Float = 0
    var isLocked: Bool = false
}

// MARK: — Hex helpers

enum Hex {
    static func encode(_ data: Data) -> String {
        data.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
    static func decode(_ s: String) -> Data? {
        let clean = s.filter { !$0.isWhitespace && $0 != ":" }
        guard clean.count.isMultiple(of: 2) else { return nil }
        var out = [UInt8]()
        var idx = clean.startIndex
        while idx < clean.endIndex {
            let next = clean.index(idx, offsetBy: 2)
            guard let b = UInt8(clean[idx..<next], radix: 16) else { return nil }
            out.append(b)
            idx = next
        }
        return Data(out)
    }
}
