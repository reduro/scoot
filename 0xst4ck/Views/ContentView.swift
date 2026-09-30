import SwiftUI

struct ContentView: View {
    @EnvironmentObject var ble: BLEManager
    @EnvironmentObject var log: LogStore
    @State private var tab: AppTab = .scan

    enum AppTab: Hashable {
        case scan, dashboard, tuning, security, logs
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                Divider().background(Theme.stroke)
                content
                Divider().background(Theme.stroke)
                tabbar
            }
        }
        .foregroundColor(Theme.text)
        .font(Theme.mono)
        .tint(Theme.accent)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("0xst4ck")
                .font(Theme.monoTitle)
                .foregroundColor(Theme.accent)
            Text("v0.1")
                .font(Theme.monoSmall)
                .foregroundColor(Theme.textDim)
            Spacer()
            statusChip
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var statusChip: some View {
        let (color, label) = statusPresentation
        return HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(Theme.monoSmall).foregroundColor(Theme.textDim)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.stroke))
    }

    private var statusPresentation: (Color, String) {
        switch ble.state {
        case .idle:                return (Theme.textDim, "idle")
        case .scanning:            return (Theme.cyan, "scan")
        case .connecting(let n):   return (Theme.warn, "→ \(n)")
        case .discovering:         return (Theme.warn, "discover")
        case .ready:               return (Theme.accent, ble.scooter.authOK ? "authed" : "link")
        case .failed(let e):       return (Theme.danger, e)
        }
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .scan:      ScanView()
        case .dashboard: DashboardView()
        case .tuning:    TuningView()
        case .security:  SecurityView()
        case .logs:      LogsView()
        }
    }

    private var tabbar: some View {
        HStack(spacing: 0) {
            tabButton(.scan,      icon: "antenna.radiowaves.left.and.right", label: "scan")
            tabButton(.dashboard, icon: "gauge.medium",                       label: "dash")
            tabButton(.tuning,    icon: "slider.horizontal.3",                label: "tune")
            tabButton(.security,  icon: "lock.shield",                        label: "sec")
            tabButton(.logs,      icon: "terminal",                            label: "log")
        }
        .background(Theme.bgElevated)
    }

    private func tabButton(_ t: AppTab, icon: String, label: String) -> some View {
        Button(action: { tab = t }) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 18, weight: .medium))
                Text(label).font(Theme.monoSmall)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundColor(tab == t ? Theme.accent : Theme.textDim)
        }
    }
}
