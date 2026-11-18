import Foundation
import AppKit
import Observation

struct GitHubReleaseAsset: Codable, Equatable, Sendable {
    let name: String
    let browserDownloadURL: URL
    let size: Int64

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
        case size
    }
}

struct GitHubReleaseInfo: Codable, Equatable, Sendable {
    let tagName: String
    let name: String
    let body: String
    let htmlURL: URL
    let publishedAt: String?
    let assets: [GitHubReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
        case publishedAt = "published_at"
        case assets
    }

    var cleanVersion: String {
        tagName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "^[vV]", with: "", options: .regularExpression)
    }

    var preferredZipAsset: GitHubReleaseAsset? {
        assets.first { $0.name.lowercased().hasSuffix(".zip") }
    }

    var preferredDMGAsset: GitHubReleaseAsset? {
        assets.first { $0.name.lowercased().hasSuffix(".dmg") }
    }
}

enum UpdateCheckState: Equatable, Sendable {
    case idle
    case checking
    case upToDate(currentVersion: String, checkedAt: Date)
    case updateRequired(release: GitHubReleaseInfo, currentVersion: String)
    case downloading(release: GitHubReleaseInfo, progress: Double, downloadedBytes: Int64, totalBytes: Int64)
    case installing(release: GitHubReleaseInfo, stageIT: String, stageEN: String)
    case failed(messageIT: String, messageEN: String, requiredRelease: GitHubReleaseInfo?)
}

@MainActor
@Observable
final class UpdateManager: NSObject {
    static let repoOwner = "iCosiSenpai"
    static let repoName = "MacDFUDiagnostics"
    static let latestReleaseAPI = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")!
    static let releasesPageURL = URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases")!

    private(set) var state: UpdateCheckState = .idle
    private(set) var lastCheckedDate: Date?

