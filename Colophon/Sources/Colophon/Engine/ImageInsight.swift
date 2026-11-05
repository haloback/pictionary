import CoreGraphics
import Foundation

/// What the engine knows about a photo: where the faces and the subject are, how bright and
/// busy it is overall and per region, and which colors it is made of. Layout code uses it to
/// pick where type goes, which way to crop and what color the type should be.
struct ImageInsight {
    static let columns = 3
    static let rows = 4

    /// Face rectangles, normalized with a top-left origin, largest first.
    var faces: [NRect] = []
    /// The salient region (or the golden center when Vision finds nothing).
    var focus: NRect = NRect(0.25, 0.25, 0.5, 0.5)
    var palette: [RGBA] = []
    /// The average color of the whole image.
    var meanColor: RGBA = RGBA(0.5, 0.5, 0.5)
    /// A clear face, or a tall centered subject.
    var isPortrait: Bool = false
    /// Mean relative luminance, 0...1.
    var brightness: Double = 0.5
    /// Standard deviation of luminance over the whole image. Above ~0.18 reads as busy.
    var busyness: Double = 0
    /// Mean luminance of each cell of a 3x4 grid (3 columns, 4 rows), row-major from the top-left.
    var darkRegions: [Double] = Array(repeating: 0.5, count: 12)
    /// Luminance std-dev of each cell of the same grid.
    var quietRegions: [Double] = Array(repeating: 0, count: 12)
    /// Vision's overall aesthetics score, −1 (poor) ... 1 (great). nil when unavailable (macOS < 15).
    var aesthetic: Double? = nil
    /// Vision thinks this is a screenshot, scan or document rather than a photograph.
    var isUtility = false
    /// Printed text found in the photo, normalized top-left.
    var textRegions: [NRect] = []
    /// Scene labels from Vision ("outdoor", "cat"), most confident first.
    var labels: [String] = []

    /// A whole-image insight with nothing detected, for layers whose photo is missing.
    static let empty = ImageInsight()

    /// One line a person would want to hear about the photo, or nil when it is fine.
    var photoNote: String? {
        if isUtility {
            return "This picture looks like a screenshot or document, not a cover photo."
        }
        if let a = aesthetic, a < -0.35 {
            let shown = String(format: "%.2f", a)
            return "This photo is weak on its own (aesthetics score \(shown)); the design will have to carry it."
        }
        if !textRegions.isEmpty {
            return "Words in the photo: keep the title off them."
        }
        return nil
    }

    /// Whether any detected text overlaps a normalized photo rect by more than `fraction` of the rect.
    func textOverlaps(_ r: NRect, fraction: Double = 0.05) -> Bool {
        guard r.area > 0 else { return false }
        var covered = 0.0
        for t in textRegions { covered += t.intersectionArea(r) }
        return covered / r.area > fraction
    }

    // MARK: Regions

    /// Mean luminance of one grid cell (column 0...2, row 0...3).
    func luminance(column: Int, row: Int) -> Double {
        let i = row * ImageInsight.columns + column
        return i >= 0 && i < darkRegions.count ? darkRegions[i] : brightness
    }

    func busyness(column: Int, row: Int) -> Double {
        let i = row * ImageInsight.columns + column
        return i >= 0 && i < quietRegions.count ? quietRegions[i] : busyness
    }

    /// Average busyness of one grid row across its three columns.
    func rowBusyness(_ row: Int) -> Double {
        var sum = 0.0
        for c in 0..<ImageInsight.columns { sum += busyness(column: c, row: row) }
        return sum / Double(ImageInsight.columns)
    }

    /// Average luminance of one grid row.
    func rowLuminance(_ row: Int) -> Double {
        var sum = 0.0
        for c in 0..<ImageInsight.columns { sum += luminance(column: c, row: row) }
        return sum / Double(ImageInsight.columns)
    }

    /// The starting row of the quietest contiguous band of `rows` rows (the best place for type).
    /// Ties go to the lower band, where titles and author lines usually sit.
    func quietestBand(rows: Int) -> Int {
        let n = max(1, min(rows, ImageInsight.rows))
        var bestStart = 0
        var bestScore = Double.greatestFiniteMagnitude
        for start in 0...(ImageInsight.rows - n) {
            var score = 0.0
            for r in start..<(start + n) { score += rowBusyness(r) }
            if score <= bestScore + 1e-9 {
                bestScore = min(bestScore, score)
                bestStart = start
            }
        }
        return bestStart
    }

