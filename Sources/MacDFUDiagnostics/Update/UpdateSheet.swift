import SwiftUI

/// Offers a new version and installs it. Updates are required, so the only ways out are to install it
/// or — if that turns out to be impossible — to carry on and be asked again next time.
struct UpdateSheet: View {
    let release: AppRelease

    @Environment(UpdateManager.self) private var updater
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: Metrics.standard) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 76, height: 76)
                .accessibilityHidden(true)

            VStack(spacing: Metrics.hairline) {
                Text("Version \(release.version) is ready")
                    .font(.title2.weight(.semibold))
                Text("You have \(updater.currentVersion).")
                    .foregroundStyle(.secondary)
            }

            if !release.notes.isEmpty {
                ScrollView {
                    Text(Self.formatted(release.notes))
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Metrics.compact)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 170)
                .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: Metrics.insetRadius))
            }

            controls
                .frame(minHeight: 54)
        }
        .padding(Metrics.roomy)
        .frame(width: 440)
        .interactiveDismissDisabled()
        .animation(.smooth, value: updater.state)
    }

    @ViewBuilder
    private var controls: some View {
        switch updater.state {
        case .downloading(_, let progress):
            VStack(spacing: Metrics.tight) {
                ProgressView(value: progress)
                Text("Downloading…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        case .installing:
            VStack(spacing: Metrics.tight) {
                ProgressView()
                    .controlSize(.small)
                Text("Checking the signature and installing…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        case .failed(_, let message):
            VStack(spacing: Metrics.compact) {
                Label {
                    Text(verbatim: message)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Button("Not Now") { updater.continueWithoutUpdating() }
                    Button("Download Manually") { openURL(release.pageURL) }
                    Button("Try Again") { Task { await updater.installPendingUpdate() } }
                        .keyboardShortcut(.defaultAction)
                }
            }
        default:
            Button {
                Task { await updater.installPendingUpdate() }
            } label: {
                Text("Update and Relaunch")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.extraLarge)
            .primaryActionStyle()
            .keyboardShortcut(.defaultAction)
        }
    }

    /// Release notes are written in Markdown. Inline formatting is rendered; headings and bullets, which
    /// the inline parser leaves as raw `###` and `-`, are turned into bold lines and bullet points.
    nonisolated static func formatted(_ notes: String) -> AttributedString {
        let lines = notes.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
            let text = line.trimmingCharacters(in: .whitespaces)
            if let heading = text.firstMatch(of: /^#{1,6}\s+(.+)$/) {
                return "**\(heading.1.replacing("**", with: ""))**"
            }
            if let bullet = text.firstMatch(of: /^[-*]\s+(.+)$/) {
                return "•\u{00A0}\(bullet.1)"
            }
            if let quote = text.firstMatch(of: /^>\s*(.*)$/) {
                return String(quote.1)
            }
            return String(line)
        }
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        let prepared = lines.joined(separator: "\n")
        return (try? AttributedString(markdown: prepared, options: options)) ?? AttributedString(notes)
    }
}
