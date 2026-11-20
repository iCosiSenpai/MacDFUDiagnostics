import Foundation

// The catalog of Macs this app knows how to talk to. It is data, not prose: where the DFU port sits is
// described by `DFUPortLayout`, and every sentence the interface shows is derived from that.

enum MacFamily: String, CaseIterable, Identifiable, Sendable {
    case macBookAir = "MacBook Air"
    case macBookPro = "MacBook Pro"
    case macBookNeo = "MacBook Neo"
    case macBook = "MacBook"
    case macMini = "Mac mini"
    case iMac = "iMac"
    case iMacPro = "iMac Pro"
    case macStudio = "Mac Studio"
    case macPro = "Mac Pro"

    var id: String { rawValue }

    /// SF Symbol that draws this kind of Mac.
    var symbol: String {
        switch self {
        case .macBookAir, .macBookPro, .macBookNeo, .macBook: "macbook"
        case .macMini: "macmini"
        case .iMac, .iMacPro: "desktopcomputer"
        case .macStudio: "macstudio"
        case .macPro: "macpro.gen3"
        }
    }

    var isPortable: Bool {
        switch self {
        case .macBookAir, .macBookPro, .macBookNeo, .macBook: true
        default: false
        }
    }
}

enum MacArchitecture: String, CaseIterable, Identifiable, Sendable {
    case appleSilicon
    case intelT2
    case intelLegacy

    var id: String { rawValue }

    /// Whether a Mac of this kind has a DFU mode that can be reached over USB-C.
    var supportsDFU: Bool { self != .intelLegacy }
}

/// Which face of the Mac carries the DFU port, as you look straight at that face.
enum PortFace: String, Sendable {
    case left
    case back
    /// Mac Pro: on top of the tower, on the front of the rack model.
    case tower
    case none
}

struct DFUPortLayout: Hashable, Sendable {
    let face: PortFace
    /// How many USB-C ports that face has.
    let portCount: Int
    /// 1-based position counted from the left of that face. `nil` when the Mac has no DFU port.
    let dfuIndex: Int?
    let hasMagSafe: Bool
    /// The port is not where the rest of the family has it (Apple support article 120694).
    let isException: Bool

    static func left(_ index: Int, of count: Int, magSafe: Bool = false, exception: Bool = false) -> DFUPortLayout {
        DFUPortLayout(face: .left, portCount: count, dfuIndex: index, hasMagSafe: magSafe, isException: exception)
    }

    static func back(_ index: Int, of count: Int, exception: Bool = false) -> DFUPortLayout {
        DFUPortLayout(face: .back, portCount: count, dfuIndex: index, hasMagSafe: false, isException: exception)
    }

    static func tower(_ index: Int, of count: Int) -> DFUPortLayout {
        DFUPortLayout(face: .tower, portCount: count, dfuIndex: index, hasMagSafe: false, isException: false)
    }

    static let none = DFUPortLayout(face: .none, portCount: 0, dfuIndex: nil, hasMagSafe: false, isException: false)
}

struct MacModel: Identifiable, Hashable, Sendable {
    let id: String
    let architecture: MacArchitecture
    let family: MacFamily
    let name: String
    /// What macOS reports as the model, e.g. `Mac16,1`.
    let modelIdentifier: String
    /// What a restore targets in DFU: the Mac itself on Apple silicon, the T2 chip (`iBridge2,x`) on Intel.
    let restoreIdentifier: String?
    let board: String?
    let cpid: UInt16?
    let bdid: UInt8?
    let chip: String
    let port: DFUPortLayout

    static func silicon(
        _ identifier: String, _ family: MacFamily, _ name: String,
        board: String, cpid: UInt16, bdid: UInt8, chip: String, _ port: DFUPortLayout
    ) -> MacModel {
        MacModel(
            id: identifier, architecture: .appleSilicon, family: family, name: name,
            modelIdentifier: identifier, restoreIdentifier: identifier, board: board,
            cpid: cpid, bdid: bdid, chip: chip, port: port
        )
    }

