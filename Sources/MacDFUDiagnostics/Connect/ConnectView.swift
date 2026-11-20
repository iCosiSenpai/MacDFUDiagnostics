import SwiftUI
import UniformTypeIdentifiers

/// The main screen: this Mac, the cable, the other Mac, and the one thing to do next.
struct ConnectView: View {
    @Environment(DiagnosticsEngine.self) private var engine
    @Environment(Navigation.self) private var navigation
    @State private var isDropTargeted = false

    var body: some View {
        @Bindable var navigation = navigation

        VStack(spacing: Metrics.wide) {
            Spacer(minLength: Metrics.tight)
            LinkScene()
            Headline()
            ActionBar()
            Spacer(minLength: Metrics.tight)
            PortHint()
        }
        .padding(Metrics.roomy)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .top) {
            NoticeToast()
                .padding(.top, Metrics.tight)
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                    .strokeBorder(.tint, style: StrokeStyle(lineWidth: 3, dash: [10, 8]))
                    .padding(Metrics.compact)
                    .allowsHitTesting(false)
            }
        }
        .background {
            AmbientBackground(
                tint: ambientTint,
                isEnergetic: engine.isBusy,
                rippleTrigger: engine.arrivals &+ engine.successes
            )
            .extendedUnderSidebar()
            .ignoresSafeArea()
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let firmware = urls.first(where: DiagnosticsEngine.isFirmwareFile) else { return false }
            engine.firmwareURL = firmware
            engine.report(.info, "Firmware ready: \(firmware.lastPathComponent)")
            return true
        } isTargeted: { isDropTargeted = $0 }
        .toolbar { ConnectToolbar() }
        .toolbar(removing: .title)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .sheet(isPresented: $navigation.showsRestoreSheet) {
            if let device = engine.focusedDevice {
                RestoreSheet(device: device)
                    .chosenLanguage()
            }
        }
        .sheet(isPresented: $navigation.showsManualDFU) {
            ManualDFUSheet()
                .chosenLanguage()
        }
    }

    private var ambientTint: Color {
        if engine.isBusy { return .blue }
        return engine.focusedDevice?.state.tint ?? .accentColor
    }
}

// MARK: - Headline

/// One line that says what is connected, one that says what state it is in.
private struct Headline: View {
    @Environment(DiagnosticsEngine.self) private var engine

    var body: some View {
        VStack(spacing: 6) {
            title
                .font(.largeTitle.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .shimmer(engine.isBusy)
            subtitle
                .font(.title3)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: 520)
        // A plain cross-fade. Morphing the glyphs (numericText, interpolate) looks lovely and keeps
        // some 25 MB of text layout alive for as long as the window is open.
        .contentTransition(.opacity)
        .animation(.smooth(duration: 0.35), value: engine.focusedDevice?.id)
        .animation(.smooth(duration: 0.35), value: engine.operation?.kind)
        .accessibilityElement(children: .combine)
    }

    private var title: Text {
        if let operation = engine.operation {
            return Text(operation.kind.headline)
        }
        guard let device = engine.focusedDevice else {
            return Text("Connect a Mac")
        }
        return device.state == .cableFault ? Text("Check the cable") : Text(verbatim: device.title)
    }

    private var subtitle: Text {
        if let operation = engine.operation {
            if let progress = operation.progress {
                let percent = Text(progress, format: .percent.precision(.fractionLength(0)))
                guard let detail = operation.detail else { return percent }
                return percent + Text(verbatim: "  ·  \(detail)")
            }
            if case .vdm = operation.kind {
                return Text("Enter your password if asked.")
            }
            return Text("Keep both Macs connected and powered.")
        }
        guard let device = engine.focusedDevice else {
            return Text("Plug a USB-C cable into the DFU port of both Macs.")
        }
        switch device.state {
        case .dfu: return Text("Ready to revive or restore.")
        case .portDFU: return Text("The port controller needs a revive.")
        case .debugUSB: return Text("Debug USB is on.")
        case .recovery: return Text("In recovery mode.")
        case .wtf: return Text("Waiting for firmware.")
        case .restoring: return Text("A restore is in progress.")
        case .booted: return Text("Running macOS. Ready for DFU.")
        case .cableFault: return Text("Use a USB-C charge cable — not Thunderbolt — and no hub.")
        case .other: return Text("Connected.")
        }
    }
}

// MARK: - Actions

/// The buttons under the headline. What they are depends entirely on the state of the other Mac.
private struct ActionBar: View {
    @Environment(DiagnosticsEngine.self) private var engine
    @Environment(Navigation.self) private var navigation
    @Environment(\.openURL) private var openURL
    @State private var isConfirmingStop = false

    var body: some View {
        GlassGroup(spacing: Metrics.compact) {
            HStack(spacing: Metrics.compact) {
                if let operation = engine.operation {
                    if operation.canStop {
                        Button("Stop", systemImage: "stop.fill", role: .destructive) {
                            isConfirmingStop = true
                        }
                        .secondaryActionStyle()
                    }
                } else if let device = engine.focusedDevice, device.state.acceptsFirmware {
                    firmwareActions(for: device)
                } else {
                    Button("Enter DFU", systemImage: "bolt.fill") {
                        Task { await engine.send(.dfu) }
                    }
                    .primaryActionStyle()
                    .keyboardShortcut(.defaultAction)
                    .help("Puts the connected Mac into DFU mode")

                    if let device = engine.focusedDevice, device.state != .cableFault {
                        restartButton
                    }
                }
            }
        }
        .controlSize(.extraLarge)
        .frame(minHeight: 44)
        .animation(.smooth(duration: 0.35), value: engine.focusedDevice?.id)
        .animation(.smooth(duration: 0.35), value: engine.operation?.kind)
        .confirmationDialog("Stop now?", isPresented: $isConfirmingStop) {
            Button("Stop", role: .destructive) { engine.stopOperation() }
        } message: {
            Text("A Mac stopped half-way may not start until it is restored.")
        }
    }

