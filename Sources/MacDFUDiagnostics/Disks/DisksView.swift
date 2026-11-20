import SwiftUI

/// Another Mac's storage, reached over a cable: an Intel Mac in Target Disk Mode shows up here as a disk,
/// and a Mac with Apple silicon shares its disk from macOS Recovery.
///
/// The steps shown are Apple's own, from the Mac User Guide ("Transfer files between two Mac computers
/// using target disk mode" and "Use Share Disk to transfer files between two Mac computers").
struct DisksView: View {
    @Environment(DiagnosticsEngine.self) private var engine

    private let diskColumns = [GridItem(.adaptive(minimum: 320, maximum: 480), spacing: Metrics.standard, alignment: .top)]
    private let guideColumns = [GridItem(.adaptive(minimum: 300, maximum: 520), spacing: Metrics.standard, alignment: .top)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.roomy) {
                if !engine.hasLoadedDisks {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else if !engine.disks.isEmpty {
                    LazyVGrid(columns: diskColumns, spacing: Metrics.standard) {
                        ForEach(engine.disks) { disk in
                            DiskCard(disk: disk)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: Metrics.compact) {
                    Text(engine.disks.isEmpty ? "Use another Mac as a disk" : "Connect another Mac")
                        .font(.title3.weight(.semibold))
                    LazyVGrid(columns: guideColumns, spacing: Metrics.standard) {
                        TargetDiskGuide()
                        ShareDiskGuide()
                    }
                }

                HStack(spacing: Metrics.compact) {
                    Button("Migration Assistant", systemImage: "arrow.left.arrow.right") {
                        engine.open(.migrationAssistant)
                    }
                    .help("Moves accounts, apps and files from a connected Mac")
                    Button("Disk Utility", systemImage: "stethoscope") {
                        engine.open(.diskUtility)
                    }
                    .help("Repairs a disk with First Aid")
                }
                .secondaryActionStyle()
                .controlSize(.large)
            }
            .padding(Metrics.roomy)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(Text("Disks"))
        .toolbar {
            ToolbarItem {
                BridgeBadge(state: engine.bridge)
            }
            ToolbarItem {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task { await engine.refreshDisks() }
                }
                .help("Look for disks again")
            }
            InspectorToggle()
        }
        .task {
            await engine.refreshDisks()
        }
    }
}

private struct BridgeBadge: View {
    let state: BridgeState

    var body: some View {
        Label {
            switch state {
            case .active: Text("Thunderbolt Bridge on")
            case .inactive: Text("Thunderbolt Bridge idle")
            case .absent: Text("No Thunderbolt Bridge")
            }
        } icon: {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .foregroundStyle(state == .active ? AnyShapeStyle(.green) : AnyShapeStyle(.secondary))
        }
        .labelStyle(.titleAndIcon)
        .font(.callout)
        .padding(.horizontal, Metrics.tight)
        .help("Networking between two Macs over a Thunderbolt cable")
    }
}

// MARK: - Guides

/// Intel Macs: Target Disk Mode.
private struct TargetDiskGuide: View {
    var body: some View {
        GuideCard(symbol: "externaldrive.connected.to.line.below", title: "Target Disk Mode", kind: "Intel Mac") {
            GuideStep(1) { Text("Connect the two Macs with a Thunderbolt cable.") }
            GuideStep(2) {
                HStack(spacing: Metrics.tight) {
                    Text("Start the Intel Mac while holding")
                    Keycap("T")
                }
            }
            GuideStep(3) { Text("Its disk appears here and in the Finder.") }
            GuideStep(4) { Text("When done, eject it, then turn that Mac off with its power button.") }
        } footer: {
            Text("If that Mac is on: System Settings › General › Startup Disk › Restart in Target Disk Mode.")
        }
    }
}

/// Macs with Apple silicon: Share Disk, from macOS Recovery.
private struct ShareDiskGuide: View {
    @Environment(DiagnosticsEngine.self) private var engine

