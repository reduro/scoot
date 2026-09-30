import Foundation
import Combine

final class ScooterState: ObservableObject {
    // Live telemetry
    @Published var driverSpeed: Int = 0        // km/h (or MPH if flag)
    @Published var driverVolt: Int = 0         // battery %
    @Published var runSpeed: Int = 0           // ride mode 1/2/3
    @Published var lampOn: Bool = false
    @Published var tripKm: Float = 0
    @Published var odoKm: Float = 0
    @Published var isLocked: Bool = false
    @Published var authOK: Bool = false

    // Tunable params (locally applied ; pushed on each tick)
    @Published var params = ConfigParams()

    // Security
    @Published var antiShortcutEnabled: Bool = false
    @Published var legalMode: Bool = false
    @Published var punishOnOverspeed: Bool = false
    @Published var overspeedThreshold: Int = 25

    // Auth
    @Published var masterPass: String = "0000"
    @Published var guestPass: String  = "000000"

    // Live stats
    @Published var lastRxAt: Date? = nil
    @Published var lastTxAt: Date? = nil
    @Published var txCount: Int = 0
    @Published var rxCount: Int = 0

    func applyStatus(_ s: StatusReading) {
        driverSpeed = Int(s.driverSpeed)
        driverVolt  = Int(s.driverVolt)
        runSpeed    = Int(s.runSpeed)
        lampOn      = s.lampStatus != 0
        tripKm      = s.tripKm
        odoKm       = s.odoKm
        isLocked    = s.isLocked
    }

    func applyConfigResponse(_ p: ConfigParams) {
        params.speedLimit  = p.speedLimit
        params.strongLimit = p.strongLimit
        params.wheelSize   = p.wheelSize
        params.batteryNum  = p.batteryNum
        params.poleNum     = p.poleNum
        params.poleNum2    = p.poleNum2
        params.flags       = p.flags
    }
}
