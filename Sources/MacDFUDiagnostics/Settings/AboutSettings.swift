import SwiftUI

/// Settings › About: what this is, which copy is running, where to find more, and how to support it.
struct AboutSettings: View {
    @Environment(DiagnosticsEngine.self) private var engine
    @Environment(UpdateManager.self) private var updater
    @State private var hasCopied = false

    var body: some View {
        Form {
            Section {
                HStack(spacing: Metrics.standard) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .frame(width: 72, height: 72)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: "Mac DFU Studio")
                            .font(.title2.weight(.semibold))
                        Text("Version \(updater.currentVersion) (\(updater.currentBuild))")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Text("Put a Mac into DFU with one click. Revive it, restore it, or read its disk.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, Metrics.hairline)
            }

            Section("This copy") {
                LabeledContent("Signature") {
                    if CodeTrust.runningAppIsReleaseBuild {
                        Label("Developer ID, notarized by Apple", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        Text("Development build").foregroundStyle(.secondary)
                    }
                }
                LabeledContent("This Mac") { Text(verbatim: engine.host.name) }
                LabeledContent("Chip") { Text(verbatim: Self.chip) }
                LabeledContent("macOS") { Text(verbatim: Self.system) }
                LabeledContent("Apple Configurator") {
                    Text(engine.cfgutilPath == nil ? "Not installed" : "Installed")
                }
                Button(hasCopied ? "Copied" : "Copy Details", systemImage: hasCopied ? "checkmark" : "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(details, forType: .string)
                    hasCopied = true
                }
            }

            Section("Support the project") {
                Text("Mac DFU Studio is free, with no account and nothing sent anywhere. If it saved you a trip to a repair shop, a donation keeps it going.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Metrics.compact) {
                    Link(destination: Links.payPal) {
                        Label("Donate with PayPal", systemImage: "heart.fill")
                    }
                    Link(destination: Links.buyMeACoffee) {
                        Label("Buy Me a Coffee", systemImage: "cup.and.saucer.fill")
                    }
                }
                .buttonStyle(.bordered)
            }

            Section {
                link("Website", "globe", Links.website)
                link("Source Code on GitHub", "chevron.left.forwardslash.chevron.right", Links.project)
                link("Report a Problem", "exclamationmark.bubble", Links.issues)
                link("License", "doc.text", Links.license)
                link("Acknowledgements", "person.2", Links.acknowledgements)
                link("Apple: Revive or Restore a Mac", "apple.logo", Links.reviveGuide)
            } header: {
                Text("More")
            } footer: {
                Text("© 2026 Alessio Cosi (iCosiSenpai). Independent software, not affiliated with Apple Inc.")
            }
        }
        // Longer than a 13-inch screen is tall if left to size itself: it scrolls instead.
        .frame(height: 560)
    }

    private func link(_ title: LocalizedStringKey, _ symbol: String, _ url: URL) -> some View {
        Link(destination: url) {
            HStack {
                Label(title, systemImage: symbol)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    /// The same facts as text, for a support request. In English, like the diagnostic report.
    private var details: String {
        [
            "Mac DFU Studio \(updater.currentVersion) (\(updater.currentBuild))",
            "Signature: \(CodeTrust.runningAppIsReleaseBuild ? "Developer ID" : "development build")",
            "Host: \(engine.host.name) [\(engine.host.board)]",
            "Chip: \(Self.chip)",
            "macOS: \(Self.system)",
            "Apple Configurator: \(engine.cfgutilPath == nil ? "not installed" : "installed")",
        ].joined(separator: "\n")
    }

    private static let system = ProcessInfo.processInfo.operatingSystemVersionString

    private static let chip: String = {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        guard size > 0 else { return "—" }
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0)
        return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }()
}
