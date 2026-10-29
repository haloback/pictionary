import AppKit
import SwiftUI

/// One accent (printer's vermilion), neutral grays everywhere else, so the user's cover
/// is always the most colorful thing on screen.
enum Theme {
    static let accent = Color(red: 0.894, green: 0.341, blue: 0.180)

    static let canvasBackdrop = Color(nsColor: NSColor(name: nil) { ap in
        ap.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 0.085, alpha: 1) : NSColor(white: 0.84, alpha: 1)
    })

    static let panel = Color(nsColor: .windowBackgroundColor)
    static let hairline = Color.primary.opacity(0.08)
    static let radius: CGFloat = 8
}

/// A small titled group used across inspectors.
struct PanelSection<Content: View>: View {
    let title: String
    var trailing: AnyView?
    @ViewBuilder var content: Content

    init(_ title: String, trailing: AnyView? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.trailing = trailing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let trailing { trailing }
            }
            content
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline).frame(height: 1) }
    }
}

/// Label + control in one aligned row.
struct FieldRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 74, alignment: .leading)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Slider with its value shown, for precise but quick adjustments.
struct ValueSlider: View {
    let label: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var format: (Double) -> String = { String(format: "%.0f%%", $0 * 100) }

    var body: some View {
        FieldRow(label) {
            HStack(spacing: 8) {
                Slider(value: $value, in: range)
                    .controlSize(.small)
                Text(format(value))
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 42, alignment: .trailing)
            }
        }
    }
}

struct Swatch: View {
    let color: RGBA
    var size: CGFloat = 22
    var selected = false

    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(color.color)
            .frame(width: size, height: size)
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.primary.opacity(selected ? 0.9 : 0.15), lineWidth: selected ? 2 : 1))
            .help(color.hex)
    }
}

/// Bridges an RGBA binding to SwiftUI's ColorPicker.
struct RGBAPicker: View {
    let label: String
    @Binding var color: RGBA
    var supportsOpacity = true

    var body: some View {
        FieldRow(label) {
            HStack(spacing: 8) {
                ColorPicker("", selection: Binding(get: { color.color }, set: { color = RGBA(color: $0) }), supportsOpacity: supportsOpacity)
                    .labelsHidden()
                Text(color.hex)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }
}

struct Toast: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.hairline))
            .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
    }
}
