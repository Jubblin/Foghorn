import AppKit
import Foundation

@MainActor
final class OutageLog: ObservableObject {
    static let shared = OutageLog()

    @Published private(set) var records: [OutageRecord] = []

    private let maxRecords = 100
    private let fileURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = appSupport.appendingPathComponent("Foghorn", isDirectory: true)
        Self.migrateLegacyDirectoryIfNeeded(appSupport: appSupport, newDirectory: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("outages.json")
        load()
    }

    /// One-time migration for installs upgrading from the app's former name ("Online").
    /// Moves `~/Library/Application Support/Online` to `.../Foghorn` so existing outage
    /// history survives the rebrand instead of appearing to vanish.
    private static func migrateLegacyDirectoryIfNeeded(appSupport: URL, newDirectory: URL) {
        let legacyDirectory = appSupport.appendingPathComponent("Online", isDirectory: true)
        let fm = FileManager.default
        guard fm.fileExists(atPath: legacyDirectory.path), !fm.fileExists(atPath: newDirectory.path) else { return }
        try? fm.moveItem(at: legacyDirectory, to: newDirectory)
    }

    var lastRecord: OutageRecord? {
        records.first
    }

    func startOutage(_ record: OutageRecord) {
        var updated = records
        updated.insert(record, at: 0)
        records = Array(updated.prefix(maxRecords))
        persist()
    }

    func endOutage(_ record: OutageRecord) {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else {
            var updated = records
            updated.insert(record, at: 0)
            records = Array(updated.prefix(maxRecords))
            persist()
            return
        }

        records[index] = record
        persist()
    }

    func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    func reload() {
        load()
    }

    func copyJSONToPasteboard() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(records),
              let json = String(data: data, encoding: .utf8) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(json, forType: .string)
    }

    var filePath: String {
        fileURL.path
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        records = (try? decoder.decode([OutageRecord].self, from: data)) ?? []
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
