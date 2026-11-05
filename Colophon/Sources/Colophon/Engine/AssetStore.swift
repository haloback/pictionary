import AppKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import Vision

/// Decodes, caches and derives images (subject cutouts, saliency) for document assets.
final class AssetStore {
    static let shared = AssetStore()

    enum Resolution: Int {
        case thumbnail = 640
        case preview = 1800
        case full = 4000
    }

    private var images: [String: CGImage] = [:]
    private var masks: [UUID: CGImage] = [:]
    private var saliency: [UUID: NRect] = [:]
    private var palettes: [UUID: [RGBA]] = [:]
    private var faceRects: [UUID: [NRect]] = [:]
    private var insights: [UUID: ImageInsight] = [:]
    private var aestheticScores: [UUID: (score: Double, isUtility: Bool)?] = [:]
    private var textRects: [UUID: [NRect]] = [:]
    private var featurePrints: [UUID: VNFeaturePrintObservation?] = [:]
    private var labelSets: [UUID: [(label: String, confidence: Double)]] = [:]
    private let lock = NSLock()

    // MARK: Import / encode

    static func decode(_ data: Data, maxPixel: Int) -> CGImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceShouldCacheImmediately: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
    }

    static func encode(_ img: CGImage, quality: Double = 0.92) -> Data? {
        let out = NSMutableData()
        let alphaless: [CGImageAlphaInfo] = [.none, .noneSkipFirst, .noneSkipLast]
        let type = alphaless.contains(img.alphaInfo) ? UTType.jpeg : UTType.png
        guard let dest = CGImageDestinationCreateWithData(out as CFMutableData, type.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, img, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }

    /// Reads any image file, applies EXIF orientation and keeps it to a sane working size.
    static func importData(from url: URL) -> Data? {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), let img = decode(data, maxPixel: Resolution.full.rawValue) else { return nil }
        return encode(img)
    }

    // MARK: Cached access

    func image(_ id: UUID, data: Data?, resolution: Resolution) -> CGImage? {
        let key = "\(id.uuidString)-\(resolution.rawValue)"
        lock.lock()
        if let c = images[key] { lock.unlock(); return c }
        lock.unlock()
        guard let data, let img = AssetStore.decode(data, maxPixel: resolution.rawValue) else { return nil }
        lock.lock(); images[key] = img; lock.unlock()
        return img
    }

    /// Foreground mask from Vision, computed once per asset at preview resolution.
    func mask(_ id: UUID, data: Data?) -> CGImage? {
        lock.lock()
        if let m = masks[id] { lock.unlock(); return m }
        lock.unlock()
        guard let base = image(id, data: data, resolution: .thumbnail) else { return nil }
        let m = VisionServices.foregroundMask(for: base) ?? VisionServices.fallbackMask(for: base, focus: focus(id, data: data))
        if let m {
            lock.lock(); masks[id] = m; lock.unlock()
        }
        return m
    }

    func cutout(_ id: UUID, data: Data?, mode: Cutout, resolution: Resolution) -> CGImage? {
        guard let src = image(id, data: data, resolution: resolution) else { return nil }
        if mode == .none { return src }
        let key = "\(id.uuidString)-\(resolution.rawValue)-\(mode.rawValue)"
        lock.lock()
        if let c = images[key] { lock.unlock(); return c }
        lock.unlock()
        guard let m = mask(id, data: data) else { return src }
        let out = VisionServices.applyMask(m, to: src, invert: mode == .background) ?? src
        lock.lock(); images[key] = out; lock.unlock()
        return out
    }

    /// The region people look at first, normalized top-left. Defaults to the golden center.
    func focus(_ id: UUID, data: Data?) -> NRect {
        lock.lock()
        if let s = saliency[id] { lock.unlock(); return s }
        lock.unlock()
        let rect = image(id, data: data, resolution: .thumbnail).flatMap { VisionServices.saliency(for: $0) }
            ?? NRect(0.25, 0.25, 0.5, 0.5)
        lock.lock(); saliency[id] = rect; lock.unlock()
        return rect
    }

    func palette(_ id: UUID, data: Data?) -> [RGBA] {
        lock.lock()
        if let p = palettes[id] { lock.unlock(); return p }
        lock.unlock()
        guard let img = image(id, data: data, resolution: .thumbnail) else { return [] }
        let p = PaletteExtractor.extract(img)
        lock.lock(); palettes[id] = p; lock.unlock()
        return p
    }

    /// Faces from Vision, normalized top-left, largest first. Computed once per asset.
    func faces(_ id: UUID, data: Data?) -> [NRect] {
        lock.lock()
        if let f = faceRects[id] { lock.unlock(); return f }
        lock.unlock()
        let f = image(id, data: data, resolution: .thumbnail).map { VisionServices.faces(for: $0) } ?? []
        lock.lock(); faceRects[id] = f; lock.unlock()
        return f
    }

    /// Aesthetics score (−1...1) and utility flag from Vision (macOS 15+), computed once per asset.
    /// nil when the OS or Vision cannot score the picture; the nil is cached too.
    func aesthetics(_ id: UUID, data: Data?) -> (score: Double, isUtility: Bool)? {
        lock.lock()
        if let cached = aestheticScores[id] { lock.unlock(); return cached }
        lock.unlock()
        let a = image(id, data: data, resolution: .thumbnail).flatMap { VisionIntelligence.aesthetics($0) }
        lock.lock(); aestheticScores.updateValue(a, forKey: id); lock.unlock()
        return a
    }

    /// Printed text found in the photo, normalized top-left. Computed once per asset.
    func textRegions(_ id: UUID, data: Data?) -> [NRect] {
        lock.lock()
        if let t = textRects[id] { lock.unlock(); return t }
        lock.unlock()
        let t = image(id, data: data, resolution: .thumbnail).map { VisionIntelligence.textRegions($0) } ?? []
        lock.lock(); textRects[id] = t; lock.unlock()
        return t
    }

    /// Vision feature print for similarity comparisons. Computed once per asset (nil is cached too).
    func featurePrint(_ id: UUID, data: Data?) -> VNFeaturePrintObservation? {
        lock.lock()
        if let cached = featurePrints[id] { lock.unlock(); return cached }
        lock.unlock()
        let f = image(id, data: data, resolution: .thumbnail).flatMap { VisionIntelligence.featurePrint($0) }
        lock.lock(); featurePrints.updateValue(f, forKey: id); lock.unlock()
        return f
    }

    /// Scene labels ("outdoor", "cat"), most confident first. Computed once per asset.
    func labels(_ id: UUID, data: Data?) -> [(label: String, confidence: Double)] {
        lock.lock()
        if let l = labelSets[id] { lock.unlock(); return l }
        lock.unlock()
        let l = image(id, data: data, resolution: .thumbnail).map { VisionIntelligence.classify($0) } ?? []
        lock.lock(); labelSets[id] = l; lock.unlock()
        return l
    }

    /// Everything layout needs to know about a photo, computed once per asset.
    func insight(_ id: UUID, data: Data?) -> ImageInsight {
        lock.lock()
        if let i = insights[id] { lock.unlock(); return i }
        lock.unlock()
        guard let img = image(id, data: data, resolution: .thumbnail) else { return .empty }
        var i = ImageInsight.analyze(img, faces: faces(id, data: data), focus: focus(id, data: data), palette: palette(id, data: data))
        if let a = aesthetics(id, data: data) {
            i.aesthetic = a.score
            i.isUtility = a.isUtility
        }
        i.textRegions = textRegions(id, data: data)
        i.labels = labels(id, data: data).map(\.label)
        lock.lock(); insights[id] = i; lock.unlock()
        return i
    }

    /// Pixel size of the working thumbnail (same aspect as the source; no full decode).
    func imageSize(_ id: UUID, data: Data?) -> CGSize? {
        guard let img = image(id, data: data, resolution: .thumbnail) else { return nil }
        return CGSize(width: img.width, height: img.height)
    }

    /// Pre-computes the expensive bits off the main thread right after import.
    func warm(_ id: UUID, data: Data?) {
        _ = image(id, data: data, resolution: .preview)
        _ = focus(id, data: data)
        _ = palette(id, data: data)
        _ = mask(id, data: data)
        _ = insight(id, data: data)
    }
}