    /// The normalized rect covered by a band of grid rows.
    static func bandRect(start: Int, rows: Int) -> NRect {
        let rh = 1.0 / Double(ImageInsight.rows)
        return NRect(0, Double(start) * rh, 1, Double(max(1, rows)) * rh)
    }

    /// Light type on dark photos, dark type on light ones, in the palette's own voice.
    func textColorSuggestion(palette p: PaletteRoles) -> RGBA {
        brightness > 0.35 ? p.dark : p.light
    }

    // MARK: Smart crop

    /// Focus values that keep the largest face fully visible and near the upper third of the frame
    /// (rule of thirds), or that center the salient region when there is no face.
    func smartFocus(frame: NRect, canvas: CGSize, imageSize: CGSize, zoom: Double, placeFaceInUpperThird: Bool = true) -> (focusX: Double, focusY: Double) {
        let p = PhotoGeometry.placement(imageSize: imageSize, frame: frame, canvas: canvas, zoom: zoom)
        guard p.dw > 0, p.dh > 0 else { return (0.5, 0.5) }
        guard let face = faces.max(by: { $0.area < $1.area }) else {
            return PhotoGeometry.focusToShow(focus, imageSize: imageSize, frame: frame, canvas: canvas, zoom: zoom)
        }
        // Breathing room around the face so hair and chin stay in.
        let padded = NRect(face.x - face.w * 0.25, face.y - face.h * 0.45, face.w * 1.5, face.h * 1.8)
        let targetY = placeFaceInUpperThird ? p.H / 3 : p.H / 2
        let targetX = p.W / 2
        return (PhotoGeometry.axisFocus(center: face.midX, lo: padded.x, hi: padded.maxX, drawn: p.dw, frame: p.W, target: targetX),
                PhotoGeometry.axisFocus(center: face.midY, lo: padded.y, hi: padded.maxY, drawn: p.dh, frame: p.H, target: targetY))
    }

    // MARK: Analysis

    /// Measures an image. Faces, focus and palette come from the caller (Vision and the palette extractor).
    static func analyze(_ img: CGImage, faces: [NRect], focus: NRect, palette: [RGBA]) -> ImageInsight {
        let p = PixelSampler.pixels(img, maxSide: 160)
        let cols = ImageInsight.columns, rows = ImageInsight.rows
        var sum = [Double](repeating: 0, count: cols * rows)
        var sumSq = [Double](repeating: 0, count: cols * rows)
        var count = [Double](repeating: 0, count: cols * rows)
        var sr = 0.0, sg = 0.0, sb = 0.0
        var total = 0.0, totalSq = 0.0, n = 0.0
        for y in 0..<p.h {
            let row = min(rows - 1, y * rows / p.h)
            for x in 0..<p.w {
                let col = min(cols - 1, x * cols / p.w)
                let i = (y * p.w + x) * 4
                let r = Double(p.data[i]) / 255, g = Double(p.data[i + 1]) / 255, b = Double(p.data[i + 2]) / 255
                let lum = RGBA(r, g, b).luminance
                let cell = row * cols + col
                sum[cell] += lum
                sumSq[cell] += lum * lum
                count[cell] += 1
                sr += r; sg += g; sb += b
                total += lum
                totalSq += lum * lum
                n += 1
            }
        }
        var insight = ImageInsight()
        insight.faces = faces.sorted { $0.area > $1.area }
        insight.focus = focus
        insight.palette = palette
        guard n > 0 else { return insight }
        let mean = total / n
        insight.brightness = mean
        insight.busyness = sqrt(max(0, totalSq / n - mean * mean))
        insight.meanColor = RGBA(sr / n, sg / n, sb / n)
        var dark = [Double](repeating: mean, count: cols * rows)
        var quiet = [Double](repeating: 0, count: cols * rows)
        for c in 0..<(cols * rows) where count[c] > 0 {
            let m = sum[c] / count[c]
            dark[c] = m
            quiet[c] = sqrt(max(0, sumSq[c] / count[c] - m * m))
        }
        insight.darkRegions = dark
        insight.quietRegions = quiet
        let bigFace = insight.faces.contains { $0.area >= 0.04 }
        let tallCentered = focus.h > focus.w * 1.15 && abs(focus.midX - 0.5) < 0.15 && focus.h > 0.35
        insight.isPortrait = bigFace || tallCentered
        return insight
    }
}

