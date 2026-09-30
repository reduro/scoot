import SwiftUI

/// Simplified UI: one toggle, one slider, one panic button.
/// Everything else lives under "advanced".
struct SecurityView: View {
    @EnvironmentObject var ble: BLEManager
    @State private var showAdvanced = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                guardCard
                capCard
                panicButton

                Button(showAdvanced ? "hide advanced" : "advanced ▾") {
                    withAnimation { showAdvanced.toggle() }
                }
                .buttonStyle(SmallActionButtonStyle())
                .frame(maxWidth: .infinity)

                if showAdvanced { advancedSection }
            }
            .padding(16)
        }
    }

    // MARK: — Main controls

    private var guardCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: guardOn ? "shield.fill" : "shield")
                    .foregroundColor(guardOn ? Theme.accent : Theme.textDim)
                    .font(.system(size: 32))
                VStack(alignment: .leading, spacing: 2) {
                    Text(guardOn ? "GUARD ARMED" : "guard off")
                        .font(.system(.title3, design: .monospaced).weight(.bold))
                        .foregroundColor(guardOn ? Theme.accent : Theme.text)
                    Text(guardOn
                         ? "reactive rebride ON · min 3 s between writes"
                         : "no protection — free ride")
                        .font(Theme.monoSmall)
                        .foregroundColor(Theme.textDim)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { guardOn },
                    set: { on in
                        ble.scooter.antiShortcutEnabled = on
                        ble.updateKeepAliveRate()
                        if on {
                            ble.scooter.params.flags.insert(.speedLimit)
                        }
                    }
                ))
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("what it does").font(Theme.monoSmall).foregroundColor(Theme.textDim)
                Text("• sends your cap ONCE at connect (one bip)").font(Theme.monoSmall).foregroundColor(Theme.text)
                Text("• polls silently the rest of the time").font(Theme.monoSmall).foregroundColor(Theme.text)
                Text("• if measured speed > cap + 3, one rebride (one bip)").font(Theme.monoSmall).foregroundColor(Theme.text)
                Text("• off when app isn't connected — physical scope only").font(Theme.monoSmall).foregroundColor(Theme.warn)
            }
        }
        .cardBg()
    }

    private var capCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("your cap").font(Theme.mono)
                Spacer()
                Text("\(ble.scooter.params.speedLimit) km/h")
                    .font(Theme.mono)
                    .foregroundColor(Theme.accent)
            }
            Slider(value: Binding(
                get: { Double(ble.scooter.params.speedLimit) },
                set: { ble.scooter.params.speedLimit = UInt8(clamping: Int($0)) }
            ), in: 15...45, step: 1)
            HStack {
                capPreset("legal", value: 20)
                capPreset("swiss+", value: 25)
                capPreset("fast", value: 35)
                capPreset("full", value: 45)
            }
        }
        .cardBg()
    }

    private func capPreset(_ label: String, value: UInt8) -> some View {
        Button(action: { ble.scooter.params.speedLimit = value }) {
            Text(label)
                .font(Theme.monoSmall)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(ble.scooter.params.speedLimit == value ? Theme.accent.opacity(0.2) : Theme.card)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(
                    ble.scooter.params.speedLimit == value ? Theme.accent : Theme.stroke
                ))
                .foregroundColor(ble.scooter.params.speedLimit == value ? Theme.accent : Theme.text)
                .cornerRadius(6)
        }
    }

    private var panicButton: some View {
        Button(action: panicLegal) {
            HStack {
                Image(systemName: "hand.raised.fill")
                Text("PANIC · CAP 20").font(Theme.mono.bold())
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(Theme.warn.opacity(0.15))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.warn, lineWidth: 1.5))
            .cornerRadius(10)
            .foregroundColor(Theme.warn)
        }
    }

    // MARK: — Advanced

    private var advancedSection: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("advanced").font(Theme.monoSmall).foregroundColor(Theme.textDim)
                Toggle(isOn: $ble.scooter.legalMode) {
                    Text("legal mode (hard cap 20)").font(Theme.mono)
                }
                .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
                Toggle(isOn: $ble.scooter.punishOnOverspeed) {
                    Text("punish overspeed (send Lock)").font(Theme.mono)
                }
                .toggleStyle(SwitchToggleStyle(tint: Theme.warn))
                if ble.scooter.punishOnOverspeed {
                    HStack {
                        Text("threshold").font(Theme.monoSmall).foregroundColor(Theme.textDim)
                        Spacer()
                        Text("\(ble.scooter.overspeedThreshold) km/h").font(Theme.mono).foregroundColor(Theme.warn)
                    }
                    Slider(value: Binding(
                        get: { Double(ble.scooter.overspeedThreshold) },
                        set: { ble.scooter.overspeedThreshold = Int($0) }
                    ), in: 15...60, step: 1)
                }
            }
            .cardBg()

            Button(action: panicLock) {
                HStack {
                    Image(systemName: "lock.fill")
                    Text("PANIC · FULL LOCK").font(Theme.mono.bold())
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Theme.danger.opacity(0.15))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.danger, lineWidth: 1.5))
                .cornerRadius(10)
                .foregroundColor(Theme.danger)
            }
        }
    }

    // MARK: — Actions

    private var guardOn: Bool { ble.scooter.antiShortcutEnabled }

    private func panicLegal() {
        var p = ble.scooter.params
        p.speedLimit = 20
        p.flags.insert(.speedLimit)
        p.isLocked = false
        ble.scooter.params = p
        ble.sendConfigOneShot(tag: "panic-cap20")
    }

    private func panicLock() {
        var p = ble.scooter.params
        p.isLocked = true
        p.speedLimit = 5
        p.flags.insert(.speedLimit)
        ble.scooter.params = p
        ble.sendConfigOneShot(tag: "panic-lock")
    }
}
