import SwiftUI

struct ScanView: View {
    @EnvironmentObject var ble: BLEManager

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("nearby devices")
                    .font(Theme.mono)
                    .foregroundColor(Theme.textDim)
                Spacer()
                scanButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if ble.devices.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(ble.devices) { dev in
                            deviceRow(dev)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            Spacer()
        }
    }

    private var scanButton: some View {
        Button(action: {
            if case .scanning = ble.state {
                ble.stopScan()
            } else {
                ble.startScan()
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.clockwise")
                Text(isScanning ? "stop" : "scan").font(Theme.mono)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Theme.card)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.accent, lineWidth: 1))
            .cornerRadius(6)
            .foregroundColor(Theme.accent)
        }
    }

    private var isScanning: Bool {
        if case .scanning = ble.state { return true }
        return false
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 40))
                .foregroundColor(Theme.textDim)
            Text(isScanning ? "listening…" : "tap scan to look for the controller")
                .font(Theme.monoSmall)
                .foregroundColor(Theme.textDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func deviceRow(_ dev: DiscoveredDevice) -> some View {
        Button(action: { ble.connect(dev) }) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(dev.name).font(Theme.mono).foregroundColor(Theme.text)
                    Text(dev.id.uuidString.prefix(8) + "…")
                        .font(Theme.monoSmall)
                        .foregroundColor(Theme.textDim)
                }
                Spacer()
                Text("\(dev.rssi) dBm")
                    .font(Theme.monoSmall)
                    .foregroundColor(rssiColor(dev.rssi))
            }
            .cardBg()
        }
        .buttonStyle(.plain)
    }

    private func rssiColor(_ rssi: Int) -> Color {
        if rssi > -60 { return Theme.accent }
        if rssi > -80 { return Theme.warn }
        return Theme.danger
    }
}
