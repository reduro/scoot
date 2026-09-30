import Foundation

/// Port of Psw_CreateSlavePsw() extracted from the decompiled Gsic app
/// (cn.wch.blecommon.setting#Psw_CreateSlavePsw).
///
///   int p  = pass
///   int i  = p % 1000
///   int i2 = (p / 1000) + (i / 100)
///   int i3 = i % 100
///   slave  = ((p * (i2 + i3/10 + i3%10)) + 370085) ^ 74565
///
/// Matches the controller's expected 6-digit slave password.
enum SlavePassword {
    static func derive(from pass: String) -> String {
        guard let p = Int(pass) else { return "000000" }
        let i  = p % 1000
        let i2 = (p / 1000) + (i / 100)
        let i3 = i % 100
        let raw = ((p * (i2 + (i3 / 10) + (i3 % 10))) + 370_085) ^ 74_565
        // format matches Java: %06d, always positive width
        let safe = raw & 0x7FFFFFFF
        return String(format: "%06d", safe)
    }
}
