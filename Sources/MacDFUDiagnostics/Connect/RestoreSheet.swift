import SwiftUI
import UniformTypeIdentifiers

/// Chooses how to restore, and confirms it. A restore erases the Mac, so this is the one place that asks.
///
/// What each choice does comes from Apple ("How to revive or restore Mac firmware", support article
/// 108900) and from what `cfgutil restore` accepts: the latest system, or a firmware file given with `-I`.
struct RestoreSheet: View {
    let device: TargetDevice

    @Environment(DiagnosticsEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    @State private var source: Source = .latest
    @State private var isChoosingFile = false

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

            if let free = freeSpace, free < Self.suggestedFreeSpace, source == .latest || device.isIntelT2 {
                note("Apple suggests 60 GB free on this Mac. There is \(ByteCountFormatter.string(fromByteCount: free, countStyle: .file)).", symbol: "internaldrive")
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
        }
        .fileImporter(isPresented: $isChoosingFile, allowedContentTypes: [Self.firmwareType]) { result in
            if case .success(let url) = result, DiagnosticsEngine.isFirmwareFile(url) {
                engine.firmwareURL = url
                source = .file
            }
        }
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
