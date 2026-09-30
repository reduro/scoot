import SwiftUI

struct SecurityView: View {
    @EnvironmentObject var ble: BLEManager

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                title("🇨🇭 LEGAL MODE")
                legalCard

                title("ANTI-SHORTCUT (brake+start)")
                antiShortcutCard

                title("OVERSPEED PUNISH")
                punishCard

                title("PANIC")
                panicCard
            }
            .padding(16)
        }
    }

    private func title(_ t: String) -> some View {
        HStack {
            Text(t).font(Theme.monoSmall).foregroundColor(Theme.textDim)
            Rectangle().fill(Theme.stroke).frame(height: 1)
        }
    }

    private var legalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: Binding(
                get: { ble.scooter.legalMode },
                set: { on in
                    ble.scooter.legalMode = on
                    if on { ble.scooter.params.flags.insert(.speedLimit) }
                }
            )) {
                Text(ble.scooter.legalMode ? "🟢 legal mode ON" : "◯ legal mode off")
                    .font(Theme.mono)
                    .foregroundColor(ble.scooter.legalMode ? Theme.accent : Theme.text)
            }
            .toggleStyle(SwitchToggleStyle(tint: Theme.accent))

            Text("caps speed_limit to 20 km/h at every tick — regardless of tuning tab.")
                .font(Theme.monoSmall).foregroundColor(Theme.textDim)
        }
        .cardBg()
    }

    private var antiShortcutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: Binding(
                get: { ble.scooter.antiShortcutEnabled },
                set: { on in
                    ble.scooter.antiShortcutEnabled = on
                    ble.updateKeepAliveRate()
                }
            )) {
                Text(ble.scooter.antiShortcutEnabled ? "🛡 anti-shortcut ON (0.5s tick)" : "◯ anti-shortcut off (1s tick)")
                    .font(Theme.mono)
                    .foregroundColor(ble.scooter.antiShortcutEnabled ? Theme.accent : Theme.text)
            }
            .toggleStyle(SwitchToggleStyle(tint: Theme.accent))

            Text("reactive rebride: silent polling ; write only when measured speed exceeds the cap. min 3 s between interventions — no bip spam.")
                .font(Theme.monoSmall).foregroundColor(Theme.textDim)
        }
        .cardBg()
    }

    private var punishCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $ble.scooter.punishOnOverspeed) {
                Text(ble.scooter.punishOnOverspeed ? "⚠ punish ON" : "◯ punish off")
                    .font(Theme.mono)
            }
            .toggleStyle(SwitchToggleStyle(tint: Theme.warn))

            HStack {
                Text("threshold").font(Theme.monoSmall).foregroundColor(Theme.textDim)
                Spacer()
                Text("\(ble.scooter.overspeedThreshold) km/h").font(Theme.mono).foregroundColor(Theme.warn)
            }
            Slider(value: Binding(
                get: { Double(ble.scooter.overspeedThreshold) },
                set: { ble.scooter.overspeedThreshold = Int($0) }
            ), in: 15...60, step: 1)

            Text("if measured speed > threshold, sends Lock=1 until back below. useful if the hardware combo was triggered without your consent.")
                .font(Theme.monoSmall).foregroundColor(Theme.textDim)
        }
        .cardBg()
    }

    private var panicCard: some View {
        VStack(spacing: 10) {
            Button(action: panicLegal) {
                HStack {
                    Image(systemName: "hand.raised.fill")
                    Text("PANIC LEGAL").font(Theme.mono.bold())
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Theme.accent.opacity(0.15))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.accent, lineWidth: 1.5))
                .cornerRadius(10)
                .foregroundColor(Theme.accent)
            }
            Button(action: panicLock) {
                HStack {
                    Image(systemName: "lock.fill")
                    Text("PANIC LOCK").font(Theme.mono.bold())
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Theme.danger.opacity(0.15))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.danger, lineWidth: 1.5))
                .cornerRadius(10)
                .foregroundColor(Theme.danger)
            }
        }
    }

    private func panicLegal() {
        var p = ble.scooter.params
        p.speedLimit = 20
        p.strongLimit = min(p.strongLimit, 3)
        p.flags.insert(.speedLimit)
        p.isLocked = false
        ble.scooter.params = p
        ble.scooter.legalMode = true
        ble.sendConfig(p, tag: "panic-legal")
    }

    private func panicLock() {
        var p = ble.scooter.params
        p.isLocked = true
        p.speedLimit = 5
        p.strongLimit = 1
        p.flags.insert(.speedLimit)
        ble.scooter.params = p
        ble.sendConfig(p, tag: "panic-lock")
    }
}
