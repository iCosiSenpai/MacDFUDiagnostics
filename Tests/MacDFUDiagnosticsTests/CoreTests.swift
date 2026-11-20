import Foundation
import Testing
@testable import MacDFUDiagnostics

@Suite("Device identity")
struct DeviceIdentityTests {
    @Test func parsesDFUSerial() {
        let identity = DeviceIdentity.parse(
            serial: "CPID:8103 CPRV:11 CPFM:03 SCEP:01 BDID:26 ECID:001A2B3C4D5E6F78 IBFL:3C SRTG:[iBoot-6723.41.11]",
            isPortDFU: false
        )
        #expect(identity.cpid == 0x8103)
        #expect(identity.bdid == 0x26)
        #expect(identity.ecid == "0x001A2B3C4D5E6F78")
        #expect(identity.iBootTag == "iBoot-6723.41.11")
    }

    @Test func parsesRecoverySerialNumber() {
        let identity = DeviceIdentity.parse(serial: "CPID:8112 BDID:28 ECID:0x1234abcd SRNM:[C02XK0ABCDEF]", isPortDFU: false)
        #expect(identity.serialNumber == "C02XK0ABCDEF")
        #expect(identity.ecid == "0x1234ABCD")
    }

    @Test func unpacksPortDFUBoardField() {
        // chip 0x8132 in bits 8–23, board 0x2A in bits 24–31
        let identity = DeviceIdentity.parse(serial: "BDID:2A813200 ECID:0000000000000001", isPortDFU: true)
        #expect(identity.cpid == 0x8132)
        #expect(identity.bdid == 0x2A)
    }

    @Test func readsChipFromBootedSerial() {
        // Eight hex digits do not fit a 16-bit integer; the chip is the low half.
        let identity = DeviceIdentity.parse(serial: "00008112-001A2B3C4D5E6F78", isPortDFU: false)
        #expect(identity.cpid == 0x8112)
        #expect(identity.ecid == "0x001A2B3C4D5E6F78")
    }

    @Test(arguments: ["", "xyz", "12 --erase", "0x", "11112222333344445", "1234;rm", "-f", "$(id)"])
    func rejectsECIDsThatAreNotHex(text: String) {
        #expect(DeviceIdentity.normalizedECID(text) == nil)
    }

    @Test func ignoresAnECIDCarryingAnOption() {
        let identity = DeviceIdentity.parse(serial: "CPID:8103 BDID:26 ECID:--foreach", isPortDFU: false)
        #expect(identity.ecid == nil)
    }

    @Test func stripsControlCharactersFromDescriptorText() {
        let identity = DeviceIdentity.parse(serial: "SRTG:[iBoot\u{1B}[31m-1]", isPortDFU: false)
        #expect(identity.iBootTag?.contains("\u{1B}") == false)
    }
}

@Suite("Target state")
struct TargetStateTests {
    @Test func mapsProductIDs() {
        #expect(TargetState.from(productID: 0x1227, productName: "", serial: "") == .dfu)
        #expect(TargetState.from(productID: 0xF014, productName: "", serial: "") == .portDFU)
        #expect(TargetState.from(productID: 0x1281, productName: "", serial: "") == .recovery)
        #expect(TargetState.from(productID: 0x1902, productName: "", serial: "") == .booted)
        #expect(TargetState.from(productID: 0x7304, productName: "", serial: "") == .cableFault)
        #expect(TargetState.from(productID: 0x1234, productName: "", serial: "") == .other)
    }

    @Test func treatsT2OnTheWTFProductIDAsDFU() {
        #expect(TargetState.from(productID: 0x1222, productName: "", serial: "CPID:8012 BDID:0A") == .dfu)
        #expect(TargetState.from(productID: 0x1222, productName: "Apple Mobile Device", serial: "") == .wtf)
    }

    @Test func onlyLowLevelModesAcceptFirmware() {
        #expect(TargetState.dfu.acceptsFirmware)
        #expect(TargetState.portDFU.acceptsFirmware)
        #expect(!TargetState.booted.acceptsFirmware)
        #expect(!TargetState.recovery.acceptsFirmware)
    }
}

