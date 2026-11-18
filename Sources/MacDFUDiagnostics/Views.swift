import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum NavigationSection: String, CaseIterable, Identifiable, Equatable {
    case dfuDashboard
    case diagnostics
    case compatibility
    case portGuide

    var id: String { rawValue }

    func title(in lang: AppLanguage) -> String {
        switch self {
        case .dfuDashboard:
            lang.text("Dashboard DFU 1-Click", "1-Click DFU Dashboard")
        case .diagnostics:
            lang.text("Diagnostica & Target Disk", "Diagnostics & Target Disk")
        case .compatibility:
            lang.text("Mac Compatibili (M1–M6 & Intel)", "Compatible Macs (M1–M6 & Intel)")
        case .portGuide:
            lang.text("Guida Porte DFU & Cavi", "DFU Port & Cable Guide")
        }
    }

    func subtitle(in lang: AppLanguage) -> String {
        switch self {
        case .dfuDashboard:
            lang.text("DFU automatico, Reboot, Revive e Restore", "Auto DFU, Reboot, Revive & Restore")
        case .diagnostics:
            lang.text("BootROM USB, SMART, Target Disk e Seriale", "USB BootROM, SMART, Target Disk & Serial")
        case .compatibility:
            lang.text("Apple Silicon, Intel T2 e Pre-T2 con mappa porte", "Apple Silicon, Intel T2 & Pre-T2 port map")
        case .portGuide:
            lang.text("Regole ufficiali Apple HT120694", "Official Apple HT120694 rules")
        }
    }

    var icon: String {
        switch self {
        case .dfuDashboard: "bolt.horizontal.circle.fill"
        case .diagnostics: "stethoscope"
        case .compatibility: "laptopcomputer.and.ipad"
        case .portGuide: "cable.connector.horizontal"
        }
    }
}

struct MainRootView: View {
    @Bindable var engine: DiagnosticsEngine
    @Bindable var prefs: AppPreferences
    @State private var selectedSection: NavigationSection = .dfuDashboard

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                SidebarBrandHeaderView(prefs: prefs)
                Divider()
                List(NavigationSection.allCases, selection: $selectedSection) { section in
                    SidebarRowView(section: section, lang: prefs.language)
                        .tag(section)
                }
                .listStyle(.sidebar)
                HostStatusFooterView(engine: engine, lang: prefs.language)
            }
            .navigationSplitViewColumnWidth(min: 245, ideal: 265)
        } detail: {
            Group {
                switch selectedSection {
                case .dfuDashboard:
                    DFUDashboardView(
                        engine: engine,
                        prefs: prefs,
                        onOpenPortGuide: { selectedSection = .portGuide },
                        onOpenCompatibility: { selectedSection = .compatibility }
                    )
                case .diagnostics:
                    HardwareDiagnosticsView(engine: engine, prefs: prefs)
                case .compatibility:
                    CompatibilityExplorerView(prefs: prefs)
                case .portGuide:
                    PortAndCableGuideView(prefs: prefs)
                }
            }
        }
        .preferredColorScheme(prefs.theme.colorScheme)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if engine.isBusy {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text(engine.currentOperationTitle(in: prefs.language) ?? prefs.tr("Operazione in corso...", "Working..."))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                }

                // Language Switcher (IT / EN)
                Picker(prefs.tr("Lingua", "Language"), selection: $prefs.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 185)
                .help(prefs.tr("Cambia lingua (Italiano / Inglese)", "Switch language (Italian / English)"))

                // Theme Switcher (System / Light / Dark)
                Picker(prefs.tr("Tema", "Theme"), selection: $prefs.theme) {
                    ForEach(AppThemeMode.allCases) { mode in
                        Label(mode.label(in: prefs.language), systemImage: mode.iconName)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
                .help(prefs.tr("Tema Chiaro / Scuro / Sistema", "Light / Dark / System Theme"))

                Button {
                    engine.refreshAllHardware()
                } label: {
                    Label(prefs.tr("Aggiorna", "Refresh"), systemImage: "arrow.clockwise")
                }
                .help(prefs.tr("Aggiorna scansione USB, porte AppleHPM e dischi Target Disk Mode", "Refresh USB, AppleHPM ports, and Target Disk Mode scan"))
            }
        }
    }
}

