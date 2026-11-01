import CoreGraphics
import Foundation

/// Decoration drawn with a line of text: flanking rules for "— A NOVEL —", a box, a band behind it...
enum TextFlourish: String, Codable, CaseIterable, Identifiable {
    case none, rules, dots, diamonds, box, band, underline, brackets

    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "None"
        case .rules: return "Flanking Rules"
        case .dots: return "Dots"
        case .diamonds: return "Diamonds & Rules"
        case .box: return "Box"
        case .band: return "Band Behind"
        case .underline: return "Underline"
        case .brackets: return "Corner Brackets"
        }
    }

    /// Room the decoration needs beside the text (fraction of the box width kept for the type).
    var textWidthShare: CGFloat {
        switch self {
        case .rules, .diamonds: return 0.6
        case .dots, .brackets, .box: return 0.78
        case .band: return 0.86
        default: return 1
        }
    }

    var textHeightShare: CGFloat {
        switch self {
        case .box, .band, .brackets: return 0.62
        case .underline: return 0.8
        default: return 1
        }
    }

    /// Draws the decoration around the text block `text` (CG coordinates) inside `box`.
    func draw(in ctx: CGContext, text: CGRect, box: CGRect, size: CGFloat, color: RGBA, bandColor: RGBA) {
        guard self != .none else { return }
        let lw: CGFloat = max(1, size * 0.06)
        let gap: CGFloat = size * 0.45
        let midY: CGFloat = text.midY
        ctx.saveGState()
        ctx.setStrokeColor(color.cgColor)
        ctx.setFillColor(color.cgColor)
        ctx.setLineWidth(lw)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        switch self {
        case .none:
            break
        case .rules, .diamonds:
            let leftEnd: CGFloat = text.minX - gap, rightStart: CGFloat = text.maxX + gap
            let leftStart: CGFloat = max(box.minX, text.minX - box.width * 0.3)
            let rightEnd: CGFloat = min(box.maxX, text.maxX + box.width * 0.3)
            if leftEnd - leftStart > lw * 2 {
                ctx.move(to: CGPoint(x: leftStart, y: midY)); ctx.addLine(to: CGPoint(x: leftEnd, y: midY))
            }
            if rightEnd - rightStart > lw * 2 {
                ctx.move(to: CGPoint(x: rightStart, y: midY)); ctx.addLine(to: CGPoint(x: rightEnd, y: midY))
            }
            ctx.strokePath()
            if self == .diamonds {
                let r: CGFloat = size * 0.16
                for x in [leftEnd + r * 0.2, rightStart - r * 0.2, leftStart, rightEnd] {
                    ctx.move(to: CGPoint(x: x, y: midY + r)); ctx.addLine(to: CGPoint(x: x + r, y: midY))
                    ctx.addLine(to: CGPoint(x: x, y: midY - r)); ctx.addLine(to: CGPoint(x: x - r, y: midY))
                    ctx.closePath()
                }
                ctx.fillPath()
            }
        case .dots:
            let r: CGFloat = size * 0.1
            for x in [text.minX - gap, text.maxX + gap] {
                ctx.fillEllipse(in: CGRect(x: x - r, y: midY - r, width: 2 * r, height: 2 * r))
            }
        case .box:
            let rect = text.insetBy(dx: -size * 0.5, dy: -size * 0.32)
            ctx.stroke(rect.insetBy(dx: lw / 2, dy: lw / 2))
        case .band:
            let rect = CGRect(x: box.minX, y: text.minY - size * 0.3, width: box.width, height: text.height + size * 0.6)
            ctx.setFillColor(bandColor.cgColor)
            ctx.fill(rect)
        case .underline:
            let y: CGFloat = text.minY - size * 0.18
            ctx.move(to: CGPoint(x: text.minX, y: y)); ctx.addLine(to: CGPoint(x: text.maxX, y: y))
            ctx.strokePath()
        case .brackets:
            let rect = text.insetBy(dx: -size * 0.45, dy: -size * 0.3)
            let arm: CGFloat = min(rect.width, rect.height) * 0.35
            let corners: [(CGPoint, CGFloat, CGFloat)] = [(CGPoint(x: rect.minX, y: rect.minY), 1, 1), (CGPoint(x: rect.maxX, y: rect.minY), -1, 1),
                                                         (CGPoint(x: rect.minX, y: rect.maxY), 1, -1), (CGPoint(x: rect.maxX, y: rect.maxY), -1, -1)]
            for (p, sx, sy) in corners {
                ctx.move(to: CGPoint(x: p.x + sx * arm, y: p.y)); ctx.addLine(to: p); ctx.addLine(to: CGPoint(x: p.x, y: p.y + sy * arm))
            }
            ctx.strokePath()
        }
        ctx.restoreGState()
    }
}