    @ViewBuilder
    private func firmwareActions(for device: TargetDevice) -> some View {
        if engine.cfgutilPath == nil {
            Button("Get Apple Configurator", systemImage: "arrow.down.circle") {
                openURL(DiagnosticsEngine.configuratorURL)
            }
            .primaryActionStyle()
            .help("Reviving and restoring use Apple Configurator")
        } else {
            Button("Revive", systemImage: "arrow.triangle.2.circlepath") {
                Task { await engine.revive(device) }
            }
            .primaryActionStyle()
            .keyboardShortcut(.defaultAction)
            .help("Reinstalls firmware and keeps the data")

            Button("Restore…", systemImage: "eraser") {
                navigation.showsRestoreSheet = true
            }
            .secondaryActionStyle()
            .help("Erases the Mac and reinstalls everything")
        }
        restartButton
    }

    private var restartButton: some View {
        Button("Restart", systemImage: "arrow.counterclockwise") {
            Task { await engine.send(.restart) }
        }
        .secondaryActionStyle()
        .help("Restarts the connected Mac")
    }
}

// MARK: - Notice

/// A message that drops in from the top and leaves on its own.
private struct NoticeToast: View {
    @Environment(DiagnosticsEngine.self) private var engine
    @Environment(Navigation.self) private var navigation

    var body: some View {
        ZStack {
            if let notice = engine.notice {
                Button {
                    engine.dismissNotice()
                    if notice.level == .failure { navigation.showActivity() }
                } label: {
                    HStack(spacing: Metrics.tight) {
                        Image(systemName: notice.level.symbol)
                            .foregroundStyle(notice.level.tint)
                        Text(notice.message)
                            .lineLimit(2)
                    }
                    .font(.callout.weight(.medium))
                    .padding(.horizontal, Metrics.standard)
                    .padding(.vertical, 9)
                    .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .glassCapsule(interactive: true)
                .transition(.move(edge: .top).combined(with: .opacity))
                .id(notice.id)
                .help(notice.level == .failure ? "Show details" : "Dismiss")
            }
        }
        .animation(.spring(duration: 0.45, bounce: 0.25), value: engine.notice)
        .frame(maxWidth: 520)
    }
}

// MARK: - Toolbar

struct ConnectToolbar: ToolbarContent {
    @Environment(DiagnosticsEngine.self) private var engine

    var body: some ToolbarContent {
        @Bindable var engine = engine

        ToolbarItem {
            if engine.ports.count > 1 {
                Picker("Port", selection: $engine.selectedPortRID) {
                    ForEach(engine.ports) { port in
                        Text(verbatim: port.displayName).tag(port.rid)
                    }
                }
                .pickerStyle(.menu)
                .help("The port on this Mac that commands are sent through")
            }
        }

        ToolbarItem {
            Menu("More", systemImage: "ellipsis") {
                DeviceMenuItems()
            }
            .menuIndicator(.hidden)
            .help("More actions")
        }

        InspectorToggle()
    }
}

/// The button that shows and hides the inspector. Every screen ends its toolbar with it.
struct InspectorToggle: ToolbarContent {
    @Environment(Navigation.self) private var navigation

    var body: some ToolbarContent {
        ToolbarItem {
            Button("Inspector", systemImage: "sidebar.trailing") {
                navigation.showsInspector.toggle()
            }
            .help("Show or hide details and activity")
        }
    }
}

extension HostPort {
    /// `left-back` → "Left Back · DFU".
    var displayName: String {
        let readable = name.replacing("-", with: " ").replacing("_", with: " ").capitalized
        return isDFUCapable ? "\(readable) · DFU" : readable
    }
}

/// The less common actions. Shown in the toolbar's menu and in the Device menu of the menu bar.
struct DeviceMenuItems: View {
    @Environment(DiagnosticsEngine.self) private var engine
    @Environment(Preferences.self) private var preferences
    @Environment(Navigation.self) private var navigation

    var body: some View {
        Section {
            Button("Enter DFU by Hand…", systemImage: "keyboard") {
                navigation.section = .connect
                navigation.showsManualDFU = true
            }

            Button("Restart Target", systemImage: "arrow.counterclockwise") {
                Task { await engine.send(.restart) }
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Button("Test This Port", systemImage: "stethoscope") {
                Task { await engine.send(.probe) }
            }
        }

        Section("Developer") {
            Button("Start Serial Console", systemImage: "terminal") {
                Task { await engine.send(.serial) }
            }
            ForEach(engine.serialConsoles, id: \.self) { console in
                Button {
                    engine.openSerialConsole(console, baudRate: preferences.baudRate)
                } label: {
                    Label {
                        Text("Open \(URL(filePath: console).lastPathComponent) in Terminal")
                    } icon: {
                        Image(systemName: "apple.terminal")
                    }
                }
            }
            Button("Switch to Debug USB", systemImage: "ladybug") {
                Task { await engine.send(.debugUSB) }
            }
        }

        Section("Force DFU") {
            Button("As Apple Silicon") {
                Task { await engine.send(.dfuSilicon) }
            }
            Button("As Intel T2") {
                Task { await engine.send(.dfuT2) }
            }
        }
        .disabled(engine.isBusy)

        Section {
            Button("Copy Diagnostic Report", systemImage: "doc.on.doc") {
                engine.copyDiagnosticReport()
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
        }
    }
}