private struct SidebarBrandHeaderView: View {
    let prefs: AppPreferences

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.08, green: 0.14, blue: 0.30), Color(red: 0.04, green: 0.25, blue: 0.26)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 38, height: 38)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.cyan.opacity(0.6), lineWidth: 1)
                    )
                Text("DFU")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.cyan)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Mac DFU Studio")
                    .font(.headline)
                Text(prefs.tr("Silicon M1–M6 & Intel T2", "Silicon M1–M6 & Intel T2"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct SidebarRowView: View {
    let section: NavigationSection
    let lang: AppLanguage

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: section.icon)
                .font(.title3)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(section.title(in: lang))
                    .font(.subheadline.weight(.medium))
                Text(section.subtitle(in: lang))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct HostStatusFooterView: View {
    let engine: DiagnosticsEngine
    let lang: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            HStack(spacing: 6) {
                Circle()
                    .fill(engine.isAppleSiliconHost ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(engine.isAppleSiliconHost
                     ? lang.text("Host Silicon (\(engine.hostPlatformName))", "Silicon Host (\(engine.hostPlatformName))")
                     : lang.text("Host Non-Silicon", "Non-Silicon Host"))
                    .font(.caption.bold())
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: engine.hostFreeSpaceBytes, countStyle: .file))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                Image(systemName: engine.cfgutilPath != nil ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(engine.cfgutilPath != nil ? .green : .orange)
                    .font(.caption2)
                Text(engine.cfgutilPath != nil
                     ? lang.text("cfgutil pronto", "cfgutil ready")
                     : lang.text("cfgutil assente", "cfgutil missing"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(lang.text("\(engine.detectedUSBDevices.count) target USB", "\(engine.detectedUSBDevices.count) USB target(s)"))
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(engine.detectedUSBDevices.isEmpty ? Color.secondary.opacity(0.15) : Color.green.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
    }
}

// MARK: - 1. Streamlined 1-Click DFU Dashboard View
struct DFUDashboardView: View {
    @Bindable var engine: DiagnosticsEngine
    let prefs: AppPreferences
    let onOpenPortGuide: () -> Void
    let onOpenCompatibility: () -> Void

    @State private var showIPSWPicker = false
    @State private var confirmRestoreDevice: DetectedAppleUSBDevice?
    @State private var showAdvancedVDM = false

    private var lang: AppLanguage { prefs.language }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // 1. Visual Hero Connection Banner & 1-Click Primary Actions
                ConnectionHeroBannerView(
                    engine: engine,
                    lang: lang,
                    onOpenPortGuide: onOpenPortGuide,
                    onOpenCompatibility: onOpenCompatibility
                )

                // 2. Active Target Device Card (or Step-by-Step Quick Guide when no device is in DFU)
                DetectedTargetsActionCard(
                    engine: engine,
                    lang: lang,
                    showIPSWPicker: $showIPSWPicker,
                    confirmRestoreDevice: $confirmRestoreDevice
                )

                // 3. Expandable Advanced VDM & Port Topology Drawer (keeps UI clean and easy!)
                AdvancedVDMControlsCard(
                    engine: engine,
                    lang: lang,
                    isExpanded: $showAdvancedVDM
                )

                // 4. Activity Log Console
                LiveConsoleCard(engine: engine, lang: lang)
            }
            .padding(22)
        }
        .navigationTitle(prefs.tr("Dashboard DFU 1-Click & Ripristino", "1-Click DFU & Restore Dashboard"))
        .fileImporter(
            isPresented: $showIPSWPicker,
            allowedContentTypes: [UTType(filenameExtension: "ipsw") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                _ = url.startAccessingSecurityScopedResource()
                engine.selectedIPSWURL = url
                engine.appendLog(
                    .info,
                    it: "File IPSW selezionato: \(url.lastPathComponent)",
                    en: "Selected IPSW file: \(url.lastPathComponent)"
                )
            }
        }
        .confirmationDialog(
            prefs.tr("Confermi il Restore (Formattazione Completa)?", "Confirm Full Erase & Restore?"),
            isPresented: Binding(
                get: { confirmRestoreDevice != nil },
                set: { if !$0 { confirmRestoreDevice = nil } }
            ),
            presenting: confirmRestoreDevice
        ) { device in
            Button(prefs.tr("Cancella Tutto ed Esegui Restore", "Erase Everything and Restore"), role: .destructive) {
                confirmRestoreDevice = nil
                Task {
                    await engine.executeCfgutilAction(mode: "restore", device: device)
                }
            }
            Button(prefs.tr("Annulla", "Cancel"), role: .cancel) {
                confirmRestoreDevice = nil
            }
        } message: { device in
            if device.isIntelT2 {
                Text(prefs.tr(
                    "Il chip Apple T2 (\(device.resolvedSpec?.dfuTargetIdentifier ?? "iBridge2,x")) su \(device.displayTitle(in: lang)) verrà inizializzato e tutte le chiavi crittografiche dell'SSD interno saranno distrutte. Dopo il ripristino di bridgeOS dovrai installare macOS da Internet Recovery (Option-Command-R).",
                    "The Apple T2 chip (\(device.resolvedSpec?.dfuTargetIdentifier ?? "iBridge2,x")) on \(device.displayTitle(in: lang)) will be erased and all internal SSD encryption keys will be destroyed. After bridgeOS restores, install macOS via Internet Recovery (Option-Command-R)."
                ))
            } else {
                Text(prefs.tr(
                    "Tutti i dati presenti su \(device.displayTitle(in: lang)) (ECID: \(device.ecidHex ?? "N/A")) verranno eliminati in modo permanente.",
                    "All data on \(device.displayTitle(in: lang)) (ECID: \(device.ecidHex ?? "N/A")) will be permanently deleted."
                ))
            }
        }
    }
}

private struct ConnectionHeroBannerView: View {
    @Environment(\.colorScheme) private var colorScheme
    let engine: DiagnosticsEngine
    let lang: AppLanguage
    let onOpenPortGuide: () -> Void
    let onOpenCompatibility: () -> Void

    private var primaryTarget: DetectedAppleUSBDevice? {
        engine.detectedUSBDevices.first { $0.state.isRestorableDFU } ?? engine.detectedUSBDevices.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Top Visual Topology Diagram: Host <-> USB-C Cable <-> Target
            HStack(spacing: 14) {
                // Host Badge
                HStack(spacing: 10) {
                    Image(systemName: "desktopcomputer")
                        .font(.title2)
                        .foregroundStyle(.cyan)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lang.text("HOST APPLE SILICON", "APPLE SILICON HOST"))
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(.secondary)
                        Text(engine.hostPlatformName)
                            .font(.subheadline.bold())
                        Text("Porta RID \(engine.selectedHostRID)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(AppPalette.elevatedBackground(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                // Cable Link Indicator
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(primaryTarget != nil ? Color.green : Color.orange)
                            .frame(width: 7, height: 7)
                        Text(primaryTarget != nil
                             ? lang.text("Cavo USB-C Attivo", "USB-C Link Active")
                             : lang.text("In attesa su Porta DFU", "Waiting on DFU Port"))
                            .font(.caption2.bold())
                    }
                    Image(systemName: "arrow.left.and.right.circle.fill")
                        .font(.title3)
                        .foregroundStyle(primaryTarget != nil ? Color.green : Color.secondary)
                    Text("USB-PD VDM (0x05AC)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                // Target Badge
                HStack(spacing: 10) {
                    Image(systemName: primaryTarget?.isIntelT2 == true ? "cpu.fill" : "laptopcomputer")
                        .font(.title2)
                        .foregroundStyle(primaryTarget?.state.isRestorableDFU == true ? Color.green : Color.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lang.text("DISPOSITIVO TARGET", "TARGET DEVICE"))
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(.secondary)
                        Text(primaryTarget?.displayTitle(in: lang) ?? lang.text("Nessun Mac in DFU", "No Mac in DFU"))
                            .font(.subheadline.bold())
                            .lineLimit(1)
                        Text(primaryTarget?.state.label(in: lang) ?? lang.text("Premi 1-Click DFU sotto", "Click 1-Click DFU below"))
                            .font(.caption2)
                            .foregroundStyle(primaryTarget?.state.isRestorableDFU == true ? Color.green : Color.secondary)
                    }
                }
                .padding(10)
                .background(AppPalette.elevatedBackground(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Divider()

            // Primary 1-Click Action Bar
            HStack(spacing: 12) {
                Button {
                    Task {
                        await engine.executeVDMCommand(
                            "dfu",
                            titleIT: "Ingresso DFU Automatico (Apple Silicon + Intel T2)",
                            titleEN: "Automatic DFU Entry (Apple Silicon + Intel T2)"
                        )
                    }
                } label: {
                    Label(
                        lang.text("1-Click Entra in DFU (Silicon + Intel T2)", "1-Click Enter DFU (Silicon + Intel T2)"),
                        systemImage: "bolt.circle.fill"
                    )
                    .font(.headline)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(engine.isBusy)

                Button {
                    Task {
                        await engine.executeVDMCommand(
                            "reboot",
                            titleIT: "Riavvio Remoto Target (Uscita DFU)",
                            titleEN: "Remote Target Reboot (Exit DFU)"
                        )
                    }
                } label: {
                    Label(
                        lang.text("Riavvia Target (Esci da DFU)", "Reboot Target (Exit DFU)"),
                        systemImage: "restart.circle.fill"
                    )
                    .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(engine.isBusy)

                Spacer()

                Button(action: onOpenCompatibility) {
                    Label(lang.text("Verifica Modello", "Check Model"), systemImage: "magnifyingglass")
                }
                .controlSize(.regular)

                Button(action: onOpenPortGuide) {
                    Label(lang.text("Quale Porta DFU?", "Which DFU Port?"), systemImage: "cable.connector.horizontal")
                }
                .controlSize(.regular)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppPalette.heroGradient(for: colorScheme, hasTarget: primaryTarget?.state.isRestorableDFU == true))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    primaryTarget?.state.isRestorableDFU == true ? Color.green.opacity(0.45) : AppPalette.cardBorder(for: colorScheme),
                    lineWidth: 1.2
                )
        )
    }
}

private struct DetectedTargetsActionCard: View {
    let engine: DiagnosticsEngine
    let lang: AppLanguage
    @Binding var showIPSWPicker: Bool
    @Binding var confirmRestoreDevice: DetectedAppleUSBDevice?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(
                    lang.text("2. Riparazione Firmware & Sistema (Revive / Restore)", "2. Firmware & OS Repair (Revive / Restore)"),
                    systemImage: "wrench.and.screwdriver.fill"
                )
                .font(.headline)

                Spacer()

                if let ipsw = engine.selectedIPSWURL {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.zipper")
                            .foregroundStyle(.cyan)
                        Text(ipsw.lastPathComponent)
                            .font(.caption.monospaced())
                            .lineLimit(1)
                        Button(lang.text("Rimuovi", "Clear")) {
                            engine.selectedIPSWURL = nil
                        }
                        .controlSize(.small)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.cyan.opacity(0.12))
                    .clipShape(Capsule())
                }

                Button {
                    showIPSWPicker = true
                } label: {
                    Label(
                        lang.text("Scegli File IPSW...", "Select IPSW File..."),
                        systemImage: "folder.badge.plus"
                    )
                }
                .controlSize(.small)
            }

            if let progress = engine.operationProgress {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: progress) {
                        Text(engine.currentOperationTitle(in: lang) ?? lang.text("Operazione in corso...", "Operation in progress..."))
                            .font(.subheadline.bold())
                    } currentValueLabel: {
                        Text(String(format: "%.1f%%", progress * 100))
                            .font(.caption.monospaced())
                    }
                }
                .padding(10)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if engine.detectedUSBDevices.isEmpty {
                HStack(spacing: 16) {
                    StepPillView(
                        number: "1",
                        title: lang.text("Collega il Cavo USB-C", "Connect USB-C Cable"),
                        detail: lang.text("Porta DFU Host ↔ Porta DFU Target (usa un cavo USB-C dati, NON Thunderbolt 3).", "Host DFU Port ↔ Target DFU Port (use a USB-C data cable, NOT Thunderbolt 3).")
                    )
                    StepPillView(
                        number: "2",
                        title: lang.text("Premi '1-Click Entra in DFU'", "Click '1-Click Enter DFU'"),
                        detail: lang.text("Invia automaticamente il segnale VDM sia per Apple Silicon (0x106) sia per Intel T2 (0x105).", "Automatically sends VDM trigger for both Apple Silicon (0x106) and Intel T2 (0x105).")
                    )
                    StepPillView(
                        number: "3",
                        title: lang.text("Esegui Revive o Restore", "Run Revive or Restore"),
                        detail: lang.text("Appena il Mac target appare qui sotto, scegli Revive (salva i dati) o Restore (formatta).", "Once the target Mac appears below, choose Revive (keeps data) or Restore (wipes).")
                    )
                }
            } else {
                ForEach(engine.detectedUSBDevices) { dev in
                    TargetDeviceRowCard(
                        device: dev,
                        engine: engine,
                        lang: lang,
                        onConfirmRestore: { confirmRestoreDevice = dev }
                    )
                }
            }
        }
        .styledCard()
    }
}

