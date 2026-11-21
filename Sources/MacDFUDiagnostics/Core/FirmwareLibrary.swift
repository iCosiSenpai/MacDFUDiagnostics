import Foundation

/// A macOS restore image that IPSW Downloader Plus keeps on this Mac.
struct LibraryFirmware: Identifiable, Equatable, Sendable {
    let url: URL
    /// The macOS version and build in the file's name, when the name says them.
    let version: String?
    let build: String?
    let sizeBytes: Int64
    /// Whether Apple still signed this build when the other app last looked; `nil` when it does not know.
    let signed: Bool?

    var id: String { url.path(percentEncoded: false) }

    /// "macOS 26.1 (25B78)", or the file's name when it does not say.
    var title: String {
        guard let version else { return url.lastPathComponent }
        return build.map { "macOS \(version) (\($0))" } ?? "macOS \(version)"
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

/// The firmware library of IPSW Downloader Plus, the sibling app that downloads restore images.
///
/// That app writes a small file listing the Mac firmware it keeps and which Macs each image is for
/// (`CompanionLink` there). This reads it, so the restore sheet can offer what is already on this Mac
/// without either app being told about the other's folders.
///
/// The file is another program's output and is treated as such: nothing in it is taken on trust. An
/// entry is used only if it names a readable `.ipsw` by absolute path, and `cfgutil` checks the image
/// against the Mac before it writes anything.
enum FirmwareLibrary {
    /// The only layout this version understands. A file that says anything else is left alone.
    static let supportedVersion = 1
    /// Larger than any real library's list, and small enough to read without a thought.
    private static let maximumIndexBytes = 1_000_000
    private static let maximumEntries = 500

    static var indexURL: URL {
        URL.homeDirectory
            .appending(path: "Library/Application Support/IPSW Downloader Plus/Companion/mac-firmware.json")
    }

    /// `Mac16,1`, `MacBookPro18,3`: letters, then digits, a comma, digits. Nothing else — it ends up in
    /// a URL handed to another app.
    static func isModelIdentifier(_ text: String) -> Bool {
        text.wholeMatch(of: /[A-Za-z]{2,20}[0-9]{1,3},[0-9]{1,3}/) != nil
    }

    /// The restore images in the library that fit a Mac model, the ones Apple still signs first and
    /// the newest first among those. Empty when the other app is not installed or keeps none.
    static func firmware(for identifier: String, indexURL: URL = indexURL) -> [LibraryFirmware] {
        guard let size = (try? indexURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize,
              size <= maximumIndexBytes,
              let data = try? Data(contentsOf: indexURL) else { return [] }
        return firmware(for: identifier, in: data, isUsable: DiagnosticsEngine.isFirmwareFile)
    }

    /// The same, from the file's contents. `isUsable` says whether a file can be handed to `cfgutil`.
    static func firmware(for identifier: String, in data: Data, isUsable: (URL) -> Bool) -> [LibraryFirmware] {
        guard let index = try? JSONDecoder().decode(Index.self, from: data),
              index.version == supportedVersion else { return [] }

        let matches = index.firmware.prefix(maximumEntries).compactMap { entry -> LibraryFirmware? in
            guard entry.identifiers.contains(identifier), entry.path.hasPrefix("/") else { return nil }
            let url = URL(filePath: entry.path).standardizedFileURL
            guard url.pathExtension.lowercased() == "ipsw", isUsable(url) else { return nil }
            return LibraryFirmware(
                url: url, version: entry.version, build: entry.build,
                sizeBytes: max(0, entry.sizeBytes), signed: entry.signed
            )
        }
        return matches.sorted { lhs, rhs in
            // An image Apple no longer signs cannot be restored, so it goes last however new it is.
            let lhsSigned = lhs.signed != false, rhsSigned = rhs.signed != false
            if lhsSigned != rhsSigned { return lhsSigned }
            return (lhs.version ?? "").compare(rhs.version ?? "", options: .numeric) == .orderedDescending
        }
    }

    /// The other app's file. Only the fields used here; anything else in it is ignored.
    private struct Index: Decodable {
        struct Entry: Decodable {
            let path: String
            let version: String?
            let build: String?
            let sizeBytes: Int64
            let identifiers: [String]
            let signed: Bool?
        }

        let version: Int
        let firmware: [Entry]
    }
}
