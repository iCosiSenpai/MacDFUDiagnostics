import SwiftUI
import UniformTypeIdentifiers

/// The trailing panel: who the connected Mac is, and what has happened so far.
struct InspectorView: View {
    @Environment(Navigation.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation

        VStack(spacing: 0) {
            Picker("View", selection: $navigation.inspectorTab) {
                Text("Device").tag(InspectorTab.device)
                Text("Activity").tag(InspectorTab.activity)
                Text("History").tag(InspectorTab.history)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(Metrics.compact)

            switch navigation.inspectorTab {
            case .device: DeviceDetails()
            case .activity: ActivityList()
            case .history: HistoryList()
            }
        }
    }
}

// MARK: - Device

private struct DeviceDetails: View {
    @Environment(DiagnosticsEngine.self) private var engine

    var body: some View {
        if let device = engine.focusedDevice {
            Form {
                Section {
                    row("Model", device.model?.name ?? device.productName, isCode: false)
                    row("Identifier", device.model?.modelIdentifier)
                    row("Chip", device.model?.chip, isCode: false)
                    LabeledContent("State") {
                        StatusChip(text: device.state.label, tint: device.state.tint)
                    }
                }
                Section("Identity") {
                    row("Serial", device.serialNumber)
                    row("ECID", device.ecid)
                    row("Chip ID", device.cpid.map { String(format: "0x%04X", $0) })
                    row("Board ID", device.bdid.map { String(format: "0x%02X", $0) })
                    row("iBoot", device.iBootTag)
                    if device.isIntelT2 {
                        row("Restores as", device.model?.restoreIdentifier)
                    }
                }
                Section("USB") {
                    row("Device", device.usbID)
                    row("Location", String(format: "0x%08X", device.locationID))
                    if let port = engine.ports.first(where: { $0.rid == device.hostPortRID }) {
                        LabeledContent("Port") {
                            Label {
                                Text(port.title)
                            } icon: {
                                Image(systemName: port.symbol)
                            }
                            .font(.callout)
                        }
                    }
                }
                if let layout = device.model?.port {
                    Section("DFU Port") {
                        VStack(alignment: .leading, spacing: Metrics.tight) {
                            PortDiagram(layout: layout, tint: device.state.tint)
                                .frame(maxWidth: .infinity)
                            Text(layout.caption)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, Metrics.hairline)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        } else {
            ContentUnavailableView("No Mac Connected", systemImage: "cable.connector.slash")
        }
    }

    @ViewBuilder
    private func row(_ label: LocalizedStringKey, _ value: String?, isCode: Bool = true) -> some View {
        if let value, !value.isEmpty {
            LabeledContent(label) {
                CopyableValue(value: value, isCode: isCode)
            }
        }
    }
}

// MARK: - Activity

private struct ActivityList: View {
    @Environment(DiagnosticsEngine.self) private var engine

    var body: some View {
        VStack(spacing: 0) {
            if engine.log.isEmpty {
                ContentUnavailableView("No Activity", systemImage: "clock")
            } else {
                List(engine.log.reversed()) { entry in
                    ActivityRow(entry: entry)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }

            Divider()
            HStack {
                Button("Copy Report", systemImage: "doc.on.doc") {
                    engine.copyDiagnosticReport()
                }
                Spacer()
                Button("Clear", systemImage: "trash") {
                    engine.clearLog()
                }
                .disabled(engine.log.isEmpty)
            }
            .buttonStyle(.borderless)
            .labelStyle(.titleAndIcon)
            .font(.callout)
            .padding(Metrics.compact)
        }
    }
}

// MARK: - History

/// What was done on other days: every revive, restore and trip into DFU, newest first.
private struct HistoryList: View {
    @Environment(DiagnosticsEngine.self) private var engine
    @Environment(History.self) private var history
    @State private var isConfirmingClear = false

    var body: some View {
        VStack(spacing: 0) {
            if history.records.isEmpty {
                ContentUnavailableView {
                    Label("No History", systemImage: "clock.arrow.circlepath")
                } description: {
                    Text("Revives, restores and trips into DFU are kept here, on this Mac only.")
                }
            } else {
                List(history.records.reversed()) { record in
                    HistoryRow(record: record)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }

            Divider()
            HStack {
                Button("Export…", systemImage: "square.and.arrow.up") {
                    export()
                }
                Spacer()
                Button("Clear", systemImage: "trash") {
                    isConfirmingClear = true
                }
            }
            .disabled(history.records.isEmpty)
            .buttonStyle(.borderless)
            .labelStyle(.titleAndIcon)
            .font(.callout)
            .padding(Metrics.compact)
        }
        .confirmationDialog("Clear the history?", isPresented: $isConfirmingClear) {
            Button("Clear", role: .destructive) { history.clear() }
        } message: {
            Text("This can't be undone.")
        }
    }

    private func export() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "Mac DFU Studio history.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try history.csv().write(to: url, atomically: true, encoding: .utf8)
            engine.report(.success, "History exported.")
        } catch {
            engine.report(.failure, "The history couldn't be exported.", detail: error.localizedDescription)
        }
    }
}

private struct HistoryRow: View {
    let record: OperationRecord

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.tight) {
            Image(systemName: record.outcome.symbol)
                .font(.callout)
                .foregroundStyle(record.outcome.tint)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.kind.label)
                    .font(.callout.weight(.medium))
                Text(verbatim: record.device)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if let ecid = record.ecid {
                    Text(verbatim: ecid)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                HStack(spacing: 6) {
                    Text(record.date, format: .dateTime.day().month().year().hour().minute())
                    if record.duration >= 1 {
                        Text(verbatim: "·")
                        Text(Duration.seconds(record.duration.rounded()), format: .units(allowed: [.hours, .minutes, .seconds], width: .narrow))
                    }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

private struct ActivityRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.tight) {
            Image(systemName: entry.level.symbol)
                .font(entry.level == .info ? .system(size: 6) : .callout)
                .foregroundStyle(entry.level.tint)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.message)
                    .font(.callout)
                if let detail = entry.detail {
                    Text(verbatim: detail)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                        .textSelection(.enabled)
                }
                Text(entry.date, format: .dateTime.hour().minute().second())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
