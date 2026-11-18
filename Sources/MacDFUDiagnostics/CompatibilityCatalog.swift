import Foundation

enum MacArchitectureCategory: String, CaseIterable, Identifiable, Equatable, Sendable {
    case appleSilicon = "appleSilicon"
    case intelT2 = "intelT2"
    case intelPreT2 = "intelPreT2"

    var id: String { rawValue }

    func title(in lang: AppLanguage) -> String {
        switch self {
        case .appleSilicon:
            lang.text("Apple Silicon (M1–M6)", "Apple Silicon (M1–M6)")
        case .intelT2:
            lang.text("Intel con Chip Apple T2 (2017–2020)", "Intel with Apple T2 Chip (2017–2020)")
        case .intelPreT2:
            lang.text("Intel Pre-T2 con USB-C / TB3 (2015–2019)", "Pre-T2 Intel with USB-C / TB3 (2015–2019)")
        }
    }

    func shortBadge(in lang: AppLanguage) -> String {
        switch self {
        case .appleSilicon:
            lang.text("DFU + VDM Nativo", "Native DFU + VDM")
        case .intelT2:
            lang.text("DFU T2 (bridgeOS)", "T2 DFU (bridgeOS)")
        case .intelPreT2:
            lang.text("NO DFU • Solo TDM", "NO DFU • TDM Only")
        }
    }

    var supportsDFU: Bool {
        switch self {
        case .appleSilicon, .intelT2: true
        case .intelPreT2: false
        }
    }
}

enum PortPanelFace: String, Equatable, Sendable {
    case leftSide = "leftSide"
    case backPanel = "backPanel"
    case topOrFront = "topOrFront"
    case none = "none"

    func label(in lang: AppLanguage) -> String {
        switch self {
        case .leftSide:
            lang.text("Vista Lato Sinistro (Cerniera a Sinistra → Fronte a Destra)", "Left Side View (Hinge on Left → Front on Right)")
        case .backPanel:
            lang.text("Vista Pannello Posteriore (Sinistra → Destra)", "Rear Panel View (Left → Right)")
        case .topOrFront:
            lang.text("Case Tower (Sopra) / Rack (Fronte)", "Tower Enclosure (Top) / Rack (Front)")
        case .none:
            lang.text("Nessuna Porta DFU", "No DFU Port")
        }
    }
}

struct PortVisualLayout: Hashable, Equatable, Sendable {
    let face: PortPanelFace
    let totalUSBCPortsOnFace: Int
    let dfuPortIndexOneBased: Int?    // 1 = leftmost, 2 = second/middle, etc.
    let hasMagSafeOnLeft: Bool
    let isExceptionHT120694: Bool
}

struct CompatibleMacSpec: Identifiable, Hashable, Equatable, Sendable {
    let id: String
    let category: MacArchitectureCategory
    let family: String
    let marketingName: String
    let modelIdentifier: String
    let dfuTargetIdentifier: String
    let boardConfig: String
    let cpid: UInt16?
    let bdid: UInt8?
    let chipNameIT: String
    let chipNameEN: String
    let dfuPortLocationIT: String
    let dfuPortLocationEN: String
    let vdmSupportNoteIT: String
    let vdmSupportNoteEN: String
    let restoreBehaviorNoteIT: String
    let restoreBehaviorNoteEN: String
    let supportedDiagnosticsIT: [String]
    let supportedDiagnosticsEN: [String]
    let portVisual: PortVisualLayout

    var cpidHex: String {
        guard let cpid else { return "N/A" }
        return String(format: "0x%04X", cpid)
    }

    var bdidHex: String {
        guard let bdid else { return "N/A" }
        return String(format: "0x%02X", bdid)
    }

    func chipName(in lang: AppLanguage) -> String {
        lang == .it ? chipNameIT : chipNameEN
    }

    func dfuPortLocation(in lang: AppLanguage) -> String {
        lang == .it ? dfuPortLocationIT : dfuPortLocationEN
    }

    func vdmSupportNote(in lang: AppLanguage) -> String {
        lang == .it ? vdmSupportNoteIT : vdmSupportNoteEN
    }

    func restoreBehaviorNote(in lang: AppLanguage) -> String {
        lang == .it ? restoreBehaviorNoteIT : restoreBehaviorNoteEN
    }

    func supportedDiagnostics(in lang: AppLanguage) -> [String] {
        lang == .it ? supportedDiagnosticsIT : supportedDiagnosticsEN
    }
}

enum CompatibilityCatalog {
    static let allSpecs: [CompatibleMacSpec] = appleSiliconSpecs + intelT2Specs + intelPreT2Specs