    static func t2(
        _ bridge: String, _ identifier: String, _ family: MacFamily, _ name: String,
        board: String, bdid: UInt8, _ port: DFUPortLayout
    ) -> MacModel {
        MacModel(
            id: "\(bridge)-\(identifier)", architecture: .intelT2, family: family, name: name,
            modelIdentifier: identifier, restoreIdentifier: bridge, board: board,
            cpid: MacCatalog.t2ChipID, bdid: bdid, chip: "Intel + T2", port: port
        )
    }

    static func legacy(_ identifier: String, _ family: MacFamily, _ name: String, chip: String) -> MacModel {
        MacModel(
            id: identifier, architecture: .intelLegacy, family: family, name: name,
            modelIdentifier: identifier, restoreIdentifier: nil, board: nil,
            cpid: nil, bdid: nil, chip: chip, port: .none
        )
    }
}

enum MacCatalog {
    /// Chip ID every Apple T2 reports in DFU.
    static let t2ChipID: UInt16 = 0x8012

    static let all: [MacModel] = appleSilicon + intelT2 + intelLegacy

    // MARK: Apple silicon

    static let appleSilicon: [MacModel] = [
        .silicon("MacBookAir10,1", .macBookAir, "MacBook Air (M1, 2020)", board: "J313AP", cpid: 0x8103, bdid: 0x26, chip: "M1", .left(1, of: 2)),
        .silicon("MacBookPro17,1", .macBookPro, "MacBook Pro (13-inch, M1, 2020)", board: "J293AP", cpid: 0x8103, bdid: 0x24, chip: "M1", .left(1, of: 2)),
        .silicon("Macmini9,1", .macMini, "Mac mini (M1, 2020)", board: "J274AP", cpid: 0x8103, bdid: 0x22, chip: "M1", .back(1, of: 2)),
        .silicon("iMac21,1", .iMac, "iMac (24-inch, M1, 2021 - 2 Ports)", board: "J456AP", cpid: 0x8103, bdid: 0x28, chip: "M1", .back(2, of: 2)),
        .silicon("iMac21,2", .iMac, "iMac (24-inch, M1, 2021 - 4 Ports)", board: "J457AP", cpid: 0x8103, bdid: 0x2A, chip: "M1", .back(4, of: 4)),
        .silicon("MacBookPro18,3", .macBookPro, "MacBook Pro (14-inch, M1 Pro, 2021)", board: "J314sAP", cpid: 0x6000, bdid: 0x08, chip: "M1 Pro", .left(1, of: 2, magSafe: true)),
        .silicon("MacBookPro18,4", .macBookPro, "MacBook Pro (14-inch, M1 Max, 2021)", board: "J314cAP", cpid: 0x6001, bdid: 0x08, chip: "M1 Max", .left(1, of: 2, magSafe: true)),
        .silicon("MacBookPro18,1", .macBookPro, "MacBook Pro (16-inch, M1 Pro, 2021)", board: "J316sAP", cpid: 0x6000, bdid: 0x0A, chip: "M1 Pro", .left(1, of: 2, magSafe: true)),
        .silicon("MacBookPro18,2", .macBookPro, "MacBook Pro (16-inch, M1 Max, 2021)", board: "J316cAP", cpid: 0x6001, bdid: 0x0A, chip: "M1 Max", .left(1, of: 2, magSafe: true)),
        .silicon("Mac13,1", .macStudio, "Mac Studio (M1 Max, 2022)", board: "J375cAP", cpid: 0x6001, bdid: 0x04, chip: "M1 Max", .back(4, of: 4)),
        .silicon("Mac13,2", .macStudio, "Mac Studio (M1 Ultra, 2022)", board: "J375dAP", cpid: 0x6002, bdid: 0x0C, chip: "M1 Ultra", .back(4, of: 4)),
        .silicon("Mac14,2", .macBookAir, "MacBook Air (13-inch, M2, 2022)", board: "J413AP", cpid: 0x8112, bdid: 0x28, chip: "M2", .left(1, of: 2, magSafe: true)),
        .silicon("Mac14,15", .macBookAir, "MacBook Air (15-inch, M2, 2023)", board: "J415AP", cpid: 0x8112, bdid: 0x2E, chip: "M2", .left(1, of: 2, magSafe: true)),
        .silicon("Mac14,7", .macBookPro, "MacBook Pro (13-inch, M2, 2022)", board: "J493AP", cpid: 0x8112, bdid: 0x2A, chip: "M2", .left(1, of: 2)),
        .silicon("Mac14,3", .macMini, "Mac mini (M2, 2023)", board: "J473AP", cpid: 0x8112, bdid: 0x24, chip: "M2", .back(1, of: 2)),
        .silicon("Mac14,12", .macMini, "Mac mini (M2 Pro, 2023)", board: "J474sAP", cpid: 0x6020, bdid: 0x02, chip: "M2 Pro", .back(1, of: 4)),
        .silicon("Mac14,9", .macBookPro, "MacBook Pro (14-inch, M2 Pro, 2023)", board: "J414sAP", cpid: 0x6020, bdid: 0x04, chip: "M2 Pro", .left(1, of: 2, magSafe: true)),
        .silicon("Mac14,5", .macBookPro, "MacBook Pro (14-inch, M2 Max, 2023)", board: "J414cAP", cpid: 0x6021, bdid: 0x04, chip: "M2 Max", .left(1, of: 2, magSafe: true)),
        .silicon("Mac14,10", .macBookPro, "MacBook Pro (16-inch, M2 Pro, 2023)", board: "J416sAP", cpid: 0x6020, bdid: 0x06, chip: "M2 Pro", .left(1, of: 2, magSafe: true)),
        .silicon("Mac14,6", .macBookPro, "MacBook Pro (16-inch, M2 Max, 2023)", board: "J416cAP", cpid: 0x6021, bdid: 0x06, chip: "M2 Max", .left(1, of: 2, magSafe: true)),
        .silicon("Mac14,13", .macStudio, "Mac Studio (M2 Max, 2023)", board: "J475cAP", cpid: 0x6021, bdid: 0x0A, chip: "M2 Max", .back(4, of: 4)),
        .silicon("Mac14,14", .macStudio, "Mac Studio (M2 Ultra, 2023)", board: "J475dAP", cpid: 0x6022, bdid: 0x0A, chip: "M2 Ultra", .back(4, of: 4)),
        .silicon("Mac14,8", .macPro, "Mac Pro (M2 Ultra, 2023 - Tower / Rack)", board: "J180dAP", cpid: 0x6022, bdid: 0x08, chip: "M2 Ultra", .tower(2, of: 2)),
        .silicon("Mac15,3", .macBookPro, "MacBook Pro (14-inch, M3, Nov 2023)", board: "J504AP", cpid: 0x8122, bdid: 0x22, chip: "M3", .left(1, of: 2, magSafe: true)),
        .silicon("Mac15,6", .macBookPro, "MacBook Pro (14-inch, M3 Pro, Nov 2023)", board: "J514sAP", cpid: 0x6030, bdid: 0x04, chip: "M3 Pro", .left(1, of: 2, magSafe: true)),
        .silicon("Mac15,8", .macBookPro, "MacBook Pro (14-inch, M3 Max 16-core, Nov 2023)", board: "J514cAP", cpid: 0x6031, bdid: 0x44, chip: "M3 Max", .left(1, of: 2, magSafe: true)),
        .silicon("Mac15,10", .macBookPro, "MacBook Pro (14-inch, M3 Max 14-core, Nov 2023)", board: "J514mAP", cpid: 0x6034, bdid: 0x44, chip: "M3 Max", .left(1, of: 2, magSafe: true)),
        .silicon("Mac15,7", .macBookPro, "MacBook Pro (16-inch, M3 Pro, Nov 2023)", board: "J516sAP", cpid: 0x6030, bdid: 0x06, chip: "M3 Pro", .left(1, of: 2, magSafe: true)),
        .silicon("Mac15,9", .macBookPro, "MacBook Pro (16-inch, M3 Max 16-core, Nov 2023)", board: "J516cAP", cpid: 0x6031, bdid: 0x46, chip: "M3 Max", .left(1, of: 2, magSafe: true)),
        .silicon("Mac15,11", .macBookPro, "MacBook Pro (16-inch, M3 Max 14-core, Nov 2023)", board: "J516mAP", cpid: 0x6034, bdid: 0x46, chip: "M3 Max", .left(1, of: 2, magSafe: true)),
        .silicon("Mac15,4", .iMac, "iMac (24-inch, M3, 2023 - 2 Ports)", board: "J433AP", cpid: 0x8122, bdid: 0x28, chip: "M3", .back(2, of: 2)),
        .silicon("Mac15,5", .iMac, "iMac (24-inch, M3, 2023 - 4 Ports)", board: "J434AP", cpid: 0x8122, bdid: 0x2A, chip: "M3", .back(4, of: 4)),
        .silicon("Mac15,12", .macBookAir, "MacBook Air (13-inch, M3, 2024)", board: "J613AP", cpid: 0x8122, bdid: 0x30, chip: "M3", .left(1, of: 2, magSafe: true)),
        .silicon("Mac15,13", .macBookAir, "MacBook Air (15-inch, M3, 2024)", board: "J615AP", cpid: 0x8122, bdid: 0x32, chip: "M3", .left(1, of: 2, magSafe: true)),
        .silicon("Mac15,14", .macStudio, "Mac Studio (M3 Ultra, 2025)", board: "J575dAP", cpid: 0x6032, bdid: 0x44, chip: "M3 Ultra", .back(4, of: 4)),
        .silicon("Mac16,1", .macBookPro, "MacBook Pro (14-inch, M4 base, Nov 2024)", board: "J604AP", cpid: 0x8132, bdid: 0x22, chip: "M4", .left(2, of: 2, magSafe: true, exception: true)),
        .silicon("Mac16,8", .macBookPro, "MacBook Pro (14-inch, M4 Pro, Nov 2024)", board: "J614sAP", cpid: 0x6040, bdid: 0x04, chip: "M4 Pro", .left(1, of: 2, magSafe: true)),
        .silicon("Mac16,6", .macBookPro, "MacBook Pro (14-inch, M4 Max, Nov 2024)", board: "J614cAP", cpid: 0x6041, bdid: 0x04, chip: "M4 Max", .left(1, of: 2, magSafe: true)),
        .silicon("Mac16,7", .macBookPro, "MacBook Pro (16-inch, M4 Pro, Nov 2024)", board: "J616sAP", cpid: 0x6040, bdid: 0x06, chip: "M4 Pro", .left(1, of: 2, magSafe: true)),
        .silicon("Mac16,5", .macBookPro, "MacBook Pro (16-inch, M4 Max, Nov 2024)", board: "J616cAP", cpid: 0x6041, bdid: 0x06, chip: "M4 Max", .left(1, of: 2, magSafe: true)),
        .silicon("Mac16,10", .macMini, "Mac mini (M4, 2024)", board: "J773gAP", cpid: 0x8132, bdid: 0x2A, chip: "M4", .back(2, of: 3, exception: true)),
        .silicon("Mac16,11", .macMini, "Mac mini (M4 Pro, 2024)", board: "J773sAP", cpid: 0x6040, bdid: 0x02, chip: "M4 Pro", .back(2, of: 3, exception: true)),
        .silicon("Mac16,2", .iMac, "iMac (24-inch, M4, 2024 - 2 Ports)", board: "J623AP", cpid: 0x8132, bdid: 0x24, chip: "M4", .back(2, of: 2)),
        .silicon("Mac16,3", .iMac, "iMac (24-inch, M4, 2024 - 4 Ports)", board: "J624AP", cpid: 0x8132, bdid: 0x26, chip: "M4", .back(4, of: 4)),
        .silicon("Mac16,12", .macBookAir, "MacBook Air (13-inch, M4, 2025)", board: "J713AP", cpid: 0x8132, bdid: 0x2C, chip: "M4", .left(2, of: 2, magSafe: true, exception: true)),
        .silicon("Mac16,13", .macBookAir, "MacBook Air (15-inch, M4, 2025)", board: "J715AP", cpid: 0x8132, bdid: 0x2E, chip: "M4", .left(2, of: 2, magSafe: true, exception: true)),
        .silicon("Mac16,9", .macStudio, "Mac Studio (M4 Max, 2025)", board: "J575cAP", cpid: 0x6041, bdid: 0x02, chip: "M4 Max", .back(4, of: 4)),
        .silicon("Mac17,5", .macBookNeo, "MacBook Neo", board: "J700AP", cpid: 0x8140, bdid: 0x64, chip: "silicon", .left(1, of: 2)),
        .silicon("Mac17,2", .macBookPro, "MacBook Pro (14-inch, M5 base)", board: "J704AP", cpid: 0x8142, bdid: 0x22, chip: "M5", .left(2, of: 2, magSafe: true, exception: true)),
        .silicon("Mac17,9", .macBookPro, "MacBook Pro (14-inch, M5 Pro)", board: "J714sAP", cpid: 0x6050, bdid: 0x08, chip: "M5 Pro", .left(1, of: 2, magSafe: true)),
        .silicon("Mac17,7", .macBookPro, "MacBook Pro (14-inch, M5 Max)", board: "J714cAP", cpid: 0x6050, bdid: 0x0A, chip: "M5 Max", .left(1, of: 2, magSafe: true)),
        .silicon("Mac17,8", .macBookPro, "MacBook Pro (16-inch, M5 Pro)", board: "J716sAP", cpid: 0x6050, bdid: 0x0C, chip: "M5 Pro", .left(1, of: 2, magSafe: true)),
        .silicon("Mac17,6", .macBookPro, "MacBook Pro (16-inch, M5 Max)", board: "J716cAP", cpid: 0x6050, bdid: 0x0E, chip: "M5 Max", .left(1, of: 2, magSafe: true)),
        .silicon("Mac17,13", .macBookPro, "MacBook Pro (14-inch PROLED XDR, M5 Pro)", board: "K114sAP", cpid: 0x6050, bdid: 0x14, chip: "M5 Pro", .left(1, of: 2, magSafe: true)),
        .silicon("Mac17,11", .macBookPro, "MacBook Pro (14-inch PROLED XDR, M5 Max)", board: "K114cAP", cpid: 0x6050, bdid: 0x04, chip: "M5 Max", .left(1, of: 2, magSafe: true)),
        .silicon("Mac17,12", .macBookPro, "MacBook Pro (16-inch PROLED XDR, M5 Pro)", board: "K116sAP", cpid: 0x6050, bdid: 0x16, chip: "M5 Pro", .left(1, of: 2, magSafe: true)),
        .silicon("Mac17,10", .macBookPro, "MacBook Pro (16-inch PROLED XDR, M5 Max)", board: "K116cAP", cpid: 0x6050, bdid: 0x06, chip: "M5 Max", .left(1, of: 2, magSafe: true)),
        .silicon("Mac17,3", .macBookAir, "MacBook Air (13-inch, M5)", board: "J813AP", cpid: 0x8142, bdid: 0x24, chip: "M5", .left(2, of: 2, magSafe: true, exception: true)),
        .silicon("Mac17,4", .macBookAir, "MacBook Air (15-inch, M5)", board: "J815AP", cpid: 0x8142, bdid: 0x26, chip: "M5", .left(2, of: 2, magSafe: true, exception: true)),
        .silicon("Mac17,16", .macMini, "Mac mini (M5 Pro)", board: "J873sAP", cpid: 0x6050, bdid: 0x02, chip: "M5 Pro", .back(2, of: 3, exception: true)),
        .silicon("Mac17,14", .macStudio, "Mac Studio (M5 Max)", board: "J775cAP", cpid: 0x6050, bdid: 0x10, chip: "M5 Max", .back(4, of: 4)),
        .silicon("Mac17,15", .macStudio, "Mac Studio (M5 Ultra)", board: "J775dAP", cpid: 0x6050, bdid: 0x12, chip: "M5 Ultra", .back(4, of: 4)),
        .silicon("Mac18,1", .macBookPro, "MacBook Pro (14-inch, M6 base)", board: "J804AP", cpid: 0x8152, bdid: 0x22, chip: "M6", .left(2, of: 2, magSafe: true, exception: true)),
        .silicon("Mac18,2", .iMac, "iMac (24-inch, M6)", board: "J833ctAP", cpid: 0x8152, bdid: 0x26, chip: "M6", .back(4, of: 4)),
        .silicon("Mac18,5", .macMini, "Mac mini (M6)", board: "J873gAP", cpid: 0x8152, bdid: 0x24, chip: "M6", .back(2, of: 3, exception: true)),
    ]

