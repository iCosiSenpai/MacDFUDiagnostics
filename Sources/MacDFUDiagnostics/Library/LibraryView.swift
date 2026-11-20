import SwiftUI

/// Every Mac the app knows, each with a picture of where its DFU port is.
struct LibraryView: View {
    @Environment(DiagnosticsEngine.self) private var engine
    @State private var query = ""
    @State private var architecture: MacArchitecture?

    private let columns = [GridItem(.adaptive(minimum: 230, maximum: 320), spacing: Metrics.standard, alignment: .top)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: Metrics.standard, pinnedViews: []) {
                ForEach(groups, id: \.family) { group in
                    Section {
                        ForEach(group.models) { model in
                            MacCard(model: model, isHost: model.id == engine.host.model?.id)
                        }
                    } header: {
                        Label(group.family.rawValue, systemImage: group.family.symbol)
                            .font(.title3.weight(.semibold))
                            .padding(.top, Metrics.tight)
                    }
                }
            }
            .padding(Metrics.roomy)
        }
        .overlay {
            if groups.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .navigationTitle(Text("Macs"))
        .searchable(text: $query, prompt: "Model, chip or identifier")
        .toolbar {
            ToolbarItem {
                Picker("Kind", selection: $architecture) {
                    Text("All").tag(MacArchitecture?.none)
                    ForEach(MacArchitecture.allCases) { kind in
                        Text(kind.label).tag(Optional(kind))
                    }
                }
                .pickerStyle(.segmented)
                .help("Show only one kind of Mac")
            }
            InspectorToggle()
        }
    }

    private struct FamilyGroup {
        let family: MacFamily
        let models: [MacModel]
    }

    private var groups: [FamilyGroup] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        let matching = MacCatalog.all.filter { model in
            (architecture == nil || model.architecture == architecture)
                && (needle.isEmpty
                    || [model.name, model.chip, model.modelIdentifier, model.board ?? "", model.restoreIdentifier ?? ""]
                        .contains { $0.localizedCaseInsensitiveContains(needle) })
        }
        return MacFamily.allCases.compactMap { family in
            // Apple silicon before Intel, and newest first: each list in the catalog is written oldest first.
            let models = MacArchitecture.allCases.flatMap { kind in
                matching.filter { $0.family == family && $0.architecture == kind }.reversed()
            }
            return models.isEmpty ? nil : FamilyGroup(family: family, models: models)
        }
    }
}

private struct MacCard: View {
    let model: MacModel
    let isHost: Bool

    @State private var showsDetails = false

    var body: some View {
        Button {
            showsDetails = true
        } label: {
            VStack(alignment: .leading, spacing: Metrics.compact) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: model.name)
                            .font(.headline)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text(verbatim: model.chip)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: Metrics.tight)
                    if isHost {
                        StatusChip(text: "This Mac", tint: .accentColor)
                    } else if model.port.isException {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                            .help("The DFU port is not where the rest of this family has it")
                    }
                }

                PortDiagram(layout: model.port, tint: tint)
                    .frame(maxWidth: .infinity, minHeight: 44)

                Text(model.port.caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(Metrics.standard)
            .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
            .contentShape(.rect(cornerRadius: Metrics.cardRadius))
        }
        .buttonStyle(.plain)
        .glassSurface(tint: isHost ? Color.accentColor.opacity(0.1) : nil)
        .hoverLift()
        .popover(isPresented: $showsDetails) {
            MacDetails(model: model)
                .chosenLanguage()
        }
    }

    private var tint: Color {
        model.port.isException ? .orange : .accentColor
    }
}

private struct MacDetails: View {
    let model: MacModel

    private static let appleGuide = URL(string: "https://support.apple.com/120694")!

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.standard) {
            HStack(spacing: Metrics.compact) {
                Image(systemName: model.family.symbol)
                    .font(.system(size: 34, weight: .light))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: model.name)
                        .font(.headline)
                    Text(model.architecture.label)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            PortDiagram(layout: model.port, tint: model.port.isException ? .orange : .accentColor, scale: 1.5, isAnimated: true)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Metrics.tight)

            Text(model.port.caption)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            Grid(alignment: .leading, horizontalSpacing: Metrics.standard, verticalSpacing: 6) {
                detail("Identifier", model.modelIdentifier)
                detail("Chip", model.chip)
                detail("Board", model.board)
                if model.architecture == .intelT2 {
                    detail("Restores as", model.restoreIdentifier)
                }
            }
            .font(.callout)

            HStack(spacing: Metrics.tight) {
                capability("DFU", model.architecture.supportsDFU)
                capability("Revive", model.architecture.supportsDFU)
                capability(model.architecture == .appleSilicon ? "Share Disk" : "Target Disk Mode", true)
                Spacer(minLength: 0)
                Link(destination: Self.appleGuide) {
                    Image(systemName: "arrow.up.right")
                }
                .help("Apple's guide to DFU ports")
            }
        }
        .padding(Metrics.standard)
        .frame(width: 340)
    }

    @ViewBuilder
    private func detail(_ label: LocalizedStringKey, _ value: String?) -> some View {
        if let value {
            GridRow {
                Text(label).foregroundStyle(.secondary)
                Text(verbatim: value).monospaced().textSelection(.enabled)
            }
        }
    }

    private func capability(_ label: LocalizedStringResource, _ isSupported: Bool) -> some View {
        StatusChip(
            text: label,
            tint: isSupported ? .green : .secondary,
            symbol: isSupported ? "checkmark" : "minus"
        )
    }
}
