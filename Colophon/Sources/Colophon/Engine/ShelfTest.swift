import CoreGraphics
import CoreText
import Foundation

/// Puts the cover on a shelf of other books in its genre, the way a shopper sees it in search results,
/// and measures whether it stands out: color against its neighbors, a title that still reads at
/// 120 px, type that keeps its contrast, and a picture that is neither flat nor a riot.
enum ShelfTest {
    struct Result {
        /// The shelf: an Amazon-like results grid with the cover among its neighbors.
        var grid: CGImage
        /// 0...100: how much the cover stands out on this shelf.
        var standout: Double
        /// Short sentences on what helps and what hurts.
        var notes: [String]
        /// The Signature designs on the shelf, in grid order (the cover's own slot is left out).
        var neighbors: [String]
        /// The cover's slot in the grid, row-major.
        var position: Int
    }

    static let defaultCell = CGSize(width: 120, height: 192)
    static let gap: CGFloat = 16
    static let captionHeight: CGFloat = 30

    /// Renders the cover and `columns × rows − 1` Signature designs of the same genre (their sample books,
    /// painted stand-ins since they have no photo), places the cover at a seeded random slot, and scores it.
    /// Same seed, same shelf.
    static func run(_ doc: CoverDocument, columns: Int = 4, rows: Int = 3, cell: CGSize = ShelfTest.defaultCell, seed: Int = 1) -> Result? {
        let cols = max(1, columns), rws = max(1, rows)
        let count = cols * rws
        guard count >= 1 else { return nil }
        var rng = SeededRNG(seed: seed)
        let position = rng.int(count)

        // The neighbors: designs of the genre, shuffled by the seed, padded from the whole collection.
        let designs = pickDesigns(genre: doc.book.genre, count: count - 1, rng: &rng)
        var thumbs: [CGImage?] = []
        var names: [String] = []
        for d in designs {
            let sample = SignatureLibrary.sampleDocument(d)
            let built = SignatureLibrary.build(d, palette: 0, base: sample)
            thumbs.append(thumbnail(built, cell: cell))
            names.append(d.name)
        }
        guard let mine = thumbnail(doc, cell: cell) else { return nil }

        // Lay the shelf out.
        var slots: [CGImage?] = []
        var k = 0
        for i in 0..<count {
            if i == position { slots.append(mine) } else { slots.append(k < thumbs.count ? thumbs[k] : nil); k += 1 }
        }
        guard let grid = drawShelf(slots, columns: cols, rows: rws, cell: cell) else { return nil }

        // Measure.
        var notes: [String] = []
        var neighborImages: [CGImage] = []
        for i in neighborSlots(of: position, columns: cols, rows: rws) { if let t = slots[i] { neighborImages.append(t) } }
        let color = colorScore(mine, neighbors: neighborImages, notes: &notes)
        let cap = capHeightScore(doc, cell: cell, notes: &notes)
        let contrast = contrastScore(doc, notes: &notes)
        let busy = busynessScore(mine, notes: &notes)
        var standout = 100 * (0.35 * color + 0.3 * cap + 0.2 * contrast + 0.15 * busy)
        standout = max(0, min(100, standout))
        if notes.isEmpty { notes.append("The cover holds its own on this shelf.") }
        return Result(grid: grid, standout: standout, notes: notes, neighbors: names, position: position)
    }

    // MARK: Shelf

    /// Designs of the genre first (shuffled by the seed), then others, until there are `count`.
    static func pickDesigns(genre: Genre, count: Int, rng: inout SeededRNG) -> [SignatureDesign] {
        guard count > 0 else { return [] }
        var same = SignatureLibrary.all.filter { $0.genre == genre }
        var others = SignatureLibrary.all.filter { $0.genre != genre }
        shuffle(&same, &rng)
        shuffle(&others, &rng)
        var out: [SignatureDesign] = []
        for d in same where out.count < count { out.append(d) }
        for d in others where out.count < count { out.append(d) }
        return out
    }

    private static func shuffle<T>(_ a: inout [T], _ rng: inout SeededRNG) {
        guard a.count > 1 else { return }
        for i in stride(from: a.count - 1, to: 0, by: -1) {
            let j = rng.int(i + 1)
            if i != j { a.swapAt(i, j) }
        }
    }

