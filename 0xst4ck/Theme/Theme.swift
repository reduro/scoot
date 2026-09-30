import SwiftUI

enum Theme {
    static let bg          = Color(red: 0.04, green: 0.05, blue: 0.06)   // near-black
    static let bgElevated  = Color(red: 0.08, green: 0.09, blue: 0.11)
    static let card        = Color(red: 0.10, green: 0.11, blue: 0.13)
    static let stroke      = Color(red: 0.18, green: 0.20, blue: 0.24)
    static let text        = Color(red: 0.90, green: 0.92, blue: 0.94)
    static let textDim     = Color(red: 0.55, green: 0.58, blue: 0.62)
    static let accent      = Color(red: 0.72, green: 1.00, blue: 0.24)   // sodium green #B8FF3D
    static let danger      = Color(red: 1.00, green: 0.25, blue: 0.30)
    static let warn        = Color(red: 1.00, green: 0.72, blue: 0.10)
    static let cyan        = Color(red: 0.30, green: 0.92, blue: 1.00)

    static let mono = Font.system(.body, design: .monospaced)
    static let monoSmall = Font.system(.caption, design: .monospaced)
    static let monoTitle = Font.system(size: 28, weight: .bold, design: .monospaced)
    static let hugeMono  = Font.system(size: 96, weight: .heavy, design: .monospaced)
}

struct CardBg: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.stroke, lineWidth: 1)
                    )
            )
    }
}

extension View {
    func cardBg() -> some View { modifier(CardBg()) }
}
