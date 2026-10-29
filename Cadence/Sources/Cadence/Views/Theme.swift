import AppKit
import SwiftUI

enum Theme {
    static let accent = Color(red: 0.31, green: 0.27, blue: 0.90)        // indigo
    static let record = Color(red: 0.90, green: 0.28, blue: 0.30)
    static let positive = Color(red: 0.06, green: 0.62, blue: 0.48)

    static let canvas = Color(nsColor: NSColor(name: nil) { a in
        a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(red: 0.055, green: 0.059, blue: 0.071, alpha: 1)
            : NSColor(red: 0.961, green: 0.965, blue: 0.973, alpha: 1)
    })
    static let card = Color(nsColor: NSColor(name: nil) { a in
        a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(red: 0.086, green: 0.094, blue: 0.114, alpha: 1) : .white
    })
    static let raised = Color(nsColor: NSColor(name: nil) { a in
        a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(red: 0.12, green: 0.13, blue: 0.16, alpha: 1)
            : NSColor(red: 0.945, green: 0.949, blue: 0.996, alpha: 1)
    })
    static let ink = Color(nsColor: NSColor(name: nil) { a in
        a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(red: 0.91, green: 0.92, blue: 0.93, alpha: 1)
            : NSColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1)
    })
    static let stroke = Color.primary.opacity(0.10)

    /// Layer colors. Index 0 is always your own takes.
    static let trackColors: [Color] = [
        accent,
        Color(red: 0.85, green: 0.47, blue: 0.02),   // amber
        Color(red: 0.06, green: 0.62, blue: 0.48),   // teal
        Color(red: 0.90, green: 0.28, blue: 0.30),   // red
        Color(red: 0.55, green: 0.36, blue: 0.96),   // violet
        Color(red: 0.15, green: 0.39, blue: 0.92),   // blue
        Color(red: 0.86, green: 0.15, blue: 0.47),   // pink
        Color(red: 0.40, green: 0.64, blue: 0.05),   // lime
    ]

    static func track(_ i: Int) -> Color { trackColors[((i % trackColors.count) + trackColors.count) % trackColors.count] }
}

@MainActor
struct Card<Content: View>: View {
    var padding: CGFloat = 22
    var dark = false
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        let base = content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(dark ? Color(red: 0.08, green: 0.09, blue: 0.11) : Theme.card, in: shape)
            .overlay(shape.strokeBorder(Theme.stroke))
        if dark {
            base.environment(\.colorScheme, .dark)
        } else {
            base
        }
    }
}

@MainActor
struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(0.9)
            .foregroundStyle(.secondary)
    }
}

struct PillButtonStyle: ButtonStyle {
    var selected = false
    var tint: Color = Theme.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 14)
            .frame(minHeight: 34)
            .foregroundStyle(selected ? Color.white : Theme.ink)
            .background(selected ? tint : Theme.card, in: Capsule())
            .overlay(Capsule().strokeBorder(selected ? Color.clear : Theme.stroke))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(Capsule())
    }
}
