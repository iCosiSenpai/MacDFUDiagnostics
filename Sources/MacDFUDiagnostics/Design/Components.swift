import SwiftUI

/// A small coloured pill: a dot or symbol and one or two words.
struct StatusChip: View {
    let text: LocalizedStringResource
    var tint: Color = .secondary
    var symbol: String?

    var body: some View {
        HStack(spacing: 6) {
            if let symbol {
                Image(systemName: symbol)
                    .imageScale(.small)
            } else {
                Circle()
                    .frame(width: 7, height: 7)
            }
            Text(text)
        }
        .font(.callout.weight(.medium))
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(tint.opacity(0.14), in: .capsule)
        .accessibilityElement(children: .combine)
    }
}

/// A circular progress ring that turns into a spinner when no fraction is known.
struct ProgressRing: View {
    let progress: Double?
    var tint: Color = .accentColor
    var lineWidth: CGFloat = 4

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.18), lineWidth: lineWidth)
            if let progress {
                Circle()
                    .trim(from: 0, to: max(0.02, min(progress, 1)))
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth, value: progress)
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue(progress.map { Text($0, format: .percent.precision(.fractionLength(0))) } ?? Text("Working"))
    }
}

/// A value the user may want to copy: selectable, monospaced, with a Copy command.
struct CopyableValue: View {
    let value: String
    /// Identifiers and addresses are set in a fixed-width face; names are not.
    var isCode = true

    var body: some View {
        Text(verbatim: value)
            .font(isCode ? .callout.monospaced() : .callout)
            .textSelection(.enabled)
            .multilineTextAlignment(.trailing)
            .contextMenu {
                Button("Copy", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value, forType: .string)
                }
            }
    }
}