    var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.3.0"
    }

    var currentBuild: String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "4"
    }

    /// True whenever a newer release has been found and must be installed before continuing.
    var isMandatoryUpdateModalPresented: Bool {
        switch state {
        case .updateRequired, .downloading, .installing:
            return true
        case .failed(_, _, let requiredRelease):
            return requiredRelease != nil
        default:
            return false
        }
    }

    var activeRequiredRelease: GitHubReleaseInfo? {
        switch state {
        case .updateRequired(let rel, _), .downloading(let rel, _, _, _), .installing(let rel, _, _):
            return rel
        case .failed(_, _, let rel):
            return rel
        default:
            return nil
        }
    }

    // MARK: - Check for Updates
    func checkForUpdates(silentIfUpToDate: Bool = false) async {
        switch state {
        case .checking, .downloading, .installing:
            return
        default:
            break
        }

        state = .checking
        var request = URLRequest(url: Self.latestReleaseAPI)
        request.timeoutInterval = 12
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("MacDFUStudio/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            guard http.statusCode == 200 else {
                state = .failed(
                    messageIT: "GitHub API ha risposto con stato HTTP \(http.statusCode).",
                    messageEN: "GitHub API returned HTTP status \(http.statusCode).",
                    requiredRelease: nil
                )
                return
            }

            let release = try JSONDecoder().decode(GitHubReleaseInfo.self, from: data)
            let now = Date()
            lastCheckedDate = now

            if Self.isVersion(release.cleanVersion, newerThan: currentVersion) {
                state = .updateRequired(release: release, currentVersion: currentVersion)
            } else {
                state = .upToDate(currentVersion: currentVersion, checkedAt: now)
            }
        } catch {
            if !silentIfUpToDate {
                state = .failed(
                    messageIT: "Impossibile verificare gli aggiornamenti: \(error.localizedDescription)",
                    messageEN: "Could not check for updates: \(error.localizedDescription)",
                    requiredRelease: nil
                )
            } else {
                state = .idle
            }
        }
    }

    // MARK: - Mandatory "Update and Restart App" Execution
    func downloadAndInstallMandatoryUpdate() async {
        guard let release = activeRequiredRelease else { return }
        guard let asset = release.preferredZipAsset ?? release.preferredDMGAsset else {
            state = .failed(
                messageIT: "Nessun pacchetto .zip o .dmg trovato nella release \(release.tagName).",
                messageEN: "No .zip or .dmg asset found in release \(release.tagName).",
                requiredRelease: release
            )
            return
        }

        let isZip = asset.name.lowercased().hasSuffix(".zip")
        state = .downloading(release: release, progress: 0.0, downloadedBytes: 0, totalBytes: asset.size)

        do {
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("macdfu-updater-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let downloadedFile = tempDir.appendingPathComponent(asset.name)

            // Stream download with progress updates
            var req = URLRequest(url: asset.browserDownloadURL)
            req.setValue("MacDFUStudio/\(currentVersion)", forHTTPHeaderField: "User-Agent")
            let (asyncBytes, response) = try await URLSession.shared.bytes(for: req)
            let expectedLength = response.expectedContentLength > 0 ? response.expectedContentLength : asset.size

            FileManager.default.createFile(atPath: downloadedFile.path, contents: nil)
            let fileHandle = try FileHandle(forWritingTo: downloadedFile)
            defer { try? fileHandle.close() }

            var buffer = Data()
            buffer.reserveCapacity(65536)
            var received: Int64 = 0
            var lastUIUpdate = Date.distantPast

            for try await byte in asyncBytes {
                buffer.append(byte)
                if buffer.count >= 65536 {
                    try fileHandle.write(contentsOf: buffer)
                    received += Int64(buffer.count)
                    buffer.removeAll(keepingCapacity: true)

                    let now = Date()
                    if now.timeIntervalSince(lastUIUpdate) >= 0.08 {
                        let prog = expectedLength > 0 ? min(1.0, Double(received) / Double(expectedLength)) : 0.5
                        state = .downloading(release: release, progress: prog, downloadedBytes: received, totalBytes: expectedLength)
                        lastUIUpdate = now
                    }
                }
            }
            if !buffer.isEmpty {
                try fileHandle.write(contentsOf: buffer)
                received += Int64(buffer.count)
                buffer.removeAll()
            }
            try fileHandle.close()

            state = .installing(
                release: release,
                stageIT: "Estrazione e verifica firma digitale Apple Developer ID...",
                stageEN: "Extracting and verifying Apple Developer ID signature..."
            )

            let extractDir = tempDir.appendingPathComponent("extracted")
            try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)

            let stagedAppURL: URL
            if isZip {
                let (rc, out) = await DiagnosticsEngine.runProcess("/usr/bin/ditto", ["-x", "-k", downloadedFile.path, extractDir.path])
                guard rc == 0 else {
                    throw NSError(domain: "UpdateManager", code: Int(rc), userInfo: [NSLocalizedDescriptionKey: "Unzip failed: \(out)"])
                }
                stagedAppURL = try Self.findAppBundle(in: extractDir)
            } else {
                let mountPoint = tempDir.appendingPathComponent("mnt")
                try FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)
                let (rc, out) = await DiagnosticsEngine.runProcess("/usr/bin/hdiutil", ["attach", downloadedFile.path, "-mountpoint", mountPoint.path, "-nobrowse", "-readonly", "-quiet"])
                guard rc == 0 else {
                    throw NSError(domain: "UpdateManager", code: Int(rc), userInfo: [NSLocalizedDescriptionKey: "DMG mount failed: \(out)"])
                }
                let mountedApp = try Self.findAppBundle(in: mountPoint)
                let copiedApp = extractDir.appendingPathComponent(mountedApp.lastPathComponent)
                _ = await DiagnosticsEngine.runProcess("/usr/bin/ditto", [mountedApp.path, copiedApp.path])
                _ = await DiagnosticsEngine.runProcess("/usr/bin/hdiutil", ["detach", mountPoint.path, "-quiet"])
                stagedAppURL = copiedApp
            }

            // Verify code signature on the downloaded app bundle
            let (verifyRC, verifyOut) = await DiagnosticsEngine.runProcess("/usr/bin/codesign", ["--verify", "--deep", "--strict", stagedAppURL.path])
            guard verifyRC == 0 else {
                throw NSError(domain: "UpdateManager", code: Int(verifyRC), userInfo: [NSLocalizedDescriptionKey: "Code signature verification failed: \(verifyOut)"])
            }

            state = .installing(
                release: release,
                stageIT: "Installazione nuova versione e riavvio automatico...",
                stageEN: "Installing new version and restarting automatically..."
            )

            try Self.replaceAndRelaunch(with: stagedAppURL)
        } catch {
            state = .failed(
                messageIT: "Aggiornamento fallito: \(error.localizedDescription)",
                messageEN: "Update failed: \(error.localizedDescription)",
                requiredRelease: release
            )
        }
    }

    private static func findAppBundle(in directory: URL) throws -> URL {
        let items = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        if let app = items.first(where: { $0.pathExtension == "app" }) {
            return app
        }
        throw NSError(domain: "UpdateManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "No .app bundle found in update archive."])
    }

    private static func replaceAndRelaunch(with newAppURL: URL) throws {
        let currentBundleURL = Bundle.main.bundleURL
        let targetAppPath: String
        if currentBundleURL.pathExtension == "app" {
            targetAppPath = currentBundleURL.path
        } else {
            // Running from SwiftPM debug/release binary -> update MacDFUDiagnostics.app in repo or /Applications
            let repoApp = "/Users/macsenpai/dev/MacDFUDiagnostics/MacDFUDiagnostics.app"
            targetAppPath = FileManager.default.fileExists(atPath: repoApp) ? repoApp : "/Applications/MacDFUDiagnostics.app"
        }

        let pid = ProcessInfo.processInfo.processIdentifier
        let script = """
        #!/bin/zsh
        while kill -0 \(pid) 2>/dev/null; do
            sleep 0.2
        done
        rm -rf "\(targetAppPath)"
        ditto "\(newAppURL.path)" "\(targetAppPath)"
        xattr -dr com.apple.quarantine "\(targetAppPath)" 2>/dev/null || true
        open -n "\(targetAppPath)"
        """

        let scriptURL = FileManager.default.temporaryDirectory.appendingPathComponent("macdfu-relaunch-\(pid).zsh")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let proc = Process()
        proc.executableURL = URL(filePath: "/bin/zsh")
        proc.arguments = [scriptURL.path]
        try proc.run()

        NSApplication.shared.terminate(nil)
    }

    // MARK: - Semantic Version Comparison
    nonisolated static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let lhs = candidate.split(separator: ".").compactMap { Int($0) }
        let rhs = current.split(separator: ".").compactMap { Int($0) }
        let maxCount = max(lhs.count, rhs.count)
        for i in 0..<maxCount {
            let l = i < lhs.count ? lhs[i] : 0
            let r = i < rhs.count ? rhs[i] : 0
            if l != r {
                return l > r
            }
        }
        return false
    }
}
