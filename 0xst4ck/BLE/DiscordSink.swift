import Foundation
import Combine

/// Ships log entries to a Discord webhook so debug sessions can be
/// pasted back to me in one shot.
///
/// The user pastes the webhook URL in the Logs tab. The URL is persisted
/// with UserDefaults (per-device). Messages are batched: Discord limits
/// content to 2000 chars and 30 requests/minute per webhook.
final class DiscordSink: ObservableObject {

    @Published var webhookURL: String {
        didSet { UserDefaults.standard.set(webhookURL, forKey: Self.key) }
    }

    @Published var autoPushErrors: Bool {
        didSet { UserDefaults.standard.set(autoPushErrors, forKey: Self.autoKey) }
    }

    @Published var lastStatus: String = ""

    private static let key = "discord.webhook.url"
    private static let autoKey = "discord.autoPushErrors"

    init() {
        self.webhookURL = UserDefaults.standard.string(forKey: Self.key) ?? ""
        self.autoPushErrors = UserDefaults.standard.bool(forKey: Self.autoKey)
    }

    var isConfigured: Bool {
        !webhookURL.isEmpty && URL(string: webhookURL) != nil
    }

    /// POST a batch of log entries. Splits into ≤ 1900-char chunks.
    func push(_ entries: [LogEntry],
              header: String? = nil,
              completion: @escaping (Bool, String) -> Void = { _, _ in }) {
        guard isConfigured, let url = URL(string: webhookURL) else {
            completion(false, "webhook URL missing")
            return
        }

        let lines = entries.suffix(200).map(Self.format)
        var chunks: [String] = []
        var buf = ""
        for l in lines {
            if buf.count + l.count + 1 > 1850 {
                chunks.append(buf)
                buf = ""
            }
            if !buf.isEmpty { buf.append("\n") }
            buf.append(l)
        }
        if !buf.isEmpty { chunks.append(buf) }

        if chunks.isEmpty {
            completion(false, "nothing to send")
            return
        }

        let deviceHeader = header ?? "0xst4ck log ・ \(Date().ISO8601Format())"

        sendChunks(chunks, prefix: deviceHeader, url: url, completion: completion)
    }

    private func sendChunks(_ chunks: [String], prefix: String, url: URL,
                            completion: @escaping (Bool, String) -> Void) {
        var pending = chunks
        var index = 0
        let total = chunks.count

        func next() {
            guard !pending.isEmpty else {
                DispatchQueue.main.async {
                    self.lastStatus = "sent \(total) chunk(s)"
                    completion(true, "ok")
                }
                return
            }
            index += 1
            let chunk = pending.removeFirst()
            let content = "**[\(index)/\(total)] \(prefix)**\n```\n\(chunk)\n```"

            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(
                withJSONObject: ["content": content, "username": "0xst4ck"])

            URLSession.shared.dataTask(with: req) { _, resp, err in
                if let err = err {
                    DispatchQueue.main.async {
                        self.lastStatus = "err: \(err.localizedDescription)"
                        completion(false, err.localizedDescription)
                    }
                    return
                }
                if let http = resp as? HTTPURLResponse, http.statusCode >= 300 {
                    DispatchQueue.main.async {
                        self.lastStatus = "http \(http.statusCode)"
                        completion(false, "http \(http.statusCode)")
                    }
                    return
                }
                // Discord rate limit: crude 400 ms pacing between chunks.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { next() }
            }.resume()
        }
        next()
    }

    private static func format(_ e: LogEntry) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"
        let t = f.string(from: e.at)
        let tag: String
        switch e.kind {
        case .info: tag = "·"
        case .tx:   tag = "→"
        case .rx:   tag = "←"
        case .warn: tag = "!"
        case .error:tag = "✖"
        case .sec:  tag = "🛡"
        }
        var s = "\(t) \(tag) \(e.text)"
        if let h = e.hex { s.append("  \(h)") }
        return s
    }
}