    /// The cover at thumbnail size, fitted inside the cell by its own aspect.
    static func thumbnail(_ doc: CoverDocument, cell: CGSize) -> CGImage? {
        let aspect = CGFloat(doc.canvas.aspect)
        var w = cell.width, h = (cell.width * aspect).rounded()
        if h > cell.height { h = cell.height; w = (cell.height / aspect).rounded() }
        return CoverRenderer.shared.render(doc, size: CGSize(width: max(8, w), height: max(8, h)), quality: .preview)
    }

    /// Row-major indices of the up-to-eight cells around a slot.
    static func neighborSlots(of position: Int, columns: Int, rows: Int) -> [Int] {
        let r = position / columns, c = position % columns
        var out: [Int] = []
        for dr in -1...1 {
            for dc in -1...1 where !(dr == 0 && dc == 0) {
                let rr = r + dr, cc = c + dc
                if rr >= 0, rr < rows, cc >= 0, cc < columns { out.append(rr * columns + cc) }
            }
        }
        return out
    }

    /// A white results page: covers on a faint card, with gray caption bars standing in for title, author and stars.
    static func drawShelf(_ slots: [CGImage?], columns: Int, rows: Int, cell: CGSize) -> CGImage? {
        let W = CGFloat(columns) * cell.width + CGFloat(columns + 1) * gap
        let H = CGFloat(rows) * (cell.height + captionHeight) + CGFloat(rows + 1) * gap
        guard let ctx = Gfx.context(Int(W), Int(H)) else { return nil }
        // Top-left origin, like the grid.
        ctx.translateBy(x: 0, y: H)
        ctx.scaleBy(x: 1, y: -1)
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
        for i in 0..<(columns * rows) {
            let r = i / columns, c = i % columns
            let x = gap + CGFloat(c) * (cell.width + gap)
            let y = gap + CGFloat(r) * (cell.height + captionHeight + gap)
            let slot = CGRect(x: x, y: y, width: cell.width, height: cell.height)
            ctx.setFillColor(CGColor(srgbRed: 0.965, green: 0.965, blue: 0.965, alpha: 1))
            ctx.fill(slot)
            if let img = slots[i] {
                let iw = CGFloat(img.width), ih = CGFloat(img.height)
                let s = min(cell.width / iw, cell.height / ih)
                let dw = (iw * s).rounded(), dh = (ih * s).rounded()
                let dr = CGRect(x: x + ((cell.width - dw) / 2).rounded(), y: y + cell.height - dh, width: dw, height: dh)
                ctx.setShadow(offset: CGSize(width: 0, height: 1.5), blur: 4, color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.25))
                Gfx.drawUpright(img, in: dr, ctx)
                ctx.setShadow(offset: .zero, blur: 0, color: nil)
            }
            // Caption bars: a title line, an author line, a short row of "stars".
            let cy = y + cell.height + 6
            ctx.setFillColor(CGColor(srgbRed: 0.42, green: 0.42, blue: 0.42, alpha: 1))
            ctx.fill(CGRect(x: x, y: cy, width: cell.width * 0.78, height: 5))
            ctx.setFillColor(CGColor(srgbRed: 0.7, green: 0.7, blue: 0.7, alpha: 1))
            ctx.fill(CGRect(x: x, y: cy + 9, width: cell.width * 0.5, height: 4))
            ctx.setFillColor(CGColor(srgbRed: 0.93, green: 0.65, blue: 0.2, alpha: 1))
            ctx.fill(CGRect(x: x, y: cy + 17, width: cell.width * 0.3, height: 4))
        }
        return ctx.makeImage()
    }

    // MARK: Scores

    static func isWarm(_ c: RGBA) -> Bool {
        guard c.chroma > 0.08 else { return false }
        let h = c.hsl.h
        return h < 70 || h > 300
    }

    static func isCool(_ c: RGBA) -> Bool {
        guard c.chroma > 0.08 else { return false }
        let h = c.hsl.h
        return h >= 160 && h <= 270
    }

    /// Mean-color distance (CIE76) and dominant-hue distance against the neighbors, 0...1.
    static func colorScore(_ mine: CGImage, neighbors: [CGImage], notes: inout [String]) -> Double {
        guard !neighbors.isEmpty else { return 0.6 }
        let myMean = PixelSampler.stats(mine, region: .full).mean
        let myDominant = PaletteExtractor.extract(mine, k: 3).first ?? myMean
        var meanSum = 0.0, hueSum = 0.0
        var close = 0, warmNeighbors = 0, coolNeighbors = 0
        for n in neighbors {
            let m = PixelSampler.stats(n, region: .full).mean
            let d = PaletteExtractor.extract(n, k: 3).first ?? m
            let de = myMean.distance(to: m)
            meanSum += de
            hueSum += (myDominant.chroma > 0.08 && d.chroma > 0.08) ? Harmonizer.hueDistance(myDominant, d) : 40
            if de < 12 { close += 1 }
            if isWarm(m) { warmNeighbors += 1 }
            if isCool(m) { coolNeighbors += 1 }
        }
        let n = Double(neighbors.count)
        let meanNorm = min(1, meanSum / n / 40)
        let hueNorm = min(1, hueSum / n / 90)
        let score = 0.6 * meanNorm + 0.4 * hueNorm
        if isWarm(myMean) && warmNeighbors == 0 {
            notes.append("Your cover is the only warm one on the shelf.")
        } else if isCool(myMean) && coolNeighbors == 0 {
            notes.append("Your cover is the only cool one on the shelf.")
        } else if close >= 2 {
            notes.append("Your cover blends in: \(close) of its neighbors share its colors.")
        } else if score < 0.35 {
            notes.append("The cover's colors sit close to the books around it.")
        } else if score > 0.7 {
            notes.append("The cover's colors separate it clearly from its neighbors.")
        }
        return score
    }

    /// The title's capital height when the cover is `cell` wide: 7 px or more reads in search results.
    static func capHeightScore(_ doc: CoverDocument, cell: CGSize, notes: inout [String]) -> Double {
        guard let title = doc.textLayer(role: .title), let t = title.textContent, title.isVisible else {
            notes.append("There is no title on the cover.")
            return 0
        }
        let aspect = CGFloat(doc.canvas.aspect)
        var w = cell.width, h = cell.width * aspect
        if h > cell.height { h = cell.height; w = cell.height / aspect }
        let box = title.frame.pixels(in: CGSize(width: w, height: h))
        let size = Double(TextRenderer.resolvedSize(t, box: box.size, canvasHeight: h))
        let cap = size * 0.7
        let px = Int(cap.rounded())
        let width = Int(cell.width)
        if cap < 7 {
            notes.append("At \(width) px the title is \(px) px tall; it will not be read.")
        } else if cap < 10 {
            notes.append("At \(width) px the title's capitals stand \(px) px tall: just readable.")
        } else {
            notes.append("At \(width) px the title's capitals stand \(px) px tall: it reads in search results.")
        }
        return min(1, cap / 7)
    }

    /// 1 when the critic finds the title legible, less for a warning, 0 for a fail.
    static func contrastScore(_ doc: CoverDocument, notes: inout [String]) -> Double {
        guard let title = doc.textLayer(role: .title) else { return 0 }
        let report = Critic.review(doc)
        let issue = report.issues.first { $0.kind == .legibility && $0.layerID == title.id }
        guard let issue else { return 1 }
        if issue.severity == .fail {
            notes.append("The title loses its contrast against what's behind it.")
            return 0
        }
        notes.append("The title's contrast is marginal; a shopper's glance may slide off it.")
        return 0.5
    }

    /// Luminance spread of the thumbnail: around 0.18 is lively; near 0 is flat, past 0.3 is noise.
    static func busynessScore(_ mine: CGImage, notes: inout [String]) -> Double {
        let b = PixelSampler.stats(mine, region: .full).busyness
        if b < 0.06 {
            notes.append("The cover is nearly flat at thumbnail size; one strong shape would help.")
        } else if b > 0.3 {
            notes.append("At thumbnail size the cover turns to noise; quieter areas would help the type.")
        }
        return max(0, 1 - abs(b - 0.18) / 0.18)
    }
}
