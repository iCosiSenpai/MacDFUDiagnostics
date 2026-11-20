import Foundation

/// Stand-in hardware, selected with the `-demo <scenario>` launch argument.
///
/// It exists so every state of the interface can be looked at — and photographed — without a second
/// Mac on the desk. In a demo nothing real is touched: no helper runs, no firmware is written.
enum DemoScenario: String, Sendable {
    /// Nothing connected.
    case empty
    /// A running Mac, ready to be sent into DFU.
    case booted
    /// An Apple silicon Mac in DFU.
    case dfu
    /// An Intel Mac whose T2 chip is in DFU.
    case t2
    case recovery
    /// A cable that cannot carry DFU.
    case cable
    /// A restore already under way.
    case restoring
    /// Plays by itself: a Mac arrives, enters DFU, is revived. Made for screen recordings.
    case tour

    var devices: [TargetDevice] {
        switch self {
        case .empty, .tour: []
        case .booted: [Self.device("Mac16,8", state: .booted, productID: 0x1902)]
        case .dfu, .restoring: [Self.device("Mac16,8", state: .dfu, productID: 0x1227)]
        case .t2: [Self.device("iBridge2,14-MacBookPro16,1", state: .dfu, productID: 0x1227)]
        case .recovery: [Self.device("Mac14,2", state: .recovery, productID: 0x1281)]
        case .cable:
            [TargetDevice(
                id: "demo-billboard", vendorID: 0x05AC, productID: 0x7304, bcdDevice: 0, locationID: 0x0110_0000,
                productName: "USB Billboard", rawSerial: "", state: .cableFault, cpid: nil, bdid: nil, ecid: nil,
                iBootTag: nil, serialNumber: nil, model: nil, hostPortRID: nil
            )]
        }
    }

    static let disks = [
        ExternalDisk(id: "disk4", name: "APPLE SSD AP0512M", sizeBytes: 500_277_792_768, bus: "Thunderbolt", smartStatus: "Verified", volumes: [DiskVolume(id: "disk5s1", name: "Macintosh HD", mountPoint: "/Volumes/Macintosh HD"), DiskVolume(id: "disk5s5", name: "Data", mountPoint: "/Volumes/Data")]),
        ExternalDisk(id: "disk6", name: "APPLE SSD SM0256L", sizeBytes: 251_000_193_024, bus: "USB", smartStatus: nil, volumes: [DiskVolume(id: "disk7s1", name: "Macintosh HD", mountPoint: "/Volumes/Macintosh HD 1")]),
    ]

    private static func device(_ catalogID: String, state: TargetState, productID: UInt16) -> TargetDevice {
        let model = MacCatalog.all.first { $0.id == catalogID }
        return TargetDevice(
            id: "demo-\(catalogID)-\(state.rawValue)",
            vendorID: 0x05AC,
            productID: productID,
            bcdDevice: 0x1608,
            locationID: 0x0110_0000,
            productName: state == .booted ? "MacBook Pro" : "Apple Mobile Device (DFU Mode)",
            rawSerial: "",
            state: state,
            cpid: model?.cpid,
            bdid: model?.bdid,
            ecid: state == .booted ? nil : "0x001A2B3C4D5E6F70",
            iBootTag: state == .booted ? nil : "iBoot-11881.61.3",
            serialNumber: state == .dfu ? nil : "DEMO0000XYZ",
            model: model,
            hostPortRID: nil
        )
    }
}

/// What the app was asked to show at launch. Used for demos, screenshots and UI tests:
/// `-demo dfu -section macs -inspector activity -sheet restore`.
enum LaunchOptions {
    /// Only what was typed on the command line counts — never a value saved in the app's preferences.
    private static func value(_ key: String) -> String? {
        UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)[key] as? String
    }

    static var demo: DemoScenario? { value("demo").flatMap(DemoScenario.init) }
    static var section: AppSection? { value("section").flatMap(AppSection.init) }
    static var inspector: InspectorTab? { value("inspector").flatMap(InspectorTab.init) }
    static var sheet: String? { value("sheet") }
}
