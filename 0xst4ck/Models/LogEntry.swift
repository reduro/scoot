import Foundation
import Combine

enum LogKind: String, Codable {
    case info, tx, rx, warn, error, sec
}

struct LogEntry: Identifiable, Hashable {
    let id = UUID()
    let at: Date
    let kind: LogKind
    let text: String
    let hex: String?
}

final class LogStore: ObservableObject {
    @Published private(set) var entries: [LogEntry] = []
    private let maxEntries = 500

    func log(_ kind: LogKind, _ text: String, hex: String? = nil) {
        entries.append(LogEntry(at: Date(), kind: kind, text: text, hex: hex))
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    func info(_ t: String)         { log(.info, t) }
    func warn(_ t: String)         { log(.warn, t) }
    func error(_ t: String)        { log(.error, t) }
    func sec(_ t: String)          { log(.sec, t) }
    func tx(_ data: Data, tag: String = "") {
        log(.tx, tag.isEmpty ? "→" : "→ \(tag)", hex: Hex.encode(data))
    }
    func rx(_ data: Data, tag: String = "") {
        log(.rx, tag.isEmpty ? "←" : "← \(tag)", hex: Hex.encode(data))
    }

    func clear() { entries.removeAll() }
}
