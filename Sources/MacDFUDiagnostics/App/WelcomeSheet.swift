import SwiftUI

/// Shown once, the first time the app opens: what it needs, and the one consent macOS asks for.
///
/// Sending a command asks for an administrator password every time, and that is the system's own
/// prompt, not something to grant in advance. The only permission to give here is notifications,
/// and Continue asks for it.
struct WelcomeSheet: View {
    @Environment(Readiness.self) private var readiness
    @Environment(Preferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Metrics.standard) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 84, height: 84)
                .accessibilityHidden(true)

            VStack(spacing: Metrics.hairline) {
                Text("Welcome to Mac DFU Studio")
                    .font(.title2.weight(.semibold))
                Text("A quick check of what it needs on this Mac.")
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)

            Form {
                ReadinessList()
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .scrollContentBackground(.hidden)
            .fixedSize(horizontal: false, vertical: true)

            Text("You can see this list again in Settings › Advanced.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button {
                Task {
                    // The system's prompt appears here, once, if it has never been answered.
                    if readiness.notifications == .notAsked {
                        await readiness.requestNotifications()
                    }
                    preferences.hasSeenWelcome = true
                    dismiss()
                }
            } label: {
                Text("Continue")
                    .frame(maxWidth: 220)
            }
            .primaryActionStyle()
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(Metrics.roomy)
        .frame(width: 480)
        .interactiveDismissDisabled()
        .task { await readiness.refresh() }
    }
}
