import AppKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers

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

    /// Pre-computes the expensive bits off the main thread right after import.
    func warm(_ id: UUID, data: Data?) {
        _ = image(id, data: data, resolution: .preview)
        _ = focus(id, data: data)
        _ = palette(id, data: data)
        _ = mask(id, data: data)
    }
}
