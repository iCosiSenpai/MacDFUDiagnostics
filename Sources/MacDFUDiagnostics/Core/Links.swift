import Foundation

/// Every address the app can send someone to, in one place.
enum Links {
    static let website = URL(string: "https://icosisenpai.app/macdfustudio/")!
    static let project = URL(string: "https://github.com/iCosiSenpai/MacDFUDiagnostics")!
    static let issues = URL(string: "https://github.com/iCosiSenpai/MacDFUDiagnostics/issues")!
    static let license = URL(string: "https://github.com/iCosiSenpai/MacDFUDiagnostics/blob/main/LICENSE")!
    static let acknowledgements = URL(string: "https://github.com/iCosiSenpai/MacDFUDiagnostics/blob/main/THIRD-PARTY-NOTICES.md")!

    /// The maintainer's donation pages, the same two every project of his links.
    static let payPal = URL(string: "https://paypal.me/AlessioCosi")!
    static let buyMeACoffee = URL(string: "https://buymeacoffee.com/icosisenpai")!

    static let dfuGuide = URL(string: "https://support.apple.com/120694")!
    static let reviveGuide = URL(string: "https://support.apple.com/108900")!

    /// The sibling app that finds and downloads the firmware files a restore can use.
    static let ipswDownloader = URL(string: "https://icosisenpai.app/ipsw-downloader/")!
    static let ipswDownloaderBundleID = "LupiaeTech.IPSW-Downloader-Plus"

    /// Asks that app to show the firmware for one Mac model: `ipswdlplus://firmware?model=Mac16,1`.
    ///
    /// `nil` unless the text is a model identifier and nothing else — it comes from the catalog, but
    /// it is going into a URL another app will read.
    static func ipswDownloaderFirmware(for model: String) -> URL? {
        guard FirmwareLibrary.isModelIdentifier(model) else { return nil }
        var components = URLComponents()
        components.scheme = "ipswdlplus"
        components.host = "firmware"
        components.queryItems = [
            URLQueryItem(name: "model", value: model),
            URLQueryItem(name: "from", value: "macdfustudio")
        ]
        return components.url
    }
}
