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
}
