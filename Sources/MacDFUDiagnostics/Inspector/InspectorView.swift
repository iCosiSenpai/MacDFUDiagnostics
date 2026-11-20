import SwiftUI

/// The trailing panel: who the connected Mac is, and what has happened so far.
struct InspectorView: View {
    @Environment(Navigation.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation

        VStack(spacing: 0) {
            Picker("View", selection: $navigation.inspectorTab) {
                Text("Device").tag(InspectorTab.device)
                Text("Activity").tag(InspectorTab.activity)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(Metrics.compact)

            switch navigation.inspectorTab {
            case .device: DeviceDetails()
            case .activity: ActivityList()
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
                    row("Port", engine.ports.first { $0.rid == device.hostPortRID }?.displayName)
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