private struct StepPillView: View {
    @Environment(\.colorScheme) private var colorScheme
    let number: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(number)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.accentColor))
                Text(title)
                    .font(.subheadline.bold())
            }
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(AppPalette.elevatedBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct TargetDeviceRowCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let device: DetectedAppleUSBDevice
    let engine: DiagnosticsEngine
    let lang: AppLanguage
    let onConfirmRestore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(device.state.isRestorableDFU ? Color.green.opacity(0.18) : Color.orange.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: device.isIntelT2 ? "cpu.fill" : "laptopcomputer")
                        .font(.title2)
                        .foregroundStyle(device.state.isRestorableDFU ? Color.green : Color.orange)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(device.displayTitle(in: lang))
                            .font(.headline)
                        Text(device.state.label(in: lang))
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(device.state.isRestorableDFU ? Color.green.opacity(0.22) : Color.orange.opacity(0.22))
                            .foregroundStyle(device.state.isRestorableDFU ? Color.green : Color.orange)
                            .clipShape(Capsule())
                    }
                    Text("USB \(device.vidPidHex) (rev \(device.bcdVersionString)) · Loc \(device.locationHex)" +
                         (device.hostPortRID != nil ? " · Host RID \(device.hostPortRID!) (\(device.hostPortLocation ?? ""))" : ""))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if device.state.isRestorableDFU {
                    Button {
                        Task {
                            await engine.executeCfgutilAction(mode: "revive", device: device)
                        }
                    } label: {
                        Label(lang.text("Revive (Salva Dati)", "Revive (Keep Data)"), systemImage: "heart.text.square.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(engine.isBusy || engine.cfgutilPath == nil)

                    Button(role: .destructive) {
                        onConfirmRestore()
                    } label: {
                        Label(lang.text("Restore (Formatta)", "Restore (Erase)"), systemImage: "trash.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(engine.isBusy || engine.cfgutilPath == nil)
                }
            }

            // Identity chips
            HStack(spacing: 10) {
                if let spec = device.resolvedSpec {
                    InfoBadgePill(text: "\(spec.modelIdentifier) → DFU: \(spec.dfuTargetIdentifier) (\(spec.boardConfig))", icon: "tag.fill")
                }
                if let cpid = device.cpid, let bdid = device.bdid {
                    InfoBadgePill(text: String(format: "CPID 0x%04X · BDID 0x%02X", cpid, bdid), icon: "memorychip")
                }
                if let ecid = device.ecidHex {
                    InfoBadgePill(text: "ECID \(ecid)", icon: "number")
                }
                if let srtg = device.srtg {
                    InfoBadgePill(text: srtg, icon: "lock.shield")
                }
            }

            // Contextual guidance
            if device.state == .billboard {
                Label(
                    lang.text(
                        "ERRORE CAVO / ALT-MODE (Billboard 05ac:7304): Il controller USB-C del target ha fallito la modalità alternativa Thunderbolt. Usa un cavo USB-C dati standard sulla porta DFU corretta.",
                        "CABLE / ALT-MODE ERROR (Billboard 05ac:7304): The target's USB-C port controller failed Thunderbolt Alt-Mode entry. Use a standard USB-C data cable on the correct DFU port."
                    ),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            } else if device.state == .portDfu {
                Label(
                    lang.text(
                        "PORT DFU (05ac:f014): Il controller USB-C (Ace/CD3217) del target è in modalità emergenza. Premi Revive per aggiornare il firmware del controller della porta.",
                        "PORT DFU (05ac:f014): The target's USB-C controller (Ace/CD3217) is in recovery. Click Revive to reprogram the port controller firmware first."
                    ),
                    systemImage: "wrench.and.screwdriver.fill"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            } else if device.state == .booted {
                Label(
                    lang.text(
                        "MAC ACCESO (05ac:1902 RemoteXPC): Il Mac target è avviato normalmente in macOS (modello identificato da bcdDevice \(device.bcdVersionString)). Premi '1-Click Entra in DFU' per riavviarlo direttamente in DFU.",
                        "BOOTED MAC (05ac:1902 RemoteXPC): The target Mac is currently booted in macOS (model resolved via bcdDevice \(device.bcdVersionString)). Click '1-Click Enter DFU' to reboot it straight into DFU."
                    ),
                    systemImage: "info.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(.cyan)
            } else if device.isIntelT2 && device.state.isRestorableDFU {
                Label(
                    lang.text(
                        "MAC INTEL T2 (CPID 0x8012): Revive ripara bridgeOS sul chip T2 senza perdere dati. Restore inizializza il T2 e l'SSD (non serve un IPSW UniversalMac; poi installa macOS con Option-Command-R).",
                        "INTEL T2 MAC (CPID 0x8012): Revive repairs bridgeOS on the T2 chip without data loss. Restore wipes T2 and the SSD (no UniversalMac IPSW needed; reinstall macOS via Option-Command-R afterward)."
                    ),
                    systemImage: "info.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(.cyan)
            }
        }
        .padding(14)
        .background(AppPalette.elevatedBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct InfoBadgePill: View {
    let text: String
    let icon: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(0.14))
        .clipShape(Capsule())
    }
}

private struct AdvancedVDMControlsCard: View {
    @Bindable var engine: DiagnosticsEngine
    let lang: AppLanguage
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                Divider()
                HStack(spacing: 12) {
                    Picker(lang.text("Porta Host AppleHPM (RID):", "Host AppleHPM Port (RID):"), selection: $engine.selectedHostRID) {
                        ForEach(engine.hostPorts) { port in
                            Text("RID \(port.rid) — \(port.locationName) [USB \(port.locationBaseHex)] \(port.isDFUCapable ? "★ DFU/VDM" : "")")
                                .tag(port.rid)
                        }
                    }
                    .frame(maxWidth: 440)

                    Button {
                        Task {
                            await engine.executeVDMCommand(
                                "probe",
                                titleIT: "Probe AppleHPM RID \(engine.selectedHostRID)",
                                titleEN: "Probing AppleHPM RID \(engine.selectedHostRID)"
                            )
                        }
                    } label: {
                        Label(lang.text("Test Porta (Probe DBMa)", "Test Port (Probe DBMa)"), systemImage: "waveform.badge.magnifyingglass")
                    }
                    .disabled(engine.isBusy)
                }

                HStack(spacing: 10) {
                    Button {
                        Task {
                            await engine.executeVDMCommand(
                                "dfu-silicon",
                                titleIT: "Forza DFU Apple Silicon (0x106)",
                                titleEN: "Force Apple Silicon DFU (0x106)"
                            )
                        }
                    } label: {
                        Label(lang.text("Forza VDM Silicon (0x106)", "Force Silicon VDM (0x106)"), systemImage: "m.square.fill")
                    }
                    .disabled(engine.isBusy)

                    Button {
                        Task {
                            await engine.executeVDMCommand(
                                "dfu-t2",
                                titleIT: "Forza DFU Intel T2 (0x105 / 0x80020000)",
                                titleEN: "Force Intel T2 DFU (0x105 / 0x80020000)"
                            )
                        }
                    } label: {
                        Label(lang.text("Forza VDM Intel T2 (0x105)", "Force Intel T2 VDM (0x105)"), systemImage: "shield.lefthalf.filled")
                    }
                    .disabled(engine.isBusy)

                    Button {
                        Task {
                            await engine.executeVDMCommand(
                                "serial",
                                titleIT: "Attiva Console Seriale UART su SBU",
                                titleEN: "Enable SBU UART Serial Console"
                            )
                        }
                    } label: {
                        Label(lang.text("Console Seriale SBU (/dev/cu.debug-console)", "SBU Serial Console (/dev/cu.debug-console)"), systemImage: "terminal.fill")
                    }
                    .disabled(engine.isBusy)

                    Button {
                        Task {
                            await engine.executeVDMCommand(
                                "debugusb",
                                titleIT: "Attiva Debug USB (KIS 05ac:1881)",
                                titleEN: "Enable Debug USB (KIS 05ac:1881)"
                            )
                        }
                    } label: {
                        Label("Debug USB (KIS)", systemImage: "ant.circle.fill")
                    }
                    .disabled(engine.isBusy)
                }
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Label(
                    lang.text("3. Opzioni Avanzate VDM, Seriale UART & Selezione Porta Host (Pro)", "3. Advanced VDM, UART Serial & Host Port Selection (Pro)"),
                    systemImage: "slider.horizontal.3"
                )
                .font(.headline)
                Spacer()
                Text(lang.text("RID attivo: \(engine.selectedHostRID)", "Active RID: \(engine.selectedHostRID)"))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .styledCard()
    }
}

private struct LiveConsoleCard: View {
    let engine: DiagnosticsEngine
    let lang: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(
                    lang.text("Registro Attività & Output VDM / cfgutil", "Activity Log & VDM / cfgutil Output"),
                    systemImage: "terminal"
                )
                .font(.headline)
                Spacer()
                Button(lang.text("Pulisci", "Clear")) {
                    engine.clearLogs()
                }
                .controlSize(.small)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 5) {
                    if engine.logs.isEmpty {
                        Text(lang.text(
                            "Pronto. Collega un Mac compatibile alla porta DFU e premi '1-Click Entra in DFU'.",
                            "Ready. Connect a compatible Mac to the DFU port and click '1-Click Enter DFU'."
                        ))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    } else {
                        ForEach(engine.logs) { entry in
                            HStack(alignment: .top, spacing: 8) {
                                Text(entry.timestamp, style: .time)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                                Text("[\(entry.level.rawValue)]")
                                    .font(.caption.monospaced().bold())
                                    .foregroundStyle(color(for: entry.level))
                                Text(entry.message(in: lang))
                                    .font(.caption.monospaced())
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 145)
            .padding(10)
            .background(Color.black.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .styledCard()
    }

    private func color(for level: DiagnosticLogEntry.Level) -> Color {
        switch level {
        case .info: .secondary
        case .success: .green
        case .warning: .orange
        case .error: .red
        }
    }
}

// MARK: - 2. Hardware Diagnostics & Target Disk Mode View
struct HardwareDiagnosticsView: View {
    @Bindable var engine: DiagnosticsEngine
    let prefs: AppPreferences
    private var lang: AppLanguage { prefs.language }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Card 1: USB & BootROM Inspector
                VStack(alignment: .leading, spacing: 10) {
                    Label(
                        lang.text("Ispezione Basso Livello Bus USB & BootROM (`IOUSBHostDevice`)", "Low-Level USB Bus & BootROM Inspector (`IOUSBHostDevice`)"),
                        systemImage: "cable.connector"
                    )
                    .font(.headline)

                    if engine.detectedUSBDevices.isEmpty {
                        Text(lang.text(
                            "Nessun Mac target rilevato sul bus USB (idVendor 0x05AC).",
                            "No target Mac currently detected on the USB bus (idVendor 0x05AC)."
                        ))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    } else {
                        ForEach(engine.detectedUSBDevices) { dev in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(dev.displayTitle(in: lang)) — \(dev.state.label(in: lang))")
                                    .font(.subheadline.bold())
                                Text("VID:PID = \(dev.vidPidHex) · bcdDevice = \(dev.bcdVersionString) · Class = 0x\(String(format: "%02X", dev.deviceClass)) · LocationID = \(dev.locationHex)")
                                    .font(.caption.monospaced())
                                Text("Raw USB Serial Descriptor: \(dev.rawSerial.isEmpty ? "(empty)" : dev.rawSerial)")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .styledCard()

                // Card 2: Target Disk Mode ('T' at boot) & SMART Verification
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label(
                            lang.text("Diagnostica Target Disk Mode (`T` all'avvio) & Dischi Esterni USB/TB", "Target Disk Mode (`T` at boot) & External USB/TB Disk Diagnostics"),
                            systemImage: "externaldrive.fill.badge.checkmark"
                        )
                        .font(.headline)
                        Spacer()
                        Button {
                            Task { await engine.refreshExternalTargetDisks() }
                        } label: {
                            Label(lang.text("Scansiona Dischi", "Scan Disks"), systemImage: "arrow.clockwise")
                        }
                        .controlSize(.small)
                    }

                    Text(lang.text(
                        "Compatibile con TUTTI i Mac Intel (sia con chip T2 2017–2020 sia Pre-T2 2015–2019 come MacBook 12\", MacBook Pro 2016–2017 e iMac 2017–2019): accendi il Mac Intel tenendo premuto 'T' mentre è collegato via cavo USB-C dati o Thunderbolt 3 a questo Mac Apple Silicon. Il suo SSD apparirà qui per verifica APFS e stato SMART.",
                        "Compatible with ALL Intel Macs (both T2 2017–2020 and Pre-T2 2015–2019 such as 12\" MacBook, 2016–2017 MacBook Pro, and 2017–2019 iMac): power on the Intel Mac while holding 'T' connected via a USB-C data or Thunderbolt 3 cable to this Apple Silicon Host. Its internal SSD will appear below for APFS & SMART diagnostics."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if engine.externalTargetDisks.isEmpty {
                        Text(lang.text(
                            "Nessun disco esterno o Mac in Target Disk Mode rilevato al momento.",
                            "No external disk or Mac in Target Disk Mode currently detected."
                        ))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                    } else {
                        ForEach(engine.externalTargetDisks) { disk in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("/dev/\(disk.deviceIdentifier) — \(disk.mediaName) (\(disk.formattedSize))")
                                        .font(.subheadline.bold())
                                    Text(lang.text(
                                        "Protocollo Bus: \(disk.busProtocol) · Stato SMART: \(disk.smartStatus)",
                                        "Bus Protocol: \(disk.busProtocol) · SMART Status: \(disk.smartStatus)"
                                    ))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    if !disk.partitions.isEmpty {
                                        Text(lang.text("Volumi: ", "Volumes: ") + disk.partitions.joined(separator: ", "))
                                            .font(.caption.monospaced())
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Button {
                                    Task {
                                        await engine.runTargetDiskVerification(diskIdentifier: disk.deviceIdentifier)
                                    }
                                } label: {
                                    Label(
                                        lang.text("Verifica File System & SMART", "Verify File System & SMART"),
                                        systemImage: "checkmark.shield.fill"
                                    )
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(engine.isBusy)
                            }
                            .padding(10)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    if !engine.diskDiagnosticOutput.isEmpty {
                        Divider()
                        Text(lang.text("Report `diskutil` Target Disk:", "Target Disk `diskutil` Report:"))
                            .font(.caption.bold())
                        ScrollView {
                            Text(engine.diskDiagnosticOutput)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 170)
                        .padding(8)
                        .background(Color.black.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .styledCard()

                // Card 3: Serial UART & Thunderbolt Bridge
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        lang.text("Console Seriale Hardware UART (SBU) & Rete Thunderbolt Bridge", "Hardware UART Serial Console (SBU) & Thunderbolt Bridge"),
                        systemImage: "network"
                    )
                    .font(.headline)

                    HStack {
                        Text(lang.text("Rete Thunderbolt Bridge (`bridge0`):", "Thunderbolt Bridge Network (`bridge0`):"))
                            .font(.callout.bold())
                        Text(engine.thunderboltBridgeState.label(in: lang))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text(lang.text("Console Seriale SBU / KIS (`/dev/cu.*`):", "SBU / KIS Serial Devices (`/dev/cu.*`):"))
                            .font(.callout.bold())
                        if engine.serialConsoleDevices.isEmpty {
                            Text(lang.text(
                                "Nessuna attiva (attivabile dalle Opzioni VDM Avanzate con cavo USB 3.x/TB)",
                                "None active (enable from Advanced VDM Options with a USB 3.x/TB cable)"
                            ))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        } else {
                            Text(engine.serialConsoleDevices.joined(separator: ", "))
                                .font(.caption.monospaced())
                                .foregroundStyle(.green)
                                .textSelection(.enabled)
                        }
                    }
                }
                .styledCard()
            }
            .padding(22)
        }
        .navigationTitle(prefs.tr("Diagnostica USB, Cavo & Target Disk Mode", "USB, Cable & Target Disk Mode Diagnostics"))
    }
}

// MARK: - 3. Compatible Macs Explorer with Interactive Visual Port Diagram
struct CompatibilityExplorerView: View {
    let prefs: AppPreferences
    @State private var searchText: String = ""
    @State private var selectedCategory: MacArchitectureCategory?
    @State private var selectedFamily: String = "All"
    @State private var selectedSpec: CompatibleMacSpec? = CompatibilityCatalog.allSpecs.first

    private var lang: AppLanguage { prefs.language }
    private let families = ["All", "MacBook Air", "MacBook Pro", "MacBook", "MacBook Neo", "iMac", "iMac Pro", "Mac mini", "Mac Studio", "Mac Pro"]

    private var filteredSpecs: [CompatibleMacSpec] {
        CompatibilityCatalog.allSpecs.filter { spec in
            if let cat = selectedCategory, spec.category != cat { return false }
            if selectedFamily != "All" && spec.family != selectedFamily { return false }
            if !searchText.isEmpty {
                let q = searchText.lowercased()
                return spec.marketingName.lowercased().contains(q) ||
                       spec.modelIdentifier.lowercased().contains(q) ||
                       spec.dfuTargetIdentifier.lowercased().contains(q) ||
                       spec.boardConfig.lowercased().contains(q) ||
                       spec.chipName(in: lang).lowercased().contains(q) ||
                       spec.cpidHex.lowercased().contains(q)
            }
            return true
        }
    }

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker(lang.text("Architettura:", "Architecture:"), selection: $selectedCategory) {
                        Text(lang.text("Tutte (\(CompatibilityCatalog.allSpecs.count))", "All (\(CompatibilityCatalog.allSpecs.count))"))
                            .tag(Optional<MacArchitectureCategory>.none)
                        ForEach(MacArchitectureCategory.allCases) { cat in
                            Text(cat.title(in: lang)).tag(Optional(cat))
                        }
                    }
                    Picker(lang.text("Famiglia Mac:", "Mac Family:"), selection: $selectedFamily) {
                        ForEach(families, id: \.self) { fam in
                            Text(fam == "All" ? lang.text("Tutti i modelli", "All families") : fam).tag(fam)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)

                List(filteredSpecs, selection: $selectedSpec) { spec in
                    CompatibilityRowView(spec: spec, lang: lang)
                        .tag(spec)
                }
            }
            .frame(minWidth: 360, idealWidth: 410)

            Group {
                if let spec = selectedSpec {
                    CompatibilityDetailView(spec: spec, lang: lang)
                } else {
                    ContentUnavailableView(
                        lang.text("Seleziona un modello di Mac", "Select a Mac Model"),
                        systemImage: "laptopcomputer"
                    )
                }
            }
            .frame(minWidth: 440)
        }
        .searchable(
            text: $searchText,
            prompt: lang.text("Cerca modello (es. Mac16,1, iBridge2,14, M4, T2, J314sAP)...", "Search model (e.g. Mac16,1, iBridge2,14, M4, T2, J314sAP)...")
        )
        .navigationTitle(prefs.tr("Mac Realmente Compatibili (Apple Silicon, Intel T2 & Pre-T2)", "Truly Compatible Macs (Apple Silicon, Intel T2 & Pre-T2)"))
    }
}

private struct CompatibilityRowView: View {
    let spec: CompatibleMacSpec
    let lang: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(spec.marketingName)
                    .font(.subheadline.bold())
                Spacer()
                Text(spec.category.shortBadge(in: lang))
                    .font(.caption2.bold())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(badgeColor.opacity(0.2))
                    .foregroundStyle(badgeColor)
                    .clipShape(Capsule())
            }
            Text("\(spec.modelIdentifier) · DFU: \(spec.dfuTargetIdentifier) · Board: \(spec.boardConfig)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var badgeColor: Color {
        switch spec.category {
        case .appleSilicon: .green
        case .intelT2: .cyan
        case .intelPreT2: .orange
        }
    }
}

private struct CompatibilityDetailView: View {
    let spec: CompatibleMacSpec
    let lang: AppLanguage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(spec.marketingName)
                            .font(.title2.bold())
                        Text(spec.category.title(in: lang))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Label(
                        spec.category.supportsDFU
                            ? lang.text("Compatibile DFU & VDM", "DFU & VDM Compatible")
                            : lang.text("NO DFU (Solo Target Disk Mode)", "NO DFU (Target Disk Mode Only)"),
                        systemImage: spec.category.supportsDFU ? "checkmark.seal.fill" : "exclamationmark.octagon.fill"
                    )
                    .font(.callout.bold())
                    .padding(10)
                    .background((spec.category.supportsDFU ? Color.green : Color.orange).opacity(0.18))
                    .foregroundStyle(spec.category.supportsDFU ? Color.green : Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Visual Interactive USB-C Port Diagram!
                VisualPortDiagramCard(spec: spec, lang: lang)

                // Hardware Identifiers
                VStack(alignment: .leading, spacing: 8) {
                    Label(lang.text("Identificatori Hardware & BootROM", "Hardware & BootROM Identifiers"), systemImage: "cpu")
                        .font(.headline)
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                        GridRow {
                            Text("Model Identifier:").bold()
                            Text(spec.modelIdentifier).monospaced().textSelection(.enabled)
                        }
                        GridRow {
                            Text(lang.text("Target in DFU:", "DFU Target ID:")).bold()
                            Text(spec.dfuTargetIdentifier).monospaced().textSelection(.enabled)
                        }
                        GridRow {
                            Text("Board Config:").bold()
                            Text(spec.boardConfig).monospaced().textSelection(.enabled)
                        }
                        GridRow {
                            Text("Chip / SoC:").bold()
                            Text(spec.chipName(in: lang))
                        }
                        GridRow {
                            Text("CPID & BDID:").bold()
                            Text("CPID: \(spec.cpidHex) · BDID: \(spec.bdidHex)").monospaced()
                        }
                    }
                }
                .styledCard()

                // VDM & Restore Notes
                VStack(alignment: .leading, spacing: 10) {
                    Label(lang.text("Comportamento VDM & Ripristino (Revive / Restore)", "VDM & Restore Behavior (Revive / Restore)"), systemImage: "bolt.horizontal.fill")
                        .font(.headline)
                    Text(spec.vdmSupportNote(in: lang))
                        .font(.callout)
                    Divider()
                    Text(spec.restoreBehaviorNote(in: lang))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .styledCard()

                // Supported Diagnostics List
                VStack(alignment: .leading, spacing: 8) {
                    Label(lang.text("Funzioni Supportate via Cavo dall'Host Apple Silicon", "Supported Cabled Functions from Apple Silicon Host"), systemImage: "checklist")
                        .font(.headline)
                    ForEach(spec.supportedDiagnostics(in: lang), id: \.self) { item in
                        Label(item, systemImage: "checkmark.circle.fill")
                            .font(.callout)
                    }
                }
                .styledCard()
            }
            .padding(20)
        }
    }
}

private struct VisualPortDiagramCard: View {
    let spec: CompatibleMacSpec
    let lang: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(
                    lang.text("Mappa Visiva Porta DFU (Apple HT120694)", "Visual DFU Port Map (Apple HT120694)"),
                    systemImage: "cable.connector.horizontal"
                )
                .font(.headline)
                Spacer()
                if spec.portVisual.isExceptionHT120694 {
                    Text(lang.text("⚠️ ECCEZIONE HT120694", "⚠️ HT120694 EXCEPTION"))
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.22))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
            }

            if spec.portVisual.face != .none, let dfuIdx = spec.portVisual.dfuPortIndexOneBased {
                VStack(spacing: 8) {
                    Text(spec.portVisual.face.label(in: lang))
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    HStack(spacing: 16) {
                        if spec.portVisual.face == .leftSide {
                            Text(lang.text("◀ Cerniera / Schermo", "◀ Display Hinge"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else if spec.portVisual.face == .backPanel {
                            Text(lang.text("◀ Lato Sinistro", "◀ Left Edge"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        if spec.portVisual.hasMagSafeOnLeft {
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.secondary.opacity(0.35))
                                    .frame(width: 28, height: 12)
                                Text("MagSafe 3")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        ForEach(1...spec.portVisual.totalUSBCPortsOnFace, id: \.self) { idx in
                            let isDFU = (idx == dfuIdx)
                            VStack(spacing: 4) {
                                ZStack {
                                    Capsule()
                                        .fill(isDFU ? Color.green : Color.secondary.opacity(0.25))
                                        .frame(width: 34, height: 14)
                                        .overlay(
                                            Capsule()
                                                .strokeBorder(isDFU ? Color.white : Color.secondary.opacity(0.5), lineWidth: 1.5)
                                        )
                                }
                                Text(isDFU ? "★ DFU (#\(idx))" : "USB-C #\(idx)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(isDFU ? Color.green : Color.secondary)
                            }
                        }

                        if spec.portVisual.face == .leftSide {
                            Text(lang.text("Trackpad / Fronte ▶", "Trackpad / Front ▶"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else if spec.portVisual.face == .backPanel {
                            Text(lang.text("Lato Destro ▶", "Right Edge ▶"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(Color.black.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            Text(spec.dfuPortLocation(in: lang))
                .font(.callout)
        }
        .styledCard()
    }
}

// MARK: - 4. Official Port & Cable Guide View
struct PortAndCableGuideView: View {
    let prefs: AppPreferences
    private var lang: AppLanguage { prefs.language }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    Label(
                        lang.text("1. Quale Cavo Usare? (USB-C Dati vs SuperSpeed vs Thunderbolt 3)", "1. Which Cable Should You Use? (USB-C Data vs SuperSpeed vs Thunderbolt 3)"),
                        systemImage: "cable.connector"
                    )
                    .font(.headline)

                    HStack(alignment: .top, spacing: 14) {
                        CableGuideBox(
                            badge: lang.text("✅ CONSIGLIATO PER DFU", "✅ RECOMMENDED FOR DFU"),
                            color: .green,
                            title: lang.text("Cavo USB-C Dati & Ricarica (USB 2.0 / 3.x)", "USB-C Data & Charge Cable (USB 2.0 / 3.x)"),
                            detail: lang.text(
                                "Il cavo Apple USB-C Charge Cable bianco o qualsiasi cavo USB-C dati trasporta il canale CC (per i pacchetti VDM 1-Click DFU) e le linee D+/D- per il flash dell'IPSW con cfgutil / Finder. Collegamento diretto senza hub!",
                                "Apple's white USB-C Charge Cable or any USB-C data cable carries the CC wire (for 1-Click DFU VDMs) and USB D+/D- data lines for IPSW flashing via cfgutil / Finder. Direct connection with no hubs!"
                            )
                        )
                        CableGuideBox(
                            badge: lang.text("⚡ PER SERIALE SBU & TDM", "⚡ FOR SBU SERIAL & TDM"),
                            color: .cyan,
                            title: lang.text("Cavo USB-C 3.1/3.2 SuperSpeed o USB4 / TB4", "USB-C 3.1/3.2 SuperSpeed or USB4 / TB4 Cable"),
                            detail: lang.text(
                                "La console seriale UART VDM (/dev/cu.debug-console) viaggia sui pin SBU1/SBU2, assenti nei cavi USB 2.0 di sola ricarica. Usa un cavo USB 3.x SuperSpeed o USB4/TB4 completo per la seriale UART o il Target Disk Mode.",
                                "The VDM UART serial console (/dev/cu.debug-console) uses the SBU1/SBU2 wires, which USB 2.0 charge cables lack. Use a full-featured USB 3.x SuperSpeed or USB4/TB4 cable for UART serial or Target Disk Mode."
                            )
                        )
                        CableGuideBox(
                            badge: lang.text("❌ EVITARE PER DFU", "❌ AVOID FOR DFU"),
                            color: .orange,
                            title: lang.text("Cavi Thunderbolt 3 Attivi & Hub USB", "Active Thunderbolt 3 Cables & USB Hubs"),
                            detail: lang.text(
                                "Apple Support HT108900 / HT120694 specifica di NON usare cavi Thunderbolt 3 per il DFU (spesso causano errore Billboard 05ac:7304). Inoltre gli hub USB bloccano i pacchetti VDM sul pin CC.",
                                "Apple Support HT108900 / HT120694 explicitly warns NOT to use Thunderbolt 3 cables for DFU (often triggering Billboard error 05ac:7304). Also, USB hubs block VDM packets on the CC line."
                            )
                        )
                    }
                }
                .styledCard()

                VStack(alignment: .leading, spacing: 10) {
                    Label(
                        lang.text("2. Tabella Riepilogativa Posizione Porta DFU (Apple Support HT120694)", "2. DFU Port Location Summary Table (Apple Support HT120694)"),
                        systemImage: "tablecells"
                    )
                    .font(.headline)

                    PortRuleRow(
                        title: lang.text("MacBook Pro 14\" & 16\" (M1/M2/M3/M4/M5 Pro & Max, e 14\" M3 base)", "14\" & 16\" MacBook Pro (M1/M2/M3/M4/M5 Pro & Max, plus 14\" base M3)"),
                        rule: lang.text("Lato sinistro: porta USB-C più a SINISTRA (vicina alla cerniera, subito accanto a MagSafe 3).", "Left side: LEFTMOST USB-C port (closest to the display hinge, right next to MagSafe 3)."),
                        isException: false
                    )
                    PortRuleRow(
                        title: lang.text("⚠️ ECCEZIONE: MacBook Pro 14\" con chip M4, M5 o M6 BASE (non Pro/Max!)", "⚠️ EXCEPTION: 14\" MacBook Pro with BASE M4, M5, or M6 chip (excluding Pro/Max!)"),
                        rule: lang.text("Lato sinistro: porta USB-C più a DESTRA (più vicina al trackpad/fronte, NON quella vicina a MagSafe!).", "Left side: RIGHTMOST USB-C port (closest to the trackpad/front, NOT the one next to MagSafe!)."),
                        isException: true
                    )
                    PortRuleRow(
                        title: lang.text("MacBook Air & MacBook Pro 13\" con M1, M2, M3 (2020–2024)", "MacBook Air & 13\" MacBook Pro with M1, M2, M3 (2020–2024)"),
                        rule: lang.text("Lato sinistro: porta USB-C più a SINISTRA (vicina alla cerniera/schermo).", "Left side: LEFTMOST USB-C port (closest to the display hinge)."),
                        isException: false
                    )
                    PortRuleRow(
                        title: lang.text("⚠️ ECCEZIONE: MacBook Air 2025 o successivi (M4, M5)", "⚠️ EXCEPTION: MacBook Air introduced in 2025 or later (M4, M5)"),
                        rule: lang.text("Lato sinistro: porta USB-C più a DESTRA (più vicina al trackpad/fronte).", "Left side: RIGHTMOST USB-C port (closest to the trackpad/front)."),
                        isException: true
                    )
                    PortRuleRow(
                        title: lang.text("MacBook Pro & MacBook Air INTEL con Chip T2 (2018–2020)", "INTEL MacBook Pro & MacBook Air with T2 Chip (2018–2020)"),
                        rule: lang.text("Lato sinistro: porta Thunderbolt 3 (USB-C) più a DESTRA (più vicina al trackpad/fronte).", "Left side: RIGHTMOST Thunderbolt 3 (USB-C) port (closest to the trackpad/front)."),
                        isException: false
                    )
                    PortRuleRow(
                        title: lang.text("Mac mini M1, M2, M2 Pro (2020–2023)", "Mac mini with M1, M2, M2 Pro (2020–2023)"),
                        rule: lang.text("Retro (visto da dietro): porta Thunderbolt/USB-C più a SINISTRA (vicina al cavo di alimentazione).", "Back panel: LEFTMOST Thunderbolt/USB-C port (closest to the power cord)."),
                        isException: false
                    )
                    PortRuleRow(
                        title: lang.text("⚠️ ECCEZIONE: Mac mini M4 / M4 Pro / M5 Pro / M6 (fine 2024 / 2025+)", "⚠️ EXCEPTION: Mac mini M4 / M4 Pro / M5 Pro / M6 (Late 2024 / 2025+)"),
                        rule: lang.text("Retro (visto da dietro): porta Thunderbolt/USB-C CENTRALE (quella in mezzo delle 3 porte posteriori).", "Back panel: MIDDLE Thunderbolt/USB-C port (center of the 3 rear ports)."),
                        isException: true
                    )
                    PortRuleRow(
                        title: lang.text("iMac (Tutti i 24\" Apple Silicon, iMac 27\" 2020 T2, iMac Pro 2017 T2), Mac Studio & Mac mini 2018 T2", "iMac (All 24\" Apple Silicon, 27\" 2020 T2, iMac Pro 2017 T2), Mac Studio & 2018 T2 Mac mini"),
                        rule: lang.text("Retro (visto da dietro): porta Thunderbolt/USB-C più a DESTRA.", "Back panel: RIGHTMOST Thunderbolt/USB-C port."),
                        isException: false
                    )
                }
                .styledCard()
            }
            .padding(22)
        }
        .navigationTitle(prefs.tr("Guida Ufficiale Porte DFU & Cavi (Apple HT120694)", "Official DFU Port & Cable Guide (Apple HT120694)"))
    }
}

private struct CableGuideBox: View {
    @Environment(\.colorScheme) private var colorScheme
    let badge: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(badge)
                .font(.caption2.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(color.opacity(0.2))
                .foregroundStyle(color)
                .clipShape(Capsule())
            Text(title)
                .font(.subheadline.bold())
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(AppPalette.elevatedBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct PortRuleRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let rule: String
    let isException: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(isException ? Color.orange : Color.primary)
            Text(rule)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isException ? Color.orange.opacity(0.1) : AppPalette.elevatedBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
