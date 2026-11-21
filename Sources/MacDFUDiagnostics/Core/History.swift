import Foundation
import Observation

/// One finished operation, as the history remembers it.
struct OperationRecord: Codable, Identifiable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case enterDFU
        case restart
        case revive
        case restore
    }

    enum Outcome: String, Codable, Sendable {
        case success
        case failure
        case stopped
    }

    var id = UUID()
    var date = Date()
    let kind: Kind
    let outcome: Outcome
    /// The Mac it was done to, as the window named it at the time.
    let device: String
    let ecid: String?
    let duration: TimeInterval
    /// Untranslated technical detail, when there was any.
    var detail: String?
}

/// What was done to which Mac, and how it ended — kept on this Mac only, across launches.
///
/// A repair bench wants this the day a customer asks "was it revived or restored?". Nothing here
/// leaves the machine: it is a JSON file in Application Support, and Clear deletes it.
@MainActor
@Observable
final class History {
    private(set) var records: [OperationRecord] = []

    @ObservationIgnored private let fileURL: URL?
    private static let limit = 500

    /// - Parameter fileURL: where to keep the records; `nil` keeps them in memory only (demos, tests).
    init(fileURL: URL? = History.defaultFileURL) {
        self.fileURL = fileURL
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return }
        records = (try? Self.decoder.decode([OperationRecord].self, from: data)) ?? []
    }

    nonisolated static var defaultFileURL: URL? {
        try? FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appending(path: "Mac DFU Studio", directoryHint: .isDirectory)
            .appending(path: "History.json")
    }

    func add(_ record: OperationRecord) {
        records.append(record)
        if records.count > Self.limit {
            records.removeFirst(records.count - Self.limit)
        }
        save()
    }

    func clear() {
        records.removeAll()
        if let fileURL { try? FileManager.default.removeItem(at: fileURL) }
    }

    /// The history as a spreadsheet: one row per operation, newest last. Always in English, with
    /// ISO 8601 dates, because it is read by tools as often as by people.
    func csv() -> String {
        let header = "date,operation,outcome,device,ecid,duration_seconds,detail"
        let rows = records.map { record in
            [
                record.date.formatted(.iso8601),
                record.kind.rawValue,
                record.outcome.rawValue,
                record.device,
                record.ecid ?? "",
                String(Int(record.duration.rounded())),
                record.detail ?? "",
            ]
            .map(Self.csvField)
            .joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n") + "\n"
    }

    /// Quotes a field when it needs it, and defuses a leading `=`, `+`, `-` or `@`: a device chooses
    /// part of its own description, and a spreadsheet would run that as a formula.
    nonisolated static func csvField(_ text: String) -> String {
        var value = text
        if let first = value.first, "=+-@\t\r".contains(first) {
            value = "'" + value
        }
        guard value.contains(where: { ",\"\n\r".contains($0) }) else { return value }
        return "\"" + value.replacing("\"", with: "\"\"") + "\""
    }

    private func save() {
        guard let fileURL else { return }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Self.encoder.encode(records).write(to: fileURL, options: .atomic)
        } catch {
            // The history is a convenience: losing a write must never get in the way of the work.
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
