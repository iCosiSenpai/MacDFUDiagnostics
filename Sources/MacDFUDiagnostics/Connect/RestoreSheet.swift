import SwiftUI
import UniformTypeIdentifiers

/// Chooses how to restore, and confirms it. A restore erases the Mac, so this is the one place that asks.
///
/// What each choice does comes from Apple ("How to revive or restore Mac firmware", support article
/// 108900) and from what `cfgutil restore` accepts: the latest system, or a firmware file given with `-I`.
struct RestoreSheet: View {
    let device: TargetDevice

    @Environment(DiagnosticsEngine.self) private var engine
    @Environment(Readiness.self) private var readiness
    @Environment(\.dismiss) private var dismiss
    @State private var source: Source = .latest
    @State private var isChoosingFile = false
    /// The restore images IPSW Downloader Plus keeps for this Mac. Read once, when the sheet opens.
    @State private var libraryFirmware: [LibraryFirmware] = []

    private enum Source {
        case latest
        case file
    }

    private static let firmwareType = UTType(filenameExtension: "ipsw") ?? .data
    /// Apple: "60GB should be more than enough" on the Mac doing the restoring.
    private static let suggestedFreeSpace: Int64 = 60_000_000_000

    var body: some View {
        VStack(spacing: Metrics.standard) {
            Image(systemName: "eraser.fill")
                .font(.system(size: 30))
                .foregroundStyle(.red)
                .frame(width: 64, height: 64)
                .background(.red.opacity(0.14), in: .circle)

            VStack(spacing: Metrics.tight) {
                Text("Erase and restore?")
                    .font(.title2.weight(.semibold))
                Text("Everything on \(device.title) will be deleted. This can't be undone.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if device.isIntelT2 {
                note("The T2 chip's firmware is restored. Afterwards the Mac starts macOS Recovery over the internet, where you install macOS.", symbol: "info.circle")
            } else {
                VStack(spacing: Metrics.tight) {
                    option(.latest, symbol: "arrow.down.circle", title: "Latest macOS") {
                        Text("Downloaded from Apple.")
                    }
                    option(.file, symbol: "doc.zipper", title: "From a firmware file") {
                        if let firmware = engine.firmwareURL {
                            Text(verbatim: firmware.lastPathComponent)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else {
                            Text("Install the version in an IPSW file you choose.")
                        }
                    }
                }
            }

            if !device.isIntelT2, !libraryFirmware.isEmpty {
                libraryPicks
            }

            if let free = freeSpace, free < Self.suggestedFreeSpace, source == .latest || device.isIntelT2 {
                note("Apple suggests 60 GB free on this Mac. There is \(ByteCountFormatter.string(fromByteCount: free, countStyle: .file)).", symbol: "internaldrive")
            }

            if readiness.isOnBattery {
                note("This Mac is running on battery. Plug it in before you start.", symbol: "battery.50percent")
            }
            if !readiness.isOnline, source == .latest || device.isIntelT2 {
                note("This Mac is offline. The firmware is downloaded from Apple.", symbol: "wifi.slash")
            }
            if !device.isIntelT2, source == .file {
                Button {
                    openFirmwareFinder()
                } label: {
                    Group {
                        if firmwareRequest == nil {
                            Label("Find firmware files with IPSW Downloader Plus", systemImage: "arrow.up.right.square")
                        } else {
                            Label("Find firmware for this Mac with IPSW Downloader Plus", systemImage: "arrow.up.right.square")
                        }
                    }
                    .font(.callout)
                }
                .buttonStyle(.link)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: Metrics.compact) {
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Erase and Restore", role: .destructive) {
                    if source == .latest { engine.firmwareURL = nil }
                    dismiss()
                    Task { await engine.restore(device) }
                }
                .tint(.red)
                .disabled(source == .file && engine.firmwareURL == nil)
            }
            .controlSize(.large)
            .padding(.top, Metrics.tight)
        }
        .padding(Metrics.roomy)
        .frame(width: 420)
        .onAppear {
            source = engine.firmwareURL == nil ? .latest : .file
            // A demo has no real Mac on the cable and no business reading another app's files.
            if engine.demo == nil, let identifier = device.model?.restoreIdentifier, !device.isIntelT2 {
                libraryFirmware = FirmwareLibrary.firmware(for: identifier)
            }
        }
        .fileImporter(isPresented: $isChoosingFile, allowedContentTypes: [Self.firmwareType]) { result in
            if case .success(let url) = result, DiagnosticsEngine.isFirmwareFile(url) {
                engine.firmwareURL = url
                source = .file
            }
        }
    }

    /// The link that asks IPSW Downloader Plus for this Mac's firmware, when the Mac is known.
    private var firmwareRequest: URL? {
        device.model?.restoreIdentifier.flatMap(Links.ipswDownloaderFirmware(for:))
    }

    /// Opens the sibling app that downloads firmware files — on this Mac's model when it is known —
    /// or its page when it is not installed.
    private func openFirmwareFinder() {
        guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Links.ipswDownloaderBundleID) else {
            NSWorkspace.shared.open(Links.ipswDownloader)
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        if let firmwareRequest {
            // Addressed to that app by name: a URL scheme can be claimed by anything installed.
            NSWorkspace.shared.open([firmwareRequest], withApplicationAt: app, configuration: configuration)
        } else {
            NSWorkspace.shared.openApplication(at: app, configuration: configuration)
        }
    }

    /// The images already on this Mac that fit the one on the cable: one click instead of a file panel.
    private var libraryPicks: some View {
        VStack(alignment: .leading, spacing: Metrics.tight) {
            Text("In your IPSW Downloader Plus library")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            ForEach(libraryFirmware.prefix(3)) { firmware in
                let isChosen = source == .file && engine.firmwareURL == firmware.url
                Button {
                    engine.firmwareURL = firmware.url
                    source = .file
                } label: {
                    HStack(spacing: Metrics.tight) {
                        Image(systemName: isChosen ? "checkmark.circle.fill" : "shippingbox")
                            .foregroundStyle(isChosen ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                            .frame(width: 20)
                        // The warning under the name, not beside it: at this sheet's width the two
                        // side by side squeezed the name down to its middle.
                        VStack(alignment: .leading, spacing: 1) {
                            Text(verbatim: firmware.title)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            if firmware.signed == false {
                                Text("No longer signed by Apple")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                        Spacer(minLength: Metrics.tight)
                        Text(verbatim: firmware.formattedSize)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .font(.callout)
                    .padding(.horizontal, Metrics.compact)
                    .padding(.vertical, Metrics.tight)
                    .contentShape(.rect(cornerRadius: Metrics.insetRadius))
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .background(isChosen ? AnyShapeStyle(.tint.opacity(0.12)) : AnyShapeStyle(.quaternary.opacity(0.5)), in: .rect(cornerRadius: Metrics.insetRadius))
                .accessibilityAddTraits(isChosen ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var freeSpace: Int64? {
        let values = try? URL.homeDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }

    private func note(_ text: LocalizedStringKey, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One selectable way of restoring.
    private func option(_ value: Source, symbol: String, title: LocalizedStringKey, @ViewBuilder detail: () -> some View) -> some View {
        let isSelected = source == value
        return Button {
            source = value
            if value == .file, engine.firmwareURL == nil { isChoosingFile = true }
        } label: {
            HStack(spacing: Metrics.compact) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
                    detail()
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: Metrics.tight)
                if value == .file, isSelected {
                    Button("Choose…") { isChoosingFile = true }
                        .controlSize(.small)
                }
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    .font(.title3)
            }
            .padding(Metrics.compact)
            .contentShape(.rect(cornerRadius: Metrics.insetRadius))
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .background(isSelected ? AnyShapeStyle(.tint.opacity(0.12)) : AnyShapeStyle(.quaternary.opacity(0.5)), in: .rect(cornerRadius: Metrics.insetRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.insetRadius)
                .strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), lineWidth: 1.5)
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
