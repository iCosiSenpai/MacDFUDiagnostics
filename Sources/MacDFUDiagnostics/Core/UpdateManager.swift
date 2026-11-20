import AppKit
import Foundation
import Observation

/// A release published on GitHub.
struct AppRelease: Equatable, Sendable {
    let version: String
    let notes: String
    let pageURL: URL
    let archiveURL: URL
    let archiveSize: Int64
}

/// Finds, downloads, verifies and installs new versions from GitHub Releases.
///
/// An updater replaces the app with whatever it downloaded, so the download is treated as hostile until
/// proven otherwise. Before anything is installed, the new bundle must:
/// 1. carry a Developer ID signature from this team, for this app's identifier (not merely "a valid
///    signature" — an ad-hoc one is valid too);
/// 2. be notarized, as judged by Gatekeeper;
/// 3. be the version that was announced, and newer than the one running (no replays of an old build).
/// The swap itself keeps the old bundle until the new one is in place.
@MainActor
@Observable
final class UpdateManager {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(AppRelease)
        case downloading(AppRelease, progress: Double)
        case installing(AppRelease)
        case failed(AppRelease?, message: String)
    }

    nonisolated static let releasesPage = URL(string: "https://github.com/iCosiSenpai/MacDFUDiagnostics/releases")!
    private nonisolated static let latestReleaseAPI = URL(string: "https://api.github.com/repos/iCosiSenpai/MacDFUDiagnostics/releases/latest")!
    private nonisolated static let downloadPrefix = "https://github.com/iCosiSenpai/MacDFUDiagnostics/releases/download/"
    private nonisolated static let maximumArchiveSize: Int64 = 250 * 1024 * 1024

    private(set) var state: State = .idle
    private(set) var lastChecked: Date?
    /// The user chose to carry on with the current version after an update could not be installed.
    private(set) var isDeferred = false

    @ObservationIgnored private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.httpAdditionalHeaders = ["User-Agent": "MacDFUStudio"]
        return URLSession(configuration: configuration)
    }()

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    var currentBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    /// Only a real app bundle can replace itself; a binary run straight from a build folder cannot.
    var canSelfUpdate: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    /// The release the update sheet is about, while there is one to show.
    var pendingRelease: AppRelease? {
        switch state {
        case .available(let release), .downloading(let release, _), .installing(let release): release
        case .failed(let release, _): isDeferred ? nil : release
        default: nil
        }
    }

    var isWorking: Bool {
        switch state {
        case .checking, .downloading, .installing: true
        default: false
        }
    }

    // MARK: - Checking

    /// Asks GitHub for the latest release. A quiet check keeps network trouble to itself.
    func check(quietly: Bool = false) async {
        guard !isWorking else { return }
        state = .checking
        isDeferred = false

        do {
            var request = URLRequest(url: Self.latestReleaseAPI, cachePolicy: .reloadIgnoringLocalCacheData)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw UpdateError.server((response as? HTTPURLResponse)?.statusCode ?? 0)
            }

            let release = try Self.release(from: data)
            lastChecked = .now
            state = Self.isVersion(release.version, newerThan: currentVersion) ? .available(release) : .upToDate
        } catch {
            state = quietly ? .idle : .failed(nil, message: error.localizedDescription)
        }
    }

    private struct ReleasePayload: Decodable {
        struct Asset: Decodable {
            let name: String
            let browser_download_url: URL
            let size: Int64
        }

        let tag_name: String
        let body: String?
        let html_url: URL
        let assets: [Asset]
    }

    /// Reads the release description GitHub returns. The archive must be this repository's own `.zip`,
    /// served over HTTPS from github.com, and of a believable size.
    nonisolated static func release(from data: Data) throws -> AppRelease {
        let payload = try JSONDecoder().decode(ReleasePayload.self, from: data)
        let version = payload.tag_name.trimmingCharacters(in: .whitespaces).replacing(/^[vV]/, with: "")
        guard version.wholeMatch(of: /\d+(\.\d+){0,3}/) != nil else { throw UpdateError.malformedRelease }

        guard let asset = payload.assets.first(where: { $0.name.lowercased().hasSuffix(".zip") }),
              asset.browser_download_url.absoluteString.hasPrefix(downloadPrefix),
              asset.size > 0, asset.size <= maximumArchiveSize else {
            throw UpdateError.noArchive
        }
        return AppRelease(
            version: version,
            notes: payload.body ?? "",
            pageURL: payload.html_url,
            archiveURL: asset.browser_download_url,
            archiveSize: asset.size
        )
    }

    /// Numeric, component-wise comparison: `2.0` is newer than `1.12.3`, and `1.3` equals `1.3.0`.
    nonisolated static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        func components(_ text: String) -> [Int] {
            text.split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 }
        }
        let lhs = components(candidate)
        let rhs = components(current)
        for index in 0..<max(lhs.count, rhs.count) {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right { return left > right }
        }
        return false
    }

    /// Shows the update sheet with made-up contents. For demos and screenshots only.
    func presentSample() {
        state = .available(AppRelease(
            version: "9.0",
            notes: "**New**\n- A sample of what release notes look like.\n- Nothing is downloaded in a demo.",
            pageURL: Self.releasesPage,
            archiveURL: Self.releasesPage,
            archiveSize: 1
        ))
    }

    // MARK: - Installing

    /// Lets the user keep working when an update cannot be installed right now.
    func continueWithoutUpdating() {
        isDeferred = true
    }

    func installPendingUpdate() async {
        guard let release = pendingRelease, !isWorking || state == .available(release) else { return }
        guard canSelfUpdate, CodeTrust.runningAppIsReleaseBuild else {
            state = .failed(release, message: String(localized: "This copy can't update itself. Download the new version from GitHub."))
            return
        }

        let scratch = FileManager.default.temporaryDirectory.appending(path: "MacDFUStudio-update-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: scratch) }

        do {
            try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])

            state = .downloading(release, progress: 0)
            let archive = scratch.appending(path: "update.zip")
            try await download(release, to: archive)

            state = .installing(release)
            let unpacked = scratch.appending(path: "unpacked", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: unpacked, withIntermediateDirectories: true)
            let unzip = await ProcessRunner.run("/usr/bin/ditto", ["-x", "-k", archive.path, unpacked.path])
            guard unzip.succeeded else { throw UpdateError.unpackFailed }

            let newApp = try Self.soleAppBundle(in: unpacked)
            try await Self.vet(newApp, announcedVersion: release.version, runningVersion: currentVersion)
            try Self.replaceRunningApp(with: newApp)
            relaunch()
        } catch {
            state = .failed(release, message: error.localizedDescription)
        }
    }

    private func download(_ release: AppRelease, to destination: URL) async throws {
        let progressWatch = ProgressWatch()
        defer { progressWatch.observation?.invalidate() }

        let session = session
        let response: URLResponse = try await withCheckedThrowingContinuation { continuation in
            let task = session.downloadTask(with: release.archiveURL) { location, response, error in
                // The temporary file only exists until this handler returns, so it is moved here.
                do {
                    if let error { throw error }
                    guard let location, let response else { throw UpdateError.server(0) }
                    try FileManager.default.moveItem(at: location, to: destination)
                    continuation.resume(returning: response)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            progressWatch.observation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
                let fraction = progress.fractionCompleted
                Task { @MainActor in
                    if case .downloading(let current, _) = self?.state {
                        self?.state = .downloading(current, progress: fraction)
                    }
                }
            }
            task.resume()
        }

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UpdateError.server((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        let size = (try? destination.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        guard size > 0, Int64(size) <= Self.maximumArchiveSize else { throw UpdateError.noArchive }
    }

    /// Keeps the progress observation alive for the length of one download.
    private final class ProgressWatch: @unchecked Sendable {
        var observation: NSKeyValueObservation?
    }

    // MARK: - Vetting the download

    /// The archive must contain exactly one real `.app` at its top level — no symlinks standing in for it.
    nonisolated static func soleAppBundle(in folder: URL) throws -> URL {
        let items = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isSymbolicLinkKey, .isDirectoryKey])
        let apps = items.filter { $0.pathExtension == "app" }
        guard apps.count == 1, let app = apps.first,
              let values = try? app.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey]),
              values.isSymbolicLink == false, values.isDirectory == true else {
            throw UpdateError.unexpectedContents
        }
        return app
    }

    nonisolated static func vet(_ app: URL, announcedVersion: String, runningVersion: String) async throws {
        // 1. Signed by this team's Developer ID, for this app.
        do {
            try CodeTrust.verify(codeAt: app, requirement: CodeTrust.requirement(identifier: CodeTrust.appIdentifier))
        } catch {
            throw UpdateError.notOurs(error.localizedDescription)
        }

        // 2. Notarized: Gatekeeper accepts it as something a user may run.
        let gatekeeper = await ProcessRunner.run("/usr/sbin/spctl", ["--assess", "--type", "execute", app.path])
        guard gatekeeper.succeeded else { throw UpdateError.notNotarized }

        // 3. It is the version that was promised, and it moves forward.
        guard let info = NSDictionary(contentsOf: app.appending(path: "Contents/Info.plist")),
              let version = info["CFBundleShortVersionString"] as? String,
              (info["CFBundleIdentifier"] as? String) == CodeTrust.appIdentifier,
              !isVersion(announcedVersion, newerThan: version), !isVersion(version, newerThan: announcedVersion),
              isVersion(version, newerThan: runningVersion) else {
            throw UpdateError.wrongVersion
        }
    }

    // MARK: - Swapping and relaunching

    /// Puts the new bundle where the running one is. The old bundle is only removed once the new one
    /// has taken its place, so a failure half-way leaves a working app behind.
    private static func replaceRunningApp(with newApp: URL) throws {
        let current = Bundle.main.bundleURL
        // Gatekeeper runs a freshly downloaded app from a read-only shadow copy until it is moved.
        guard !current.path.contains("/AppTranslocation/") else { throw UpdateError.translocated }
        guard FileManager.default.isWritableFile(atPath: current.deletingLastPathComponent().path) else {
            throw UpdateError.notWritable
        }

        // Stage next to the destination first so the final step is a rename on the same volume.
        let staged = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: current, create: true)
            .appending(path: current.lastPathComponent, directoryHint: .isDirectory)
        try FileManager.default.copyItem(at: newApp, to: staged)
        _ = try FileManager.default.replaceItemAt(current, withItemAt: staged)
        try? FileManager.default.removeItem(at: staged.deletingLastPathComponent())
    }

    private func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
            Task { @MainActor in
                if error != nil {
                    // The new version is installed but did not start. Say so, and let the user open it.
                    self.state = .failed(nil, message: String(localized: "The update is installed. Quit and open the app again to use it."))
                    return
                }
                // AppKit does not quit an app that is showing a sheet, and the update sheet is still up:
                // take it down, ask to quit, and do not wait around if that is refused — this copy has
                // already been replaced on disk and must not outlive its successor.
                self.state = .idle
                NSApplication.shared.terminate(nil)
                try? await Task.sleep(for: .seconds(1))
                exit(0)
            }
        }
    }
}

enum UpdateError: LocalizedError {
    case server(Int)
    case malformedRelease
    case noArchive
    case unpackFailed
    case unexpectedContents
    case notOurs(String)
    case notNotarized
    case wrongVersion
    case translocated
    case notWritable

    var errorDescription: String? {
        switch self {
        case .server(let code):
            String(localized: "GitHub didn't answer (\(code)).")
        case .malformedRelease, .noArchive:
            String(localized: "The release has no installable download.")
        case .unpackFailed, .unexpectedContents:
            String(localized: "The download is damaged.")
        case .notOurs(let reason):
            String(localized: "The download isn't signed by the developer. Nothing was installed. (\(reason))")
        case .notNotarized:
            String(localized: "The download isn't notarized by Apple. Nothing was installed.")
        case .wrongVersion:
            String(localized: "The download isn't the announced version. Nothing was installed.")
        case .translocated:
            String(localized: "Move the app to the Applications folder, then update.")
        case .notWritable:
            String(localized: "This folder can't be written to. Download the new version from GitHub.")
        }
    }
}