    var body: some View {
        GuideCard(symbol: "macbook.and.iphone", title: "Share Disk", kind: "Mac with Apple silicon") {
            GuideStep(1) { Text("Connect the two Macs with a USB-C or Thunderbolt cable.") }
            GuideStep(2) { Text("On the other Mac, hold the power button until Options appears, then open Options.") }
            GuideStep(3) { Text("Choose Utilities › Share Disk, pick a volume and click Start Sharing.") }
            GuideStep(4) { Text("On this Mac, open Network, double-click that Mac and connect as Guest.") }
            GuideStep(5) { Text("When done, eject the volume, then click Stop Sharing.") }
        } footer: {
            Button("Open Network", systemImage: "network") {
                engine.open(.network)
            }
            .help("Opens the Finder's Network window")
        }
    }
}

private struct GuideCard<Steps: View, Footer: View>: View {
    let symbol: String
    let title: LocalizedStringKey
    let kind: LocalizedStringKey
    @ViewBuilder var steps: Steps
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.compact) {
            HStack(spacing: Metrics.compact) {
                Image(systemName: symbol)
                    .font(.system(size: 24, weight: .light))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
                    .frame(width: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(kind)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: Metrics.tight) {
                steps
            }
            footer
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(Metrics.standard)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .glassSurface()
    }
}

/// One numbered line of a guide.
struct GuideStep<Content: View>: View {
    let number: Int
    @ViewBuilder var content: Content

    init(_ number: Int, @ViewBuilder content: () -> Content) {
        self.number = number
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.tight) {
            Text(verbatim: "\(number)")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(.tint)
                .frame(width: 20, height: 20)
                .background(.tint.opacity(0.15), in: .circle)
            content
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A key, drawn the way it looks on the keyboard.
struct Keycap: View {
    let symbol: String
    var caption: LocalizedStringKey?

    init(_ symbol: String, caption: LocalizedStringKey? = nil) {
        self.symbol = symbol
        self.caption = caption
    }

    var body: some View {
        VStack(spacing: 1) {
            Text(verbatim: symbol)
                .font(.system(size: caption == nil ? 13 : 15, weight: .medium, design: .rounded))
            if let caption {
                Text(caption)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: caption == nil ? 24 : 52, minHeight: caption == nil ? 24 : 40)
        .padding(.horizontal, 4)
        .background(.background.secondary, in: .rect(cornerRadius: 6))
        .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(.separator) }
        .shadow(color: .black.opacity(0.12), radius: 0.5, y: 1)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Disk

private struct DiskCard: View {
    let disk: ExternalDisk

    @Environment(DiagnosticsEngine.self) private var engine
    @State private var showsOutput = false

    private var check: DiskCheck? { engine.diskChecks[disk.id] }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.compact) {
            HStack(spacing: Metrics.compact) {
                Image(systemName: "externaldrive.fill")
                    .font(.system(size: 30))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: disk.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(verbatim: [disk.formattedSize, disk.bus, disk.id].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)

                Button("Eject", systemImage: "eject.fill") {
                    Task { await engine.eject(disk) }
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Eject before disconnecting the cable")
            }

            if !disk.visibleVolumes.isEmpty {
                HStack(spacing: Metrics.tight) {
                    ForEach(disk.visibleVolumes) { volume in
                        Button {
                            engine.reveal(volume)
                        } label: {
                            Label {
                                Text(verbatim: volume.name).lineLimit(1)
                            } icon: {
                                Image(systemName: "folder")
                            }
                        }
                        .help("Show in the Finder")
                    }
                }
                .controlSize(.small)
            }

            HStack(spacing: Metrics.tight) {
                if let smart = disk.smartStatus {
                    StatusChip(
                        text: smart == "Verified" ? "SMART OK" : "SMART failing",
                        tint: smart == "Verified" ? .green : .red,
                        symbol: smart == "Verified" ? "checkmark.seal.fill" : "xmark.seal.fill"
                    )
                }
                result
                Spacer(minLength: 0)
                Button(check == nil ? "Check" : "Check Again") {
                    Task { await engine.check(disk) }
                }
                .disabled(check?.outcome == .running)
                .help("Checks the partition map and file systems. Nothing is changed.")
            }

            if showsOutput, let output = check?.output, !output.isEmpty {
                ScrollView {
                    Text(verbatim: output)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Metrics.tight)
                }
                .frame(maxHeight: 160)
                .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: Metrics.insetRadius))
                .transition(.opacity)
            }
        }
        .padding(Metrics.standard)
        .glassSurface()
        .animation(.smooth, value: showsOutput)
        .animation(.smooth, value: check)
    }

    @ViewBuilder
    private var result: some View {
        switch check?.outcome {
        case .running:
            ProgressView()
                .controlSize(.small)
        case .passed:
            Button { showsOutput.toggle() } label: {
                StatusChip(text: "Passed", tint: .green, symbol: "checkmark.circle.fill")
            }
            .buttonStyle(.plain)
            .help("Show the full output")
        case .problems:
            Button { showsOutput.toggle() } label: {
                StatusChip(text: "Problems found", tint: .orange, symbol: "exclamationmark.triangle.fill")
            }
            .buttonStyle(.plain)
            .help("Show the full output")
        case nil:
            EmptyView()
        }
    }
}