/// Maps between photo space (normalized rects in the source image) and cover space, using the
/// same aspect-fill, zoom and focus math as `CoverRenderer.renderImage`.
enum PhotoGeometry {
    struct Placement {
        /// Frame size in canvas pixels.
        var W: Double
        var H: Double
        /// Drawn image size in canvas pixels after aspect-fill and zoom.
        var dw: Double
        var dh: Double
    }

    static func placement(imageSize: CGSize, frame: NRect, canvas: CGSize, zoom: Double) -> Placement {
        let W = frame.w * Double(canvas.width), H = frame.h * Double(canvas.height)
        let iw = Double(imageSize.width), ih = Double(imageSize.height)
        guard iw > 0, ih > 0, W > 0, H > 0 else { return Placement(W: W, H: H, dw: 0, dh: 0) }
        let s = max(W / iw, H / ih) * max(1, zoom)
        return Placement(W: W, H: H, dw: iw * s, dh: ih * s)
    }

    /// A normalized rect in the source photo (a face, say) as a normalized rect on the canvas.
    static func imageToCanvas(_ r: NRect, image: ImageContent, imageSize: CGSize, frame: NRect, canvas: CGSize) -> NRect {
        let p = placement(imageSize: imageSize, frame: frame, canvas: canvas, zoom: image.zoom)
        guard p.dw > 0, p.dh > 0, canvas.width > 0, canvas.height > 0 else { return frame }
        let ox = -(p.dw - p.W) * image.focusX.clamped01
        let oy = -(p.dh - p.H) * image.focusY.clamped01
        var fx = ox + r.x * p.dw
        let fy = oy + r.y * p.dh
        let fw = r.w * p.dw, fh = r.h * p.dh
        if image.flipped { fx = p.W - (fx + fw) }
        let cx = frame.x * Double(canvas.width) + fx
        let cy = frame.y * Double(canvas.height) + fy
        return NRect(cx / Double(canvas.width), cy / Double(canvas.height), fw / Double(canvas.width), fh / Double(canvas.height))
    }

    /// The focus values that center a photo rect in the frame (clamped, so the image never shows a gap).
    static func focusToShow(_ r: NRect, imageSize: CGSize, frame: NRect, canvas: CGSize, zoom: Double) -> (focusX: Double, focusY: Double) {
        let p = placement(imageSize: imageSize, frame: frame, canvas: canvas, zoom: zoom)
        guard p.dw > 0, p.dh > 0 else { return (0.5, 0.5) }
        return (centeringFocus(center: r.midX, drawn: p.dw, frame: p.W, target: p.W / 2),
                centeringFocus(center: r.midY, drawn: p.dh, frame: p.H, target: p.H / 2))
    }

    /// Focus along one axis that puts `center` (normalized in the photo) at `target` frame pixels.
    static func centeringFocus(center: Double, drawn: Double, frame: Double, target: Double) -> Double {
        let slack = drawn - frame
        guard slack > 0.5 else { return 0.5 }
        return ((center * drawn - target) / slack).clamped01
    }

    /// Like `centeringFocus`, but then nudged so the span `lo...hi` (normalized) stays fully inside the frame.
    static func axisFocus(center: Double, lo: Double, hi: Double, drawn: Double, frame: Double, target: Double) -> Double {
        let slack = drawn - frame
        guard slack > 0.5 else { return 0.5 }
        var f = (center * drawn - target) / slack
        // Visible when: offset + lo*drawn >= 0 and offset + hi*drawn <= frame, offset = -slack*f.
        let maxF = max(0, lo) * drawn / slack
        let minF = (min(1, hi) * drawn - frame) / slack
        if minF <= maxF {
            f = f.clamped(minF, maxF)
        } else {
            // The span is bigger than the frame: center it.
            f = ((lo + hi) / 2 * drawn - frame / 2) / slack
        }
        return f.clamped01
    }
}
