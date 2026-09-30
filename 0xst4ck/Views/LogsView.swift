import SwiftUI

struct LogsView: View {
    @EnvironmentObject var log: LogStore
    @EnvironmentObject var ble: BLEManager
    @EnvironmentObject var discord: DiscordSink
    @State private var rawHex: String = "AA CC 00 08 0D 0E 1C 00 14 00 00 00 00 00 64 03 01 02 00 55"
    @State private var showingDiscord: Bool = false
    @State private var pushStatus: String = ""

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            if showingDiscord {
                discordPanel
                Divider().background(Theme.stroke)
            }
            Divider().background(Theme.stroke)
            logList
            Divider().background(Theme.stroke)
            injectPanel
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Text("\(log.entries.count) entries").font(Theme.monoSmall).foregroundColor(Theme.textDim)
            Spacer()
            Button {
                pushToDiscord()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "paperplane.fill").font(.system(size: 10))
                    Text(discord.isConfigured ? "push" : "no wh")
                }
            }
            .buttonStyle(SmallActionButtonStyle())
            .disabled(!discord.isConfigured)
            Button(showingDiscord ? "hide" : "webhook") { showingDiscord.toggle() }
                .buttonStyle(SmallActionButtonStyle())
            Button("clear") { log.clear() }.buttonStyle(SmallActionButtonStyle())
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
    }

    private var discordPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("discord webhook").font(Theme.monoSmall).foregroundColor(Theme.textDim)
            TextField("https://discord.com/api/webhooks/...", text: $discord.webhookURL)
                .font(.system(size: 11, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .padding(8)
                .background(Theme.card)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.stroke))
            Toggle(isOn: $discord.autoPushErrors) {
                Text("auto-push warn/error/sec").font(Theme.monoSmall)
            }
            .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
            HStack {
                Text(discord.lastStatus.isEmpty ? "idle" : discord.lastStatus)
                    .font(Theme.monoSmall).foregroundColor(Theme.textDim)
                Spacer()
                if !pushStatus.isEmpty {
                    Text(pushStatus).font(Theme.monoSmall).foregroundColor(Theme.accent)
                }
            }
        }
        .padding(12)
        .background(Theme.bgElevated)
    }

    private func pushToDiscord() {
        pushStatus = "sending…"
        discord.push(log.entries) { ok, msg in
            pushStatus = ok ? "sent ✓" : "fail: \(msg)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { pushStatus = "" }
        }
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    ForEach(log.entries) { e in
                        row(e).id(e.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: log.entries.count) { _ in
                if let last = log.entries.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private func row(_ e: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(fmt(e.at)).font(Theme.monoSmall).foregroundColor(Theme.textDim).frame(width: 60, alignment: .leading)
            Text(tag(e.kind)).font(Theme.monoSmall).foregroundColor(color(e.kind)).frame(width: 26, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(e.text).font(Theme.monoSmall).foregroundColor(Theme.text)
                if let h = e.hex {
                    Text(h).font(.system(size: 10, design: .monospaced)).foregroundColor(Theme.textDim)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var injectPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("inject raw hex (20 bytes)").font(Theme.monoSmall).foregroundColor(Theme.textDim)
            TextField("AA ..", text: $rawHex)
                .font(.system(size: 11, design: .monospaced))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled(true)
                .padding(8)
                .background(Theme.card)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.stroke))
            HStack {
                Button("compute checksum") { fillChecksum() }.buttonStyle(SmallActionButtonStyle())
                Spacer()
                Button("SEND") { send() }.buttonStyle(SmallActionButtonStyle())
            }
        }
        .padding(12)
        .background(Theme.bgElevated)
    }

    private func fillChecksum() {
        guard var d = Hex.decode(rawHex), d.count == 20 else { return }
        var sum: UInt8 = 0
        for i in 0..<18 { sum = sum &+ d[i] }
        d[18] = sum
        rawHex = Hex.encode(d)
    }

    private func send() {
        guard let d = Hex.decode(rawHex), d.count == 20 else {
            log.warn("raw frame must be 20 bytes")
            return
        }
        ble.sendRaw(d, tag: "inject")
    }

    private func fmt(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"
        return f.string(from: d)
    }

    private func tag(_ k: LogKind) -> String {
        switch k {
        case .info: return "·"
        case .tx:   return "TX"
        case .rx:   return "RX"
        case .warn: return "!"
        case .error:return "✖"
        case .sec:  return "🛡"
        }
    }

    private func color(_ k: LogKind) -> Color {
        switch k {
        case .info: return Theme.textDim
        case .tx:   return Theme.cyan
        case .rx:   return Theme.accent
        case .warn: return Theme.warn
        case .error:return Theme.danger
        case .sec:  return Theme.warn
        }
    }
}
