import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var ble: BLEManager

    var body: some View {
        let s = ble.scooter
        ScrollView {
            VStack(spacing: 14) {
                if let at = s.intrusionDetectedAt {
                    intrusionBanner(at: at, summary: s.intrusionSummary)
                }
                bigSpeed(s)
                statRow(s)
                tripRow(s)
                controlRow
                lockPanel(s)
            }
            .padding(16)
        }
    }

    private func intrusionBanner(at: Date, summary: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(Theme.danger)
                Text("INTRUSION DETECTED").font(Theme.mono.bold()).foregroundColor(Theme.danger)
                Spacer()
                Button(action: { ble.scooter.intrusionDetectedAt = nil }) {
                    Image(systemName: "xmark").foregroundColor(Theme.textDim)
                }
            }
            Text(summary).font(Theme.monoSmall).foregroundColor(Theme.text)
            Text("scooter was derestricted physically — auto-healed to your cap")
                .font(Theme.monoSmall).foregroundColor(Theme.textDim)
        }
        .padding(12)
        .background(Theme.danger.opacity(0.15))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.danger, lineWidth: 1.5))
        .cornerRadius(10)
    }

    private var controlRow: some View {
        HStack(spacing: 10) {
            controlButton(label: "gear",
                          icon: "arrow.triangle.2.circlepath",
                          color: Theme.cyan) { ble.cycleGear() }
            controlButton(label: "lamp",
                          icon: ble.scooter.lampOn ? "lightbulb.fill" : "lightbulb",
                          color: ble.scooter.lampOn ? Theme.warn : Theme.textDim) { ble.toggleHeadlight() }
            controlButton(label: "power",
                          icon: "power",
                          color: Theme.accent) { ble.togglePower() }
        }
    }

    private func controlButton(label: String, icon: String, color: Color,
                                action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 22))
                Text(label).font(Theme.monoSmall)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color.opacity(0.10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(color, lineWidth: 1))
            .cornerRadius(10)
            .foregroundColor(color)
        }
    }

    private func bigSpeed(_ s: ScooterState) -> some View {
        VStack(spacing: 2) {
            Text("\(s.driverSpeed)")
                .font(Theme.hugeMono)
                .foregroundColor(s.driverSpeed > 25 ? Theme.warn : Theme.accent)
                .contentTransition(.numericText())
            Text("km/h")
                .font(Theme.monoSmall)
                .foregroundColor(Theme.textDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .cardBg()
    }

    private func statRow(_ s: ScooterState) -> some View {
        HStack(spacing: 10) {
            statTile("BAT",   value: "\(s.driverVolt)%",   color: batColor(s.driverVolt))
            statTile("MODE",  value: "\(s.runSpeed)",       color: Theme.cyan)
            statTile("LAMP",  value: s.lampOn ? "ON" : "off", color: s.lampOn ? Theme.warn : Theme.textDim)
        }
    }

    private func tripRow(_ s: ScooterState) -> some View {
        HStack(spacing: 10) {
            statTile("TRIP",  value: String(format: "%.1f km", s.tripKm), color: Theme.text)
            statTile("ODO",   value: String(format: "%.0f km", s.odoKm),   color: Theme.text)
        }
    }

    private func lockPanel(_ s: ScooterState) -> some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: s.isLocked ? "lock.fill" : "lock.open.fill")
                    .foregroundColor(s.isLocked ? Theme.danger : Theme.accent)
                Text(s.isLocked ? "LOCKED" : "UNLOCKED")
                    .font(Theme.mono)
                    .foregroundColor(s.isLocked ? Theme.danger : Theme.accent)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { s.params.isLocked },
                    set: { new in
                        ble.scooter.params.isLocked = new
                        ble.sendConfig(tag: new ? "lock" : "unlock")
                    }
                )).labelsHidden()
            }
            HStack(spacing: 8) {
                Text("auth")
                    .font(Theme.monoSmall)
                    .foregroundColor(Theme.textDim)
                Circle().fill(s.authOK ? Theme.accent : Theme.danger).frame(width: 8, height: 8)
                Spacer()
                Text("tx=\(s.txCount) rx=\(s.rxCount)")
                    .font(Theme.monoSmall)
                    .foregroundColor(Theme.textDim)
            }
        }
        .cardBg()
    }

    private func statTile(_ label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label).font(Theme.monoSmall).foregroundColor(Theme.textDim)
            Text(value).font(.system(.title2, design: .monospaced).weight(.bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.card)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.stroke))
        .cornerRadius(10)
    }

    private func batColor(_ v: Int) -> Color {
        if v > 40 { return Theme.accent }
        if v > 15 { return Theme.warn }
        return Theme.danger
    }
}