    // MARK: - 1. Apple Silicon Macs (M1 -> M6)
    static let appleSiliconSpecs: [CompatibleMacSpec] = [
        // M1
        specSilicon(
            id: "MacBookAir10,1", family: "MacBook Air", name: "MacBook Air (M1, 2020)", board: "J313AP", cpid: 0x8103, bdid: 0x26, chip: "Apple M1",
            portIT: "Lato sinistro: porta USB-C più a sinistra (più vicina alla cerniera/schermo).",
            portEN: "Left side: leftmost USB-C port (closest to the display hinge).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "MacBookPro17,1", family: "MacBook Pro", name: "MacBook Pro (13-inch, M1, 2020)", board: "J293AP", cpid: 0x8103, bdid: 0x24, chip: "Apple M1",
            portIT: "Lato sinistro: porta USB-C più a sinistra (più vicina alla cerniera/schermo).",
            portEN: "Left side: leftmost USB-C port (closest to the display hinge).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Macmini9,1", family: "Mac mini", name: "Mac mini (M1, 2020)", board: "J274AP", cpid: 0x8103, bdid: 0x22, chip: "Apple M1",
            portIT: "Retro (visto da dietro): porta Thunderbolt/USB-C più a sinistra (vicina al cavo di alimentazione).",
            portEN: "Back panel: leftmost Thunderbolt/USB-C port (closest to the power cord).",
            visual: .init(face: .backPanel, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "iMac21,1", family: "iMac", name: "iMac (24-inch, M1, 2021 - 2 Ports)", board: "J456AP", cpid: 0x8103, bdid: 0x28, chip: "Apple M1",
            portIT: "Retro (visto da dietro): porta USB-C più a destra (vicina al pulsante d'accensione).",
            portEN: "Back panel: rightmost USB-C port (closest to the power button).",
            visual: .init(face: .backPanel, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 2, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "iMac21,2", family: "iMac", name: "iMac (24-inch, M1, 2021 - 4 Ports)", board: "J457AP", cpid: 0x8103, bdid: 0x2A, chip: "Apple M1",
            portIT: "Retro (visto da dietro): porta Thunderbolt/USB-C più a destra.",
            portEN: "Back panel: rightmost Thunderbolt/USB-C port.",
            visual: .init(face: .backPanel, totalUSBCPortsOnFace: 4, dfuPortIndexOneBased: 4, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "MacBookPro18,3", family: "MacBook Pro", name: "MacBook Pro (14-inch, M1 Pro, 2021)", board: "J314sAP", cpid: 0x6000, bdid: 0x08, chip: "Apple M1 Pro",
            portIT: "Lato sinistro: porta USB-C più a sinistra (subito accanto a MagSafe 3).",
            portEN: "Left side: leftmost USB-C port (immediately next to MagSafe 3).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: true, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "MacBookPro18,4", family: "MacBook Pro", name: "MacBook Pro (14-inch, M1 Max, 2021)", board: "J314cAP", cpid: 0x6001, bdid: 0x08, chip: "Apple M1 Max",
            portIT: "Lato sinistro: porta USB-C più a sinistra (subito accanto a MagSafe 3).",
            portEN: "Left side: leftmost USB-C port (immediately next to MagSafe 3).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: true, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "MacBookPro18,1", family: "MacBook Pro", name: "MacBook Pro (16-inch, M1 Pro, 2021)", board: "J316sAP", cpid: 0x6000, bdid: 0x0A, chip: "Apple M1 Pro",
            portIT: "Lato sinistro: porta USB-C più a sinistra (subito accanto a MagSafe 3).",
            portEN: "Left side: leftmost USB-C port (immediately next to MagSafe 3).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: true, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "MacBookPro18,2", family: "MacBook Pro", name: "MacBook Pro (16-inch, M1 Max, 2021)", board: "J316cAP", cpid: 0x6001, bdid: 0x0A, chip: "Apple M1 Max",
            portIT: "Lato sinistro: porta USB-C più a sinistra (subito accanto a MagSafe 3).",
            portEN: "Left side: leftmost USB-C port (immediately next to MagSafe 3).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: true, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac13,1", family: "Mac Studio", name: "Mac Studio (M1 Max, 2022)", board: "J375cAP", cpid: 0x6001, bdid: 0x04, chip: "Apple M1 Max",
            portIT: "Retro (visto da dietro): porta Thunderbolt/USB-C più a destra.",
            portEN: "Back panel: rightmost Thunderbolt/USB-C port.",
            visual: .init(face: .backPanel, totalUSBCPortsOnFace: 4, dfuPortIndexOneBased: 4, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac13,2", family: "Mac Studio", name: "Mac Studio (M1 Ultra, 2022)", board: "J375dAP", cpid: 0x6002, bdid: 0x0C, chip: "Apple M1 Ultra",
            portIT: "Retro (visto da dietro): porta Thunderbolt/USB-C più a destra.",
            portEN: "Back panel: rightmost Thunderbolt/USB-C port.",
            visual: .init(face: .backPanel, totalUSBCPortsOnFace: 4, dfuPortIndexOneBased: 4, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),

        // M2
        specSilicon(
            id: "Mac14,2", family: "MacBook Air", name: "MacBook Air (13-inch, M2, 2022)", board: "J413AP", cpid: 0x8112, bdid: 0x28, chip: "Apple M2",
            portIT: "Lato sinistro: porta USB-C più a sinistra (subito accanto a MagSafe 3).",
            portEN: "Left side: leftmost USB-C port (next to MagSafe 3).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: true, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac14,15", family: "MacBook Air", name: "MacBook Air (15-inch, M2, 2023)", board: "J415AP", cpid: 0x8112, bdid: 0x2E, chip: "Apple M2",
            portIT: "Lato sinistro: porta USB-C più a sinistra (subito accanto a MagSafe 3).",
            portEN: "Left side: leftmost USB-C port (next to MagSafe 3).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: true, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac14,7", family: "MacBook Pro", name: "MacBook Pro (13-inch, M2, 2022)", board: "J493AP", cpid: 0x8112, bdid: 0x2A, chip: "Apple M2",
            portIT: "Lato sinistro: porta USB-C più a sinistra (più vicina alla cerniera).",
            portEN: "Left side: leftmost USB-C port (closest to the hinge).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac14,3", family: "Mac mini", name: "Mac mini (M2, 2023)", board: "J473AP", cpid: 0x8112, bdid: 0x24, chip: "Apple M2",
            portIT: "Retro (visto da dietro): porta Thunderbolt/USB-C più a sinistra.",
            portEN: "Back panel: leftmost Thunderbolt/USB-C port.",
            visual: .init(face: .backPanel, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac14,12", family: "Mac mini", name: "Mac mini (M2 Pro, 2023)", board: "J474sAP", cpid: 0x6020, bdid: 0x02, chip: "Apple M2 Pro",
            portIT: "Retro (visto da dietro): porta Thunderbolt/USB-C più a sinistra.",
            portEN: "Back panel: leftmost Thunderbolt/USB-C port.",
            visual: .init(face: .backPanel, totalUSBCPortsOnFace: 4, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac14,9", family: "MacBook Pro", name: "MacBook Pro (14-inch, M2 Pro, 2023)", board: "J414sAP", cpid: 0x6020, bdid: 0x04, chip: "Apple M2 Pro",
            portIT: "Lato sinistro: porta USB-C più a sinistra (accanto a MagSafe 3).",
            portEN: "Left side: leftmost USB-C port (next to MagSafe 3).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: true, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac14,5", family: "MacBook Pro", name: "MacBook Pro (14-inch, M2 Max, 2023)", board: "J414cAP", cpid: 0x6021, bdid: 0x04, chip: "Apple M2 Max",
            portIT: "Lato sinistro: porta USB-C più a sinistra (accanto a MagSafe 3).",
            portEN: "Left side: leftmost USB-C port (next to MagSafe 3).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: true, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac14,10", family: "MacBook Pro", name: "MacBook Pro (16-inch, M2 Pro, 2023)", board: "J416sAP", cpid: 0x6020, bdid: 0x06, chip: "Apple M2 Pro",
            portIT: "Lato sinistro: porta USB-C più a sinistra (accanto a MagSafe 3).",
            portEN: "Left side: leftmost USB-C port (next to MagSafe 3).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: true, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac14,6", family: "MacBook Pro", name: "MacBook Pro (16-inch, M2 Max, 2023)", board: "J416cAP", cpid: 0x6021, bdid: 0x06, chip: "Apple M2 Max",
            portIT: "Lato sinistro: porta USB-C più a sinistra (accanto a MagSafe 3).",
            portEN: "Left side: leftmost USB-C port (next to MagSafe 3).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: true, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac14,13", family: "Mac Studio", name: "Mac Studio (M2 Max, 2023)", board: "J475cAP", cpid: 0x6021, bdid: 0x0A, chip: "Apple M2 Max",
            portIT: "Retro (visto da dietro): porta Thunderbolt/USB-C più a destra.",
            portEN: "Back panel: rightmost Thunderbolt/USB-C port.",
            visual: .init(face: .backPanel, totalUSBCPortsOnFace: 4, dfuPortIndexOneBased: 4, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac14,14", family: "Mac Studio", name: "Mac Studio (M2 Ultra, 2023)", board: "J475dAP", cpid: 0x6022, bdid: 0x0A, chip: "Apple M2 Ultra",
            portIT: "Retro (visto da dietro): porta Thunderbolt/USB-C più a destra.",
            portEN: "Back panel: rightmost Thunderbolt/USB-C port.",
            visual: .init(face: .backPanel, totalUSBCPortsOnFace: 4, dfuPortIndexOneBased: 4, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac14,8", family: "Mac Pro", name: "Mac Pro (M2 Ultra, 2023 - Tower / Rack)", board: "J180dAP", cpid: 0x6022, bdid: 0x08, chip: "Apple M2 Ultra",
            portIT: "Tower: sulla parte superiore, porta USB-C più lontana dal tasto d'accensione. Rack: sul fronte, porta USB-C più vicina al tasto d'accensione.",
            portEN: "Tower: on top, USB-C port farthest from the power button. Rack: on front, USB-C port closest to the power button.",
            visual: .init(face: .topOrFront, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 2, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),

        // M3
        specSilicon(
            id: "Mac15,3", family: "MacBook Pro", name: "MacBook Pro (14-inch, M3, Nov 2023)", board: "J504AP", cpid: 0x8122, bdid: 0x22, chip: "Apple M3",
            portIT: "Lato sinistro: porta USB-C più a sinistra (accanto a MagSafe 3).",
            portEN: "Left side: leftmost USB-C port (next to MagSafe 3).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: true, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac15,6", family: "MacBook Pro", name: "MacBook Pro (14-inch, M3 Pro, Nov 2023)", board: "J514sAP", cpid: 0x6030, bdid: 0x04, chip: "Apple M3 Pro",
            portIT: "Lato sinistro: porta USB-C più a sinistra (accanto a MagSafe 3).",
            portEN: "Left side: leftmost USB-C port (next to MagSafe 3).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: true, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac15,8", family: "MacBook Pro", name: "MacBook Pro (14-inch, M3 Max 16-core, Nov 2023)", board: "J514cAP", cpid: 0x6031, bdid: 0x44, chip: "Apple M3 Max",
            portIT: "Lato sinistro: porta USB-C più a sinistra (accanto a MagSafe 3).",
            portEN: "Left side: leftmost USB-C port (next to MagSafe 3).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: true, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac15,10", family: "MacBook Pro", name: "MacBook Pro (14-inch, M3 Max 14-core, Nov 2023)", board: "J514mAP", cpid: 0x6034, bdid: 0x44, chip: "Apple M3 Max",
            portIT: "Lato sinistro: porta USB-C più a sinistra (accanto a MagSafe 3).",
            portEN: "Left side: leftmost USB-C port (next to MagSafe 3).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: true, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac15,7", family: "MacBook Pro", name: "MacBook Pro (16-inch, M3 Pro, Nov 2023)", board: "J516sAP", cpid: 0x6030, bdid: 0x06, chip: "Apple M3 Pro",
            portIT: "Lato sinistro: porta USB-C più a sinistra (accanto a MagSafe 3).",
            portEN: "Left side: leftmost USB-C port (next to MagSafe 3).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: true, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac15,9", family: "MacBook Pro", name: "MacBook Pro (16-inch, M3 Max 16-core, Nov 2023)", board: "J516cAP", cpid: 0x6031, bdid: 0x46, chip: "Apple M3 Max",
            portIT: "Lato sinistro: porta USB-C più a sinistra (accanto a MagSafe 3).",
            portEN: "Left side: leftmost USB-C port (next to MagSafe 3).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: true, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac15,11", family: "MacBook Pro", name: "MacBook Pro (16-inch, M3 Max 14-core, Nov 2023)", board: "J516mAP", cpid: 0x6034, bdid: 0x46, chip: "Apple M3 Max",
            portIT: "Lato sinistro: porta USB-C più a sinistra (accanto a MagSafe 3).",
            portEN: "Left side: leftmost USB-C port (next to MagSafe 3).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: true, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac15,4", family: "iMac", name: "iMac (24-inch, M3, 2023 - 2 Ports)", board: "J433AP", cpid: 0x8122, bdid: 0x28, chip: "Apple M3",
            portIT: "Retro (visto da dietro): porta USB-C più a destra.",
            portEN: "Back panel: rightmost USB-C port.",
            visual: .init(face: .backPanel, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 2, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac15,5", family: "iMac", name: "iMac (24-inch, M3, 2023 - 4 Ports)", board: "J434AP", cpid: 0x8122, bdid: 0x2A, chip: "Apple M3",
            portIT: "Retro (visto da dietro): porta USB-C più a destra.",
            portEN: "Back panel: rightmost USB-C port.",
            visual: .init(face: .backPanel, totalUSBCPortsOnFace: 4, dfuPortIndexOneBased: 4, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac15,12", family: "MacBook Air", name: "MacBook Air (13-inch, M3, 2024)", board: "J613AP", cpid: 0x8122, bdid: 0x30, chip: "Apple M3",
            portIT: "Lato sinistro: porta USB-C più a sinistra (accanto a MagSafe 3).",
            portEN: "Left side: leftmost USB-C port (next to MagSafe 3).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: true, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac15,13", family: "MacBook Air", name: "MacBook Air (15-inch, M3, 2024)", board: "J615AP", cpid: 0x8122, bdid: 0x32, chip: "Apple M3",
            portIT: "Lato sinistro: porta USB-C più a sinistra (accanto a MagSafe 3).",
            portEN: "Left side: leftmost USB-C port (next to MagSafe 3).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: true, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac15,14", family: "Mac Studio", name: "Mac Studio (M3 Ultra, 2025)", board: "J575dAP", cpid: 0x6032, bdid: 0x44, chip: "Apple M3 Ultra",
            portIT: "Retro (visto da dietro): porta Thunderbolt/USB-C più a destra.",
            portEN: "Back panel: rightmost Thunderbolt/USB-C port.",
            visual: .init(face: .backPanel, totalUSBCPortsOnFace: 4, dfuPortIndexOneBased: 4, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),

        // M4 (with HT120694 exceptions!)
        specSilicon(
            id: "Mac16,1", family: "MacBook Pro", name: "MacBook Pro (14-inch, M4 base, Nov 2024)", board: "J604AP", cpid: 0x8132, bdid: 0x22, chip: "Apple M4",
            portIT: "ECCEZIONE HT120694! Lato sinistro: porta USB-C più a DESTRA (più vicina al trackpad/fronte, NON quella vicina a MagSafe!).",
            portEN: "HT120694 EXCEPTION! Left side: RIGHTMOST USB-C port (closest to trackpad/front, NOT the one next to MagSafe!).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 2, hasMagSafeOnLeft: true, isExceptionHT120694: true)
        ),
        specSilicon(
            id: "Mac16,8", family: "MacBook Pro", name: "MacBook Pro (14-inch, M4 Pro, Nov 2024)", board: "J614sAP", cpid: 0x6040, bdid: 0x04, chip: "Apple M4 Pro",
            portIT: "Lato sinistro: porta USB-C più a sinistra (subito accanto a MagSafe 3).",
            portEN: "Left side: leftmost USB-C port (immediately next to MagSafe 3).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: true, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac16,6", family: "MacBook Pro", name: "MacBook Pro (14-inch, M4 Max, Nov 2024)", board: "J614cAP", cpid: 0x6041, bdid: 0x04, chip: "Apple M4 Max",
            portIT: "Lato sinistro: porta USB-C più a sinistra (subito accanto a MagSafe 3).",
            portEN: "Left side: leftmost USB-C port (immediately next to MagSafe 3).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: true, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac16,7", family: "MacBook Pro", name: "MacBook Pro (16-inch, M4 Pro, Nov 2024)", board: "J616sAP", cpid: 0x6040, bdid: 0x06, chip: "Apple M4 Pro",
            portIT: "Lato sinistro: porta USB-C più a sinistra (subito accanto a MagSafe 3).",
            portEN: "Left side: leftmost USB-C port (immediately next to MagSafe 3).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: true, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac16,5", family: "MacBook Pro", name: "MacBook Pro (16-inch, M4 Max, Nov 2024)", board: "J616cAP", cpid: 0x6041, bdid: 0x06, chip: "Apple M4 Max",
            portIT: "Lato sinistro: porta USB-C più a sinistra (subito accanto a MagSafe 3).",
            portEN: "Left side: leftmost USB-C port (immediately next to MagSafe 3).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: true, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac16,10", family: "Mac mini", name: "Mac mini (M4, 2024)", board: "J773gAP", cpid: 0x8132, bdid: 0x2A, chip: "Apple M4",
            portIT: "ECCEZIONE HT120694! Retro (visto da dietro): porta Thunderbolt/USB-C CENTRALE (quella in mezzo delle 3 porte posteriori).",
            portEN: "HT120694 EXCEPTION! Back panel: MIDDLE Thunderbolt/USB-C port (center of the 3 rear ports).",
            visual: .init(face: .backPanel, totalUSBCPortsOnFace: 3, dfuPortIndexOneBased: 2, hasMagSafeOnLeft: false, isExceptionHT120694: true)
        ),
        specSilicon(
            id: "Mac16,11", family: "Mac mini", name: "Mac mini (M4 Pro, 2024)", board: "J773sAP", cpid: 0x6040, bdid: 0x02, chip: "Apple M4 Pro",
            portIT: "ECCEZIONE HT120694! Retro (visto da dietro): porta Thunderbolt/USB-C CENTRALE (quella in mezzo delle 3 porte posteriori).",
            portEN: "HT120694 EXCEPTION! Back panel: MIDDLE Thunderbolt/USB-C port (center of the 3 rear ports).",
            visual: .init(face: .backPanel, totalUSBCPortsOnFace: 3, dfuPortIndexOneBased: 2, hasMagSafeOnLeft: false, isExceptionHT120694: true)
        ),
        specSilicon(
            id: "Mac16,2", family: "iMac", name: "iMac (24-inch, M4, 2024 - 2 Ports)", board: "J623AP", cpid: 0x8132, bdid: 0x24, chip: "Apple M4",
            portIT: "Retro (visto da dietro): porta USB-C più a destra.",
            portEN: "Back panel: rightmost USB-C port.",
            visual: .init(face: .backPanel, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 2, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac16,3", family: "iMac", name: "iMac (24-inch, M4, 2024 - 4 Ports)", board: "J624AP", cpid: 0x8132, bdid: 0x26, chip: "Apple M4",
            portIT: "Retro (visto da dietro): porta USB-C più a destra.",
            portEN: "Back panel: rightmost USB-C port.",
            visual: .init(face: .backPanel, totalUSBCPortsOnFace: 4, dfuPortIndexOneBased: 4, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac16,12", family: "MacBook Air", name: "MacBook Air (13-inch, M4, 2025)", board: "J713AP", cpid: 0x8132, bdid: 0x2C, chip: "Apple M4",
            portIT: "ECCEZIONE HT120694 (2025+)! Lato sinistro: porta USB-C più a DESTRA (più vicina al trackpad/fronte).",
            portEN: "HT120694 EXCEPTION (2025+)! Left side: RIGHTMOST USB-C port (closest to trackpad/front).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 2, hasMagSafeOnLeft: true, isExceptionHT120694: true)
        ),
        specSilicon(
            id: "Mac16,13", family: "MacBook Air", name: "MacBook Air (15-inch, M4, 2025)", board: "J715AP", cpid: 0x8132, bdid: 0x2E, chip: "Apple M4",
            portIT: "ECCEZIONE HT120694 (2025+)! Lato sinistro: porta USB-C più a DESTRA (più vicina al trackpad/fronte).",
            portEN: "HT120694 EXCEPTION (2025+)! Left side: RIGHTMOST USB-C port (closest to trackpad/front).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 2, hasMagSafeOnLeft: true, isExceptionHT120694: true)
        ),
        specSilicon(
            id: "Mac16,9", family: "Mac Studio", name: "Mac Studio (M4 Max, 2025)", board: "J575cAP", cpid: 0x6041, bdid: 0x02, chip: "Apple M4 Max",
            portIT: "Retro (visto da dietro): porta Thunderbolt/USB-C più a destra.",
            portEN: "Back panel: rightmost Thunderbolt/USB-C port.",
            visual: .init(face: .backPanel, totalUSBCPortsOnFace: 4, dfuPortIndexOneBased: 4, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),

        // M5 & M6 & Neo
        specSilicon(
            id: "Mac17,5", family: "MacBook Neo", name: "MacBook Neo", board: "J700AP", cpid: 0x8140, bdid: 0x64, chip: "Apple Silicon (J700AP)",
            portIT: "Lato sinistro: porta USB-C più a sinistra (più vicina alla cerniera).",
            portEN: "Left side: leftmost USB-C port (closest to the hinge).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac17,2", family: "MacBook Pro", name: "MacBook Pro (14-inch, M5 base)", board: "J704AP", cpid: 0x8142, bdid: 0x22, chip: "Apple M5",
            portIT: "ECCEZIONE HT120694! Lato sinistro: porta USB-C più a DESTRA (più vicina al trackpad/fronte).",
            portEN: "HT120694 EXCEPTION! Left side: RIGHTMOST USB-C port (closest to trackpad/front).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 2, hasMagSafeOnLeft: true, isExceptionHT120694: true)
        ),
        specSilicon(
            id: "Mac17,9", family: "MacBook Pro", name: "MacBook Pro (14-inch, M5 Pro)", board: "J714sAP", cpid: 0x6050, bdid: 0x08, chip: "Apple M5 Pro",
            portIT: "Lato sinistro: porta USB-C più a sinistra (accanto a MagSafe 3).",
            portEN: "Left side: leftmost USB-C port (next to MagSafe 3).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: true, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac17,7", family: "MacBook Pro", name: "MacBook Pro (14-inch, M5 Max)", board: "J714cAP", cpid: 0x6050, bdid: 0x0A, chip: "Apple M5 Max",
            portIT: "Lato sinistro: porta USB-C più a sinistra (accanto a MagSafe 3).",
            portEN: "Left side: leftmost USB-C port (next to MagSafe 3).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: true, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac17,8", family: "MacBook Pro", name: "MacBook Pro (16-inch, M5 Pro)", board: "J716sAP", cpid: 0x6050, bdid: 0x0C, chip: "Apple M5 Pro",
            portIT: "Lato sinistro: porta USB-C più a sinistra (accanto a MagSafe 3).",
            portEN: "Left side: leftmost USB-C port (next to MagSafe 3).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: true, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac17,6", family: "MacBook Pro", name: "MacBook Pro (16-inch, M5 Max)", board: "J716cAP", cpid: 0x6050, bdid: 0x0E, chip: "Apple M5 Max",
            portIT: "Lato sinistro: porta USB-C più a sinistra (accanto a MagSafe 3).",
            portEN: "Left side: leftmost USB-C port (next to MagSafe 3).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: true, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac17,13", family: "MacBook Pro", name: "MacBook Pro (14-inch PROLED XDR, M5 Pro)", board: "K114sAP", cpid: 0x6050, bdid: 0x14, chip: "Apple M5 Pro",
            portIT: "Lato sinistro: porta USB-C più a sinistra (accanto a MagSafe 3).",
            portEN: "Left side: leftmost USB-C port (next to MagSafe 3).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: true, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac17,11", family: "MacBook Pro", name: "MacBook Pro (14-inch PROLED XDR, M5 Max)", board: "K114cAP", cpid: 0x6050, bdid: 0x04, chip: "Apple M5 Max",
            portIT: "Lato sinistro: porta USB-C più a sinistra (accanto a MagSafe 3).",
            portEN: "Left side: leftmost USB-C port (next to MagSafe 3).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: true, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac17,12", family: "MacBook Pro", name: "MacBook Pro (16-inch PROLED XDR, M5 Pro)", board: "K116sAP", cpid: 0x6050, bdid: 0x16, chip: "Apple M5 Pro",
            portIT: "Lato sinistro: porta USB-C più a sinistra (accanto a MagSafe 3).",
            portEN: "Left side: leftmost USB-C port (next to MagSafe 3).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: true, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac17,10", family: "MacBook Pro", name: "MacBook Pro (16-inch PROLED XDR, M5 Max)", board: "K116cAP", cpid: 0x6050, bdid: 0x06, chip: "Apple M5 Max",
            portIT: "Lato sinistro: porta USB-C più a sinistra (accanto a MagSafe 3).",
            portEN: "Left side: leftmost USB-C port (next to MagSafe 3).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 1, hasMagSafeOnLeft: true, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac17,3", family: "MacBook Air", name: "MacBook Air (13-inch, M5)", board: "J813AP", cpid: 0x8142, bdid: 0x24, chip: "Apple M5",
            portIT: "ECCEZIONE HT120694 (2025+)! Lato sinistro: porta USB-C più a DESTRA (più vicina al trackpad/fronte).",
            portEN: "HT120694 EXCEPTION (2025+)! Left side: RIGHTMOST USB-C port (closest to trackpad/front).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 2, hasMagSafeOnLeft: true, isExceptionHT120694: true)
        ),
        specSilicon(
            id: "Mac17,4", family: "MacBook Air", name: "MacBook Air (15-inch, M5)", board: "J815AP", cpid: 0x8142, bdid: 0x26, chip: "Apple M5",
            portIT: "ECCEZIONE HT120694 (2025+)! Lato sinistro: porta USB-C più a DESTRA (più vicina al trackpad/fronte).",
            portEN: "HT120694 EXCEPTION (2025+)! Left side: RIGHTMOST USB-C port (closest to trackpad/front).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 2, hasMagSafeOnLeft: true, isExceptionHT120694: true)
        ),
        specSilicon(
            id: "Mac17,16", family: "Mac mini", name: "Mac mini (M5 Pro)", board: "J873sAP", cpid: 0x6050, bdid: 0x02, chip: "Apple M5 Pro",
            portIT: "ECCEZIONE HT120694! Retro (visto da dietro): porta Thunderbolt/USB-C CENTRALE.",
            portEN: "HT120694 EXCEPTION! Back panel: MIDDLE Thunderbolt/USB-C port.",
            visual: .init(face: .backPanel, totalUSBCPortsOnFace: 3, dfuPortIndexOneBased: 2, hasMagSafeOnLeft: false, isExceptionHT120694: true)
        ),
        specSilicon(
            id: "Mac17,14", family: "Mac Studio", name: "Mac Studio (M5 Max)", board: "J775cAP", cpid: 0x6050, bdid: 0x10, chip: "Apple M5 Max",
            portIT: "Retro (visto da dietro): porta Thunderbolt/USB-C più a destra.",
            portEN: "Back panel: rightmost Thunderbolt/USB-C port.",
            visual: .init(face: .backPanel, totalUSBCPortsOnFace: 4, dfuPortIndexOneBased: 4, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac17,15", family: "Mac Studio", name: "Mac Studio (M5 Ultra)", board: "J775dAP", cpid: 0x6050, bdid: 0x12, chip: "Apple M5 Ultra",
            portIT: "Retro (visto da dietro): porta Thunderbolt/USB-C più a destra.",
            portEN: "Back panel: rightmost Thunderbolt/USB-C port.",
            visual: .init(face: .backPanel, totalUSBCPortsOnFace: 4, dfuPortIndexOneBased: 4, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac18,1", family: "MacBook Pro", name: "MacBook Pro (14-inch, M6 base)", board: "J804AP", cpid: 0x8152, bdid: 0x22, chip: "Apple M6",
            portIT: "ECCEZIONE HT120694! Lato sinistro: porta USB-C più a DESTRA (più vicina al trackpad/fronte).",
            portEN: "HT120694 EXCEPTION! Left side: RIGHTMOST USB-C port (closest to trackpad/front).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 2, hasMagSafeOnLeft: true, isExceptionHT120694: true)
        ),
        specSilicon(
            id: "Mac18,2", family: "iMac", name: "iMac (24-inch, M6)", board: "J833ctAP", cpid: 0x8152, bdid: 0x26, chip: "Apple M6",
            portIT: "Retro (visto da dietro): porta USB-C più a destra.",
            portEN: "Back panel: rightmost USB-C port.",
            visual: .init(face: .backPanel, totalUSBCPortsOnFace: 4, dfuPortIndexOneBased: 4, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),
        specSilicon(
            id: "Mac18,5", family: "Mac mini", name: "Mac mini (M6)", board: "J873gAP", cpid: 0x8152, bdid: 0x24, chip: "Apple M6",
            portIT: "ECCEZIONE HT120694! Retro (visto da dietro): porta Thunderbolt/USB-C CENTRALE.",
            portEN: "HT120694 EXCEPTION! Back panel: MIDDLE Thunderbolt/USB-C port.",
            visual: .init(face: .backPanel, totalUSBCPortsOnFace: 3, dfuPortIndexOneBased: 2, hasMagSafeOnLeft: false, isExceptionHT120694: true)
        )
    ]

    // MARK: - 2. Intel Macs with Apple T2 Security Chip (2017–2020, CPID: 0x8012)
    static let intelT2Specs: [CompatibleMacSpec] = [
        specT2(
            ibridge: "iBridge2,1", macID: "iMacPro1,1", family: "iMac Pro", name: "iMac Pro (2017)", board: "J137AP", bdid: 0x0A,
            portIT: "Retro (visto da dietro): porta Thunderbolt 3 (USB-C) più a destra (vicina alla porta Ethernet).",
            portEN: "Back panel: rightmost Thunderbolt 3 (USB-C) port (closest to the Ethernet port).",
            visual: .init(face: .backPanel, totalUSBCPortsOnFace: 4, dfuPortIndexOneBased: 4, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),
        specT2(
            ibridge: "iBridge2,3", macID: "MacBookPro15,1", family: "MacBook Pro", name: "MacBook Pro (15-inch, 2018 / 2019)", board: "J680AP", bdid: 0x0B,
            portIT: "Lato sinistro: porta Thunderbolt 3 (USB-C) più a DESTRA (più vicina al trackpad/fronte).",
            portEN: "Left side: RIGHTMOST Thunderbolt 3 (USB-C) port (closest to trackpad/front).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 2, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),
        specT2(
            ibridge: "iBridge2,7", macID: "MacBookPro15,3", family: "MacBook Pro", name: "MacBook Pro (15-inch, 2018 / 2019 Vega)", board: "J780AP", bdid: 0x07,
            portIT: "Lato sinistro: porta Thunderbolt 3 (USB-C) più a DESTRA (più vicina al trackpad/fronte).",
            portEN: "Left side: RIGHTMOST Thunderbolt 3 (USB-C) port (closest to trackpad/front).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 2, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),
        specT2(
            ibridge: "iBridge2,4", macID: "MacBookPro15,2", family: "MacBook Pro", name: "MacBook Pro (13-inch, 2018 / 2019, Four TB3 Ports)", board: "J132AP", bdid: 0x0C,
            portIT: "Lato sinistro: porta Thunderbolt 3 (USB-C) più a DESTRA (più vicina al trackpad/fronte).",
            portEN: "Left side: RIGHTMOST Thunderbolt 3 (USB-C) port (closest to trackpad/front).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 2, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),
        specT2(
            ibridge: "iBridge2,10", macID: "MacBookPro15,4", family: "MacBook Pro", name: "MacBook Pro (13-inch, 2019, Two TB3 Ports)", board: "J213AP", bdid: 0x18,
            portIT: "Lato sinistro: porta Thunderbolt 3 (USB-C) più a DESTRA (più vicina al trackpad/fronte).",
            portEN: "Left side: RIGHTMOST Thunderbolt 3 (USB-C) port (closest to trackpad/front).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 2, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),
        specT2(
            ibridge: "iBridge2,14", macID: "MacBookPro16,1", family: "MacBook Pro", name: "MacBook Pro (16-inch, 2019)", board: "J152fAP", bdid: 0x3A,
            portIT: "Lato sinistro: porta Thunderbolt 3 (USB-C) più a DESTRA (più vicina al trackpad/fronte).",
            portEN: "Left side: RIGHTMOST Thunderbolt 3 (USB-C) port (closest to trackpad/front).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 2, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),
        specT2(
            ibridge: "iBridge2,22", macID: "MacBookPro16,4", family: "MacBook Pro", name: "MacBook Pro (16-inch, 2019 - Radeon Pro 5600M)", board: "J215AP", bdid: 0x38,
            portIT: "Lato sinistro: porta Thunderbolt 3 (USB-C) più a DESTRA (più vicina al trackpad/fronte).",
            portEN: "Left side: RIGHTMOST Thunderbolt 3 (USB-C) port (closest to trackpad/front).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 2, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),
        specT2(
            ibridge: "iBridge2,16", macID: "MacBookPro16,2", family: "MacBook Pro", name: "MacBook Pro (13-inch, 2020 Intel, Four TB3 Ports)", board: "J214kAP", bdid: 0x3E,
            portIT: "Lato sinistro: porta Thunderbolt 3 (USB-C) più a DESTRA (più vicina al trackpad/fronte).",
            portEN: "Left side: RIGHTMOST Thunderbolt 3 (USB-C) port (closest to trackpad/front).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 2, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),
        specT2(
            ibridge: "iBridge2,21", macID: "MacBookPro16,3", family: "MacBook Pro", name: "MacBook Pro (13-inch, 2020 Intel, Two TB3 Ports)", board: "J223AP", bdid: 0x3B,
            portIT: "Lato sinistro: porta Thunderbolt 3 (USB-C) più a DESTRA (più vicina al trackpad/fronte).",
            portEN: "Left side: RIGHTMOST Thunderbolt 3 (USB-C) port (closest to trackpad/front).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 2, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),
        specT2(
            ibridge: "iBridge2,8", macID: "MacBookAir8,1", family: "MacBook Air", name: "MacBook Air (Retina, 13-inch, 2018)", board: "J140kAP", bdid: 0x17,
            portIT: "Lato sinistro: porta Thunderbolt 3 (USB-C) più a DESTRA (più vicina al trackpad/fronte).",
            portEN: "Left side: RIGHTMOST Thunderbolt 3 (USB-C) port (closest to trackpad/front).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 2, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),
        specT2(
            ibridge: "iBridge2,12", macID: "MacBookAir8,2", family: "MacBook Air", name: "MacBook Air (Retina, 13-inch, 2019)", board: "J140aAP", bdid: 0x37,
            portIT: "Lato sinistro: porta Thunderbolt 3 (USB-C) più a DESTRA (più vicina al trackpad/fronte).",
            portEN: "Left side: RIGHTMOST Thunderbolt 3 (USB-C) port (closest to trackpad/front).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 2, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),
        specT2(
            ibridge: "iBridge2,15", macID: "MacBookAir9,1", family: "MacBook Air", name: "MacBook Air (Retina, 13-inch, 2020 Intel)", board: "J230kAP", bdid: 0x3F,
            portIT: "Lato sinistro: porta Thunderbolt 3 (USB-C) più a DESTRA (più vicina al trackpad/fronte).",
            portEN: "Left side: RIGHTMOST Thunderbolt 3 (USB-C) port (closest to trackpad/front).",
            visual: .init(face: .leftSide, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 2, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),
        specT2(
            ibridge: "iBridge2,5", macID: "Macmini8,1", family: "Mac mini", name: "Mac mini (2018 Intel)", board: "J174AP", bdid: 0x0E,
            portIT: "Retro (visto da dietro): porta Thunderbolt 3 (USB-C) più a DESTRA (accanto alla porta HDMI).",
            portEN: "Back panel: RIGHTMOST Thunderbolt 3 (USB-C) port (next to the HDMI port).",
            visual: .init(face: .backPanel, totalUSBCPortsOnFace: 4, dfuPortIndexOneBased: 4, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),
        specT2(
            ibridge: "iBridge2,19", macID: "iMac20,1", family: "iMac", name: "iMac (Retina 5K, 27-inch, 2020 Intel)", board: "J185AP", bdid: 0x22,
            portIT: "Retro (visto da dietro): porta Thunderbolt 3 (USB-C) più a DESTRA.",
            portEN: "Back panel: RIGHTMOST Thunderbolt 3 (USB-C) port.",
            visual: .init(face: .backPanel, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 2, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),
        specT2(
            ibridge: "iBridge2,20", macID: "iMac20,2", family: "iMac", name: "iMac (Retina 5K, 27-inch, 2020 Intel - Radeon Pro 5700/XT)", board: "J185fAP", bdid: 0x23,
            portIT: "Retro (visto da dietro): porta Thunderbolt 3 (USB-C) più a DESTRA.",
            portEN: "Back panel: RIGHTMOST Thunderbolt 3 (USB-C) port.",
            visual: .init(face: .backPanel, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 2, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        ),
        specT2(
            ibridge: "iBridge2,6", macID: "MacPro7,1", family: "Mac Pro", name: "Mac Pro (2019 Intel - Tower / Rack)", board: "J160AP", bdid: 0x0F,
            portIT: "Tower: sulla parte superiore, porta USB-C più lontana dal tasto d'accensione. Rack: sul fronte, porta USB-C più vicina al tasto d'accensione.",
            portEN: "Tower: on top, USB-C port farthest from the power button. Rack: on front, USB-C port closest to the power button.",
            visual: .init(face: .topOrFront, totalUSBCPortsOnFace: 2, dfuPortIndexOneBased: 2, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        )
    ]

    // MARK: - 3. Pre-T2 Intel Macs with USB-C / Thunderbolt 3 (2015–2019 — NO DFU, Target Disk Mode Only!)
    static let intelPreT2Specs: [CompatibleMacSpec] = [
        specPreT2(
            id: "MacBook8,1 / 9,1 / 10,1", family: "MacBook", name: "MacBook (Retina, 12-inch, 2015 / 2016 / 2017)",
            chipIT: "Intel Core M / m3 / m5 / m7 / i5 / i7 (Senza chip T2)",
            chipEN: "Intel Core M / m3 / m5 / m7 / i5 / i7 (No T2 Security Chip)"
        ),
        specPreT2(
            id: "MacBookPro13,1 / 14,1", family: "MacBook Pro", name: "MacBook Pro (13-inch, 2016 / 2017, Two TB3 Ports - No Touch Bar)",
            chipIT: "Intel Core i5 / i7 (Senza chip T1 né T2)",
            chipEN: "Intel Core i5 / i7 (No T1 or T2 Chip)"
        ),
        specPreT2(
            id: "MacBookPro13,2 / 13,3 / 14,2 / 14,3", family: "MacBook Pro", name: "MacBook Pro (13-inch & 15-inch, 2016 / 2017, Four TB3 Ports - Touch Bar)",
            chipIT: "Intel Core i5 / i7 + Chip Apple T1 (Il T1 gestisce solo Touch ID/Touch Bar e NON supporta DFU via USB-C!)",
            chipEN: "Intel Core i5 / i7 + Apple T1 Chip (T1 only drives Touch ID/Touch Bar and does NOT support USB-C DFU!)"
        ),
        specPreT2(
            id: "iMac18,1 / 18,2 / 18,3", family: "iMac", name: "iMac (21.5-inch & 27-inch 5K, 2017)",
            chipIT: "Intel Core i5 / i7 (Porte Thunderbolt 3 presenti, ma SENZA chip T2)",
            chipEN: "Intel Core i5 / i7 (Has Thunderbolt 3 ports, but NO T2 Security Chip)"
        ),
        specPreT2(
            id: "iMac19,1 / 19,2", family: "iMac", name: "iMac (21.5-inch 4K & 27-inch 5K, 2019)",
            chipIT: "Intel Core i3 / i5 / i7 / i9 (Porte TB3 presenti, ma SENZA chip T2 — solo il 27\" 2020 ha il T2!)",
            chipEN: "Intel Core i3 / i5 / i7 / i9 (Has TB3 ports, but NO T2 Chip — only the 27\" 2020 iMac has T2!)"
        )
    ]

    // MARK: - Helpers
    private static func specSilicon(
        id: String,
        family: String,
        name: String,
        board: String,
        cpid: UInt16,
        bdid: UInt8,
        chip: String,
        portIT: String,
        portEN: String,
        visual: PortVisualLayout
    ) -> CompatibleMacSpec {
        CompatibleMacSpec(
            id: id,
            category: .appleSilicon,
            family: family,
            marketingName: name,
            modelIdentifier: id,
            dfuTargetIdentifier: id,
            boardConfig: board,
            cpid: cpid,
            bdid: bdid,
            chipNameIT: chip,
            chipNameEN: chip,
            dfuPortLocationIT: portIT,
            dfuPortLocationEN: portEN,
            vdmSupportNoteIT: "Supporto nativo completo VDM Apple Silicon: DFU 1-Click (0x106 / 0x80010000), Reboot (0x105), Serial UART su SBU (/dev/cu.debug-console), Debug USB (KIS).",
            vdmSupportNoteEN: "Full native Apple Silicon VDM support: 1-Click DFU (0x106 / 0x80010000), Reboot (0x105), SBU UART Serial Console (/dev/cu.debug-console), Debug USB (KIS).",
            restoreBehaviorNoteIT: "Revive aggiorna il firmware iBoot/SFR e recoveryOS mantenendo intatti i dati utente. Restore formatta l'SSD e installa macOS completo tramite un file UniversalMac_..._Restore.ipsw.",
            restoreBehaviorNoteEN: "Revive updates iBoot/SFR firmware and recoveryOS while preserving user data. Restore erases internal storage and installs full macOS from a UniversalMac_..._Restore.ipsw file.",
            supportedDiagnosticsIT: [
                "DFU Automatico 1-Click via USB-PD VDM (0x106)",
                "Revive (Rianima) e Restore (Ripristino completo con IPSW UniversalMac)",
                "Lettura Identità BootROM in DFU (CPID, BDID, ECID, versione iBoot SRTG)",
                "Rilevamento a Mac Acceso (USB Gadget 05ac:1902, decodifica BCD modello, Serial Number)",
                "Console Seriale Hardware UART su pin SBU1/SBU2 (/dev/cu.debug-console @ 115200 8N1)",
                "Diagnostica errore cavo / Alt-Mode tramite USB Billboard (05ac:7304) e Port DFU (05ac:f014)",
                "Rete Thunderbolt / USB4 Bridge & Condivisione Disco da macOS Recovery"
            ],
            supportedDiagnosticsEN: [
                "1-Click Automatic DFU via USB-PD VDM (0x106)",
                "Revive (Keep Data) and Restore (Full Wipe with UniversalMac IPSW)",
                "BootROM Identity Inspection in DFU (CPID, BDID, ECID, iBoot SRTG tag)",
                "Live Detection while Booted in macOS (05ac:1902 Gadget, BCD Model Decode, Serial Number)",
                "Hardware UART Serial Console over SBU1/SBU2 pins (/dev/cu.debug-console @ 115200 8N1)",
                "Cable / Alt-Mode Failure Diagnostics via USB Billboard (05ac:7304) & Port DFU (05ac:f014)",
                "Thunderbolt / USB4 Bridge Networking & macOS Recovery Share Disk"
            ],
            portVisual: visual
        )
    }

    private static func specT2(
        ibridge: String,
        macID: String,
        family: String,
        name: String,
        board: String,
        bdid: UInt8,
        portIT: String,
        portEN: String,
        visual: PortVisualLayout
    ) -> CompatibleMacSpec {
        CompatibleMacSpec(
            id: "\(ibridge)-\(macID)",
            category: .intelT2,
            family: family,
            marketingName: name,
            modelIdentifier: macID,
            dfuTargetIdentifier: ibridge,
            boardConfig: board,
            cpid: 0x8012,
            bdid: bdid,
            chipNameIT: "Intel x86_64 + Chip di Sicurezza Apple T2 (CPID 0x8012)",
            chipNameEN: "Intel x86_64 + Apple T2 Security Chip (CPID 0x8012)",
            dfuPortLocationIT: portIT,
            dfuPortLocationEN: portEN,
            vdmSupportNoteIT: "Supporta VDM dall'Host Apple Silicon! I Mac Intel T2 rifiutano (NAK) l'azione 0x106 e richiedono il fallback VDM T2 0x105 con flag 0x80020000 (PMU Reset + DFU Hold), eseguito automaticamente da questa app.",
            vdmSupportNoteEN: "Supports VDM from an Apple Silicon Host! Intel T2 Macs NAK action 0x106 and require the T2 VDM fallback 0x105 with flag 0x80020000 (PMU Reset + DFU Hold), automatically sent by this app.",
            restoreBehaviorNoteIT: "IMPORTANTE: In DFU il dispositivo target è il chip T2 (\(ibridge)), NON la CPU Intel! Revive/Restore aggiorna o formatta bridgeOS (~500 MB scaricati automaticamente da cfgutil senza bisogno di un IPSW UniversalMac). Dopo un Restore, macOS va reinstallato tramite Internet Recovery (Option-Command-R).",
            restoreBehaviorNoteEN: "IMPORTANT: In DFU the target device is the T2 Security Chip (\(ibridge)), NOT the Intel CPU! Revive/Restore updates or erases bridgeOS (~500 MB downloaded automatically by cfgutil without a UniversalMac IPSW). After a Restore, reinstall macOS via Internet Recovery (Option-Command-R).",
            supportedDiagnosticsIT: [
                "DFU Automatico via VDM T2 Fallback (0x105 / 0x80020000) o manuale da tastiera (3 sec)",
                "Revive e Restore di bridgeOS sul chip T2 (\(ibridge)) tramite cfgutil",
                "Lettura Identità T2 BootROM in DFU (CPID 0x8012, BDID, ECID, versione iBoot SRTG)",
                "Target Disk Mode Hardware (tenendo premuto 'T' all'avvio) → Verifica APFS e SMART su Host Silicon",
                "Rete Thunderbolt Bridge (IP over Thunderbolt) per SSH e Screen Sharing"
            ],
            supportedDiagnosticsEN: [
                "Automatic DFU via T2 VDM Fallback (0x105 / 0x80020000) or manual keyboard combo (3 sec)",
                "Revive and Restore of bridgeOS on the T2 chip (\(ibridge)) via cfgutil",
                "T2 BootROM Identity Inspection in DFU (CPID 0x8012, BDID, ECID, iBoot SRTG tag)",
                "Hardware Target Disk Mode (hold 'T' at startup) → APFS & SMART verification on Silicon Host",
                "Thunderbolt Bridge Networking (IP over Thunderbolt) for SSH & Screen Sharing"
            ],
            portVisual: visual
        )
    }

    private static func specPreT2(
        id: String,
        family: String,
        name: String,
        chipIT: String,
        chipEN: String
    ) -> CompatibleMacSpec {
        CompatibleMacSpec(
            id: id,
            category: .intelPreT2,
            family: family,
            marketingName: name,
            modelIdentifier: id,
            dfuTargetIdentifier: "N/A (No T2)",
            boardConfig: "Intel EFI (Pre-T2)",
            cpid: nil,
            bdid: nil,
            chipNameIT: chipIT,
            chipNameEN: chipEN,
            dfuPortLocationIT: "NESSUNA PORTA DFU: Questo Mac non possiede né Apple Silicon né chip T2. Tutte le porte USB-C/TB3 funzionano solo per Target Disk Mode ('T' all'avvio) o Thunderbolt Bridge.",
            dfuPortLocationEN: "NO DFU PORT: This Mac has neither Apple Silicon nor an Apple T2 chip. Its USB-C/TB3 ports only support Target Disk Mode (hold 'T' at boot) or Thunderbolt Bridge.",
            vdmSupportNoteIT: "NON compatibile con VDM DFU, macvdmtool o Apple Configurator DFU.",
            vdmSupportNoteEN: "NOT compatible with VDM DFU, macvdmtool, or Apple Configurator DFU.",
            restoreBehaviorNoteIT: "NON supporta Revive/Restore DFU. Collegalo all'Host Apple Silicon tenendo premuto 'T' all'avvio sul Mac Intel per montare l'SSD in Target Disk Mode ed eseguire diagnostica disco/SMART.",
            restoreBehaviorNoteEN: "Does NOT support DFU Revive/Restore. Connect it to the Apple Silicon Host while holding 'T' at startup on the Intel Mac to mount its SSD in Target Disk Mode for disk/SMART diagnostics.",
            supportedDiagnosticsIT: [
                "Target Disk Mode Hardware (tasto 'T' all'avvio) via cavo USB-C dati (MacBook 12\") o Thunderbolt 3",
                "Diagnostica e Riparazione File System APFS/HFS+ (diskutil verifyDisk / verifyVolume) dall'Host Silicon",
                "Ispezione stato SMART e lettura log di sistema (/var/log) dal volume montato",
                "Rete Thunderbolt Bridge (IP over Thunderbolt) sui modelli dotati di Thunderbolt 3"
            ],
            supportedDiagnosticsEN: [
                "Hardware Target Disk Mode (hold 'T' at startup) over USB-C data cable (12\" MacBook) or Thunderbolt 3",
                "APFS/HFS+ File System Verification & Repair (diskutil verifyDisk / verifyVolume) from Silicon Host",
                "SMART Health Inspection & system log (/var/log) extraction from mounted target volume",
                "Thunderbolt Bridge Networking (IP over Thunderbolt) on Thunderbolt 3 models"
            ],
            portVisual: .init(face: .none, totalUSBCPortsOnFace: 0, dfuPortIndexOneBased: nil, hasMagSafeOnLeft: false, isExceptionHT120694: false)
        )
    }

    // MARK: - Lookup Functions
    static func lookup(cpid: UInt16, bdid: UInt8) -> CompatibleMacSpec? {
        allSpecs.first { $0.cpid == cpid && $0.bdid == bdid }
    }

    static func lookupByIdentifier(_ identifier: String) -> CompatibleMacSpec? {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        return allSpecs.first {
            $0.modelIdentifier.caseInsensitiveCompare(trimmed) == .orderedSame ||
            $0.dfuTargetIdentifier.caseInsensitiveCompare(trimmed) == .orderedSame
        }
    }

    static func lookupByBoardConfig(_ boardConfig: String) -> CompatibleMacSpec? {
        let trimmed = boardConfig.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return allSpecs.first {
            $0.boardConfig.caseInsensitiveCompare(trimmed) == .orderedSame
        }
    }

    static func lookupByBootedBCDDevice(_ bcd: UInt16) -> CompatibleMacSpec? {
        let majorByte = (bcd >> 8) & 0xFF
        let minorByte = bcd & 0xFF
        let major = ((majorByte >> 4) * 10) + (majorByte & 0x0F)
        let minor = ((minorByte >> 4) * 10) + (minorByte & 0x0F)
        let numericSuffix = "\(major),\(minor)"

        return appleSiliconSpecs.first { spec in
            guard let lastAlphaIndex = spec.modelIdentifier.lastIndex(where: { $0.isLetter }) else { return false }
            let suffix = String(spec.modelIdentifier[spec.modelIdentifier.index(after: lastAlphaIndex)...])
            return suffix == numericSuffix
        }
    }
}