    // MARK: Intel with the Apple T2 chip (2017–2020)

    static let intelT2: [MacModel] = [
        .t2("iBridge2,1", "iMacPro1,1", .iMacPro, "iMac Pro (2017)", board: "J137AP", bdid: 0x0A, .back(4, of: 4)),
        .t2("iBridge2,3", "MacBookPro15,1", .macBookPro, "MacBook Pro (15-inch, 2018 / 2019)", board: "J680AP", bdid: 0x0B, .left(2, of: 2)),
        .t2("iBridge2,7", "MacBookPro15,3", .macBookPro, "MacBook Pro (15-inch, 2018 / 2019 Vega)", board: "J780AP", bdid: 0x07, .left(2, of: 2)),
        .t2("iBridge2,4", "MacBookPro15,2", .macBookPro, "MacBook Pro (13-inch, 2018 / 2019, Four TB3 Ports)", board: "J132AP", bdid: 0x0C, .left(2, of: 2)),
        .t2("iBridge2,10", "MacBookPro15,4", .macBookPro, "MacBook Pro (13-inch, 2019, Two TB3 Ports)", board: "J213AP", bdid: 0x18, .left(2, of: 2)),
        .t2("iBridge2,14", "MacBookPro16,1", .macBookPro, "MacBook Pro (16-inch, 2019)", board: "J152fAP", bdid: 0x3A, .left(2, of: 2)),
        .t2("iBridge2,22", "MacBookPro16,4", .macBookPro, "MacBook Pro (16-inch, 2019 - Radeon Pro 5600M)", board: "J215AP", bdid: 0x38, .left(2, of: 2)),
        .t2("iBridge2,16", "MacBookPro16,2", .macBookPro, "MacBook Pro (13-inch, 2020 Intel, Four TB3 Ports)", board: "J214kAP", bdid: 0x3E, .left(2, of: 2)),
        .t2("iBridge2,21", "MacBookPro16,3", .macBookPro, "MacBook Pro (13-inch, 2020 Intel, Two TB3 Ports)", board: "J223AP", bdid: 0x3B, .left(2, of: 2)),
        .t2("iBridge2,8", "MacBookAir8,1", .macBookAir, "MacBook Air (Retina, 13-inch, 2018)", board: "J140kAP", bdid: 0x17, .left(2, of: 2)),
        .t2("iBridge2,12", "MacBookAir8,2", .macBookAir, "MacBook Air (Retina, 13-inch, 2019)", board: "J140aAP", bdid: 0x37, .left(2, of: 2)),
        .t2("iBridge2,15", "MacBookAir9,1", .macBookAir, "MacBook Air (Retina, 13-inch, 2020 Intel)", board: "J230kAP", bdid: 0x3F, .left(2, of: 2)),
        .t2("iBridge2,5", "Macmini8,1", .macMini, "Mac mini (2018 Intel)", board: "J174AP", bdid: 0x0E, .back(4, of: 4)),
        .t2("iBridge2,19", "iMac20,1", .iMac, "iMac (Retina 5K, 27-inch, 2020 Intel)", board: "J185AP", bdid: 0x22, .back(2, of: 2)),
        .t2("iBridge2,20", "iMac20,2", .iMac, "iMac (Retina 5K, 27-inch, 2020 Intel - Radeon Pro 5700/XT)", board: "J185fAP", bdid: 0x23, .back(2, of: 2)),
        .t2("iBridge2,6", "MacPro7,1", .macPro, "Mac Pro (2019 Intel - Tower / Rack)", board: "J160AP", bdid: 0x0F, .tower(2, of: 2)),
    ]