/// Subtitle, tagline and series lines: where they go and how they look when the brief gains one.
enum SupportingText {
    static let roles: [TextRole] = [.subtitle, .tagline, .series]

    static func text(_ role: TextRole, _ b: BookInfo) -> String {
        switch role {
        case .subtitle: return b.subtitle
        case .tagline: return b.tagline
        case .series: return b.series
        default: return ""
        }
    }

    /// Adds any supporting line the brief has but the cover lacks, in free space around the title.
    static func ensureAll(_ d: inout CoverDocument) {
        for role in roles { ensure(role, in: &d) }
    }

    static func ensure(_ role: TextRole, in d: inout CoverDocument) {
        let value = text(role, d.book).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, d.textLayer(role: role) == nil else { return }
        let f = frame(for: role, in: d)
        let author = d.textLayer(role: .author)?.textContent
        let title = d.textLayer(role: .title)?.textContent
        let font = author?.fontName ?? title?.fontName ?? "Didot"
        let color = (author?.color ?? title?.color ?? .nearWhite).withAlpha(0.94)
        var l = Layer.text(value, role: role, frame: f, font: font, color: color)
        l.name = role.label
        switch role {
        case .tagline:
            l.textContent?.letterCase = .asTyped
            l.textContent?.tracking = 0.04
        case .series:
            l.textContent?.letterCase = .upper
            l.textContent?.tracking = 0.3
            l.textContent?.flourish = .rules
        default:
            l.textContent?.letterCase = .asTyped
            l.textContent?.tracking = 0.06
        }
        l.textContent?.alignment = .center
        // Above the scrims and photos, just under the title in the stack.
        let ti = d.layers.lastIndex { $0.textContent?.role == .title } ?? d.layers.count
        d.layers.insert(l, at: ti)
    }

    /// Free horizontal band near the title for a supporting line.
    static func frame(for role: TextRole, in d: CoverDocument) -> NRect {
        let t = d.textLayer(role: .title)?.frame ?? NRect(0.1, 0.12, 0.8, 0.3)
        let a = d.textLayer(role: .author)?.frame ?? NRect(0.1, 0.88, 0.8, 0.05)
        let x = max(0.06, t.x), w = min(0.88, t.w)
        func clear(_ r: NRect) -> Bool {
            r.y > 0.015 && r.maxY < 0.985 && d.layers.allSatisfy { l in
                guard l.textContent != nil, l.isVisible else { return true }
                return l.frame.intersectionArea(r) < r.w * r.h * 0.15
            }
        }
        let h: Double = role == .subtitle ? 0.036 : 0.03
        var candidates: [NRect] = []
        switch role {
        case .subtitle:
            candidates = [NRect(x, t.maxY + 0.012, w, h), NRect(x, t.y - h - 0.012, w, h), NRect(x, a.y - h - 0.02, w, h)]
        case .tagline:
            candidates = [NRect(0.12, 0.035, 0.76, h), NRect(0.12, a.y - h - 0.025, 0.76, h), NRect(x, t.maxY + 0.05, w, h)]
        default:
            candidates = [NRect(0.2, t.y - h - 0.015, 0.6, h), NRect(0.2, 0.03, 0.6, h), NRect(0.2, t.maxY + 0.012, 0.6, h)]
        }
        return candidates.first(where: clear) ?? candidates[0]
    }
}