@Suite("Mac catalog")
struct MacCatalogTests {
    @Test func identifiersAreUnique() {
        let ids = MacCatalog.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func chipAndBoardPairsAreUnique() {
        var seen: [String: String] = [:]
        for model in MacCatalog.all {
            guard let cpid = model.cpid, let bdid = model.bdid else { continue }
            let key = String(format: "%04X-%02X", cpid, bdid)
            #expect(seen[key] == nil, "\(model.name) and \(seen[key] ?? "") share \(key)")
            seen[key] = model.name
        }
    }

    @Test func boardNamesAreUnique() {
        let boards = MacCatalog.all.compactMap(\.board)
        #expect(Set(boards).count == boards.count)
    }

    @Test func dfuPortIsOnTheFaceItClaims() {
        for model in MacCatalog.all {
            if let index = model.port.dfuIndex {
                #expect((1...model.port.portCount).contains(index), "\(model.name)")
            } else {
                #expect(model.architecture == .intelLegacy, "\(model.name)")
            }
        }
    }

    @Test func findsAMacByChipAndBoard() {
        #expect(MacCatalog.model(cpid: 0x8103, bdid: 0x26)?.modelIdentifier == "MacBookAir10,1")
        #expect(MacCatalog.model(cpid: 0x8012, bdid: 0x0A)?.restoreIdentifier == "iBridge2,1")
        #expect(MacCatalog.model(cpid: 0xFFFF, bdid: 0xFF) == nil)
    }

    @Test func findsTheHostByBoardName() {
        #expect(MacCatalog.model(board: "j813ap")?.modelIdentifier == "Mac17,3")
        #expect(MacCatalog.model(board: "") == nil)
    }

    @Test func decodesABootedMacFromBCD() {
        #expect(MacCatalog.model(bootedBCDDevice: 0x1603)?.modelIdentifier == "Mac16,3")
        #expect(MacCatalog.model(bootedBCDDevice: 0x1001)?.modelIdentifier == "MacBookAir10,1")
    }

    @Test func refusesToGuessBetweenMacsThatShareABCDValue() {
        // MacBookPro18,1 (2021) and Mac18,1 (M6) both encode as 0x1801, and both are MacBook Pros.
        #expect(MacCatalog.model(bootedBCDDevice: 0x1801, productName: "MacBook Pro") == nil)
        // Mac18,2 is an iMac; MacBookPro18,2 is not.
        #expect(MacCatalog.model(bootedBCDDevice: 0x1802, productName: "iMac")?.modelIdentifier == "Mac18,2")
    }
}

@Suite("Updates")
struct UpdateTests {
    @Test(arguments: [("2.0.0", "1.3.0"), ("1.3.1", "1.3.0"), ("1.10.0", "1.9.9"), ("2", "1.99"), ("1.3.0.1", "1.3.0")])
    func newer(pair: (String, String)) {
        #expect(UpdateManager.isVersion(pair.0, newerThan: pair.1))
        #expect(!UpdateManager.isVersion(pair.1, newerThan: pair.0))
    }

    @Test func equalVersionsAreNotNewer() {
        #expect(!UpdateManager.isVersion("1.3", newerThan: "1.3.0"))
        #expect(!UpdateManager.isVersion("2.0.0", newerThan: "2.0.0"))
    }

    private func payload(tag: String = "v2.0.0", url: String, size: Int = 1_300_000, body: String? = "Notes") -> Data {
        let bodyJSON = body.map { "\"\($0)\"" } ?? "null"
        return Data("""
        {"tag_name":"\(tag)","name":null,"body":\(bodyJSON),"html_url":"https://github.com/iCosiSenpai/MacDFUDiagnostics/releases/tag/\(tag)",
         "assets":[{"name":"Mac-DFU-Studio.dmg","browser_download_url":"https://github.com/iCosiSenpai/MacDFUDiagnostics/releases/download/\(tag)/a.dmg","size":10},
                   {"name":"Mac-DFU-Studio.zip","browser_download_url":"\(url)","size":\(size)}]}
        """.utf8)
    }

    @Test func readsAReleaseEvenWithoutNameOrNotes() throws {
        let release = try UpdateManager.release(
            from: payload(url: "https://github.com/iCosiSenpai/MacDFUDiagnostics/releases/download/v2.0.0/Mac-DFU-Studio.zip", body: nil)
        )
        #expect(release.version == "2.0.0")
        #expect(release.notes.isEmpty)
        #expect(release.archiveURL.lastPathComponent == "Mac-DFU-Studio.zip")
    }

    @Test(arguments: [
        "http://github.com/iCosiSenpai/MacDFUDiagnostics/releases/download/v2.0.0/a.zip",
        "https://evil.example/iCosiSenpai/MacDFUDiagnostics/releases/download/v2.0.0/a.zip",
        "https://github.com/someone-else/MacDFUDiagnostics/releases/download/v2.0.0/a.zip",
        "https://github.com.evil.example/iCosiSenpai/MacDFUDiagnostics/releases/download/v2.0.0/a.zip",
    ])
    func refusesArchivesFromAnywhereElse(url: String) {
        #expect(throws: UpdateError.self) { try UpdateManager.release(from: payload(url: url)) }
    }