    // MARK: Intel with USB-C but no T2 — no DFU, Target Disk Mode only

    static let intelLegacy: [MacModel] = [
        .legacy("MacBook8,1 / 9,1 / 10,1", .macBook, "MacBook (Retina, 12-inch, 2015–2017)", chip: "Intel"),
        .legacy("MacBookPro13,1 / 14,1", .macBookPro, "MacBook Pro (13-inch, 2016–2017, two ports)", chip: "Intel"),
        .legacy("MacBookPro13,2 / 13,3 / 14,2 / 14,3", .macBookPro, "MacBook Pro (13- and 15-inch, 2016–2017, Touch Bar)", chip: "Intel + T1"),
        .legacy("iMac18,1 / 18,2 / 18,3", .iMac, "iMac (21.5- and 27-inch, 2017)", chip: "Intel"),
        .legacy("iMac19,1 / 19,2", .iMac, "iMac (21.5- and 27-inch, 2019)", chip: "Intel"),
    ]

    // MARK: Lookup

    /// The Mac a device in DFU identifies as.
    static func model(cpid: UInt16, bdid: UInt8) -> MacModel? {
        all.first { $0.cpid == cpid && $0.bdid == bdid }
    }

    /// The Mac whose logic board has this name, e.g. `J813AP` — how the host identifies itself.
    static func model(board: String) -> MacModel? {
        let wanted = board.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !wanted.isEmpty else { return nil }
        return all.first { $0.board?.caseInsensitiveCompare(wanted) == .orderedSame }
    }

    /// The Mac a running macOS advertises over USB: `bcdDevice` carries the two numbers of the model
    /// identifier in BCD (0x1603 → "16,3") but not the family prefix, so more than one Mac can share a
    /// value (`MacBookPro18,1` and `Mac18,1`). `productName` breaks the tie when it can; when it cannot,
    /// the answer is `nil` — an unnamed Mac is better than the wrong one.
    static func model(bootedBCDDevice bcd: UInt16, productName: String = "") -> MacModel? {
        let high = (bcd >> 8) & 0xFF
        let low = bcd & 0xFF
        let major = (high >> 4) * 10 + (high & 0x0F)
        let minor = (low >> 4) * 10 + (low & 0x0F)
        let suffix = "\(major),\(minor)"

        let candidates = appleSilicon.filter { model in
            guard let lastLetter = model.modelIdentifier.lastIndex(where: \.isLetter) else { return false }
            return model.modelIdentifier[model.modelIdentifier.index(after: lastLetter)...] == suffix
        }
        if candidates.count <= 1 { return candidates.first }

        let named = candidates.filter { productName.localizedCaseInsensitiveContains($0.family.rawValue) }
        return named.count == 1 ? named.first : nil
    }
}
