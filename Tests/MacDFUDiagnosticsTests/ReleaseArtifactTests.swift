import Foundation
import Testing
@testable import MacDFUDiagnostics

/// Checks the updater's vetting against real bundles. These need a notarized release build, so they
/// only run when the environment says where to find one:
///
///     MACDFU_RELEASE_APP=/path/to/MacDFUDiagnostics.app        a genuine release build
///     MACDFU_TAMPERED_APP=…  MACDFU_ADHOC_APP=…                optional: copies that must be refused
///     MACDFU_RELEASE_VERSION=2.0.0
@Suite("Release artifact", .enabled(if: ProcessInfo.processInfo.environment["MACDFU_RELEASE_APP"] != nil))
struct ReleaseArtifactTests {
    private let environment = ProcessInfo.processInfo.environment
    private var version: String { environment["MACDFU_RELEASE_VERSION"] ?? "0" }

    private func app(_ key: String) -> URL? {
        environment[key].map { URL(filePath: $0) }
    }

    @Test func acceptsTheGenuineRelease() async throws {
        let url = try #require(app("MACDFU_RELEASE_APP"))
        try await UpdateManager.vet(url, announcedVersion: version, runningVersion: "0.9")
    }

    @Test func refusesAReleaseThatIsNotNewer() async throws {
        let url = try #require(app("MACDFU_RELEASE_APP"))
        await #expect(throws: UpdateError.self) {
            try await UpdateManager.vet(url, announcedVersion: version, runningVersion: version)
        }
    }

    @Test func refusesAVersionOtherThanTheOneAnnounced() async throws {
        let url = try #require(app("MACDFU_RELEASE_APP"))
        await #expect(throws: UpdateError.self) {
            try await UpdateManager.vet(url, announcedVersion: "99.0", runningVersion: "0.9")
        }
    }

    @Test func refusesABundleChangedAfterSigning() async throws {
        guard let url = app("MACDFU_TAMPERED_APP") else { return }
        await #expect(throws: UpdateError.self) {
            try await UpdateManager.vet(url, announcedVersion: version, runningVersion: "0.9")
        }
    }

    @Test func refusesABundleSignedBySomeoneElse() async throws {
        // An ad-hoc signature is a perfectly valid signature. It is just not ours.
        guard let url = app("MACDFU_ADHOC_APP") else { return }
        await #expect(throws: UpdateError.self) {
            try await UpdateManager.vet(url, announcedVersion: version, runningVersion: "0.9")
        }
    }

    @Test func findsTheOnlyAppInAnArchive() throws {
        let url = try #require(app("MACDFU_RELEASE_APP"))
        #expect(try UpdateManager.soleAppBundle(in: url.deletingLastPathComponent()).lastPathComponent == url.lastPathComponent)
    }
}