    @Test func refusesAnAbsurdlyLargeArchive() {
        #expect(throws: UpdateError.self) {
            try UpdateManager.release(from: payload(
                url: "https://github.com/iCosiSenpai/MacDFUDiagnostics/releases/download/v2.0.0/a.zip", size: 900_000_000
            ))
        }
    }

    @Test func refusesATagThatIsNotAVersion() {
        #expect(throws: UpdateError.self) {
            try UpdateManager.release(from: payload(
                tag: "latest", url: "https://github.com/iCosiSenpai/MacDFUDiagnostics/releases/download/latest/a.zip"
            ))
        }
    }
}

@Suite("Privileged helper")
struct PrivilegedHelperTests {
    @Test func quotesAPathThatTriesToEscape() {
        let hostile = "/Applications/It's $(id) `x`\"; rm -rf ~/Mac DFU.app/Contents/MacOS/macdfu-vdm-helper"
        let script = PrivilegedHelper.rootScript(helperPath: hostile, requirement: nil, command: .dfu, rid: 2)
        // The path appears once, wholly inside single quotes, with its own quote escaped.
        #expect(script.contains("/bin/cp '/Applications/It'\\''s $(id) `x`\"; rm -rf ~/Mac DFU.app/Contents/MacOS/macdfu-vdm-helper' \"$D/helper\""))
        #expect(script.contains("\"$D/helper\" dfu --rid 2 --json"))
    }

    @Test func checksTheSignatureOfTheCopyInAReleaseBuild() {
        let requirement = CodeTrust.requirement(identifier: CodeTrust.helperIdentifier)
        let script = PrivilegedHelper.rootScript(helperPath: "/x/helper", requirement: requirement, command: .probe, rid: 0)
        let lines = script.split(separator: "\n")
        let verify = lines.firstIndex { $0.contains("codesign --verify") }
        let execute = lines.firstIndex { $0.hasPrefix("\"$D/helper\"") }
        #expect(verify != nil && execute != nil && verify! < execute!)
        #expect(lines[verify!].contains("\"$D/helper\""), "the copy is verified, not the original")
        #expect(script.contains("certificate leaf[subject.OU] = \"6KV8L8WQ9D\""))
    }

    @Test func shellQuotingRoundTrips() {
        #expect(ProcessRunner.shellQuoted("a'b") == "'a'\\''b'")
        #expect(ProcessRunner.shellQuoted("plain") == "'plain'")
    }
}

@Suite("Input validation")
struct ValidationTests {
    @Test func acceptsOnlyRealConsoleNodes() {
        #expect(DiagnosticsEngine.isValidConsolePath("/dev/cu.debug-console"))
        #expect(DiagnosticsEngine.isValidConsolePath("/dev/cu.kis-0001"))
        #expect(!DiagnosticsEngine.isValidConsolePath("/dev/cu.debug'; rm -rf ~; '"))
        #expect(!DiagnosticsEngine.isValidConsolePath("/dev/cu.x y"))
        #expect(!DiagnosticsEngine.isValidConsolePath("/tmp/cu.debug-console"))
        #expect(!DiagnosticsEngine.isValidConsolePath("/dev/cu.a/../../etc/passwd"))
    }

    @Test func acceptsOnlyDiskIdentifiers() {
        #expect(ExternalDisk.isValidIdentifier("disk4"))
        #expect(!ExternalDisk.isValidIdentifier("disk4s1"))
        #expect(!ExternalDisk.isValidIdentifier("-rf"))
        #expect(!ExternalDisk.isValidIdentifier("disk4 disk0"))
    }

    @Test func firmwareMustBeALocalIPSW() {
        #expect(!DiagnosticsEngine.isFirmwareFile(URL(string: "https://example.com/a.ipsw")!))
        #expect(!DiagnosticsEngine.isFirmwareFile(URL(filePath: "/etc/hosts")))
        #expect(!DiagnosticsEngine.isFirmwareFile(URL(filePath: "/nonexistent/file.ipsw")))
    }
}

@Suite("Code signing requirement")
struct CodeTrustTests {
    @Test func requirementCompiles() throws {
        // A requirement that does not compile rejects everything — it must be checked, not assumed.
        let text = CodeTrust.requirement(identifier: CodeTrust.appIdentifier)
        var requirement: SecRequirement?
        #expect(SecRequirementCreateWithString(text as CFString, [], &requirement) == errSecSuccess)
    }

    @Test func rejectsAnAppFromAnotherSigner() {
        // Safari is validly signed — by Apple, not by this team.
        #expect(throws: (any Error).self) {
            try CodeTrust.verify(
                codeAt: URL(filePath: "/Applications/Safari.app"),
                requirement: CodeTrust.requirement(identifier: CodeTrust.appIdentifier)
            )
        }
    }
}
