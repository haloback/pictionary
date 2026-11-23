import CoreGraphics
import CoreML
import CoreVideo
import Foundation
import Observation

/// Errors raised while installing or running the print enlarger.
enum UpscalerError: LocalizedError {
    case badURL(String)
    case http(Int, String)
    case notPublished
    case checksum(String)
    case unzipFailed(String)
    case badFile(String)
    case notReady
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .badURL(let f): return "Couldn't build a download address for \(f)."
        case .http(let code, let f): return "The model server answered \(code) for \(f). Try again later."
        case .notPublished: return "The enlarger model is not published yet. Try again after the next release."
        case .checksum(let f): return "\(f) downloaded damaged (checksum mismatch). Try again."
        case .unzipFailed(let f): return "Couldn't unpack \(f)."
        case .badFile(let f): return "\(f) isn't in the expected format."
        case .notReady: return "The enlarger model isn't installed yet."
        case .writeFailed(let f): return "Couldn't save \(f) to the model cache."
        }
    }
}

/// "Enlarge for print": Real-ESRGAN x4plus (BSD, converted to Core ML and published as a release asset)
/// run tile by tile with feathered seams. Downloads on demand into Application Support/Colophon/Models;
/// `upscale` is safe to call from any thread.
@Observable
final class Upscaler {
    static let shared = Upscaler()

    enum Status: Equatable {
        case notInstalled
        case downloading(Double)
        case installing
        case ready
        case failed(String)
    }

    /// Observed state (mutated on the main thread only).
    private(set) var status: Status = .notInstalled

    var isReady: Bool { status == .ready }

    static let scale: Int = 4
    static let tile: Int = 256
    static let overlap: Int = 16
    /// Longest input side the enlarger accepts; bigger pictures are downscaled first, so output tops out at 6400 px.
    static let maxInputSide: Int = 1600

    static let baseURL: String = TasteEngine.baseURL
    static let modelAsset: String = "realesrgan-x4plus.mlpackage.zip"
    static let packageName: String = "realesrgan-x4plus.mlpackage"
    static let compiledName: String = "realesrgan-x4plus.mlmodelc"
    static let manifestAsset: String = "upscaler-manifest.json"
    static let inputName: String = "image"
    static let outputName: String = "upscaled"

    /// ~/Library/Application Support/Colophon/Models
    let modelsDirectory: URL

    private let lock = NSLock()
    @ObservationIgnored private var model: MLModel?
    @ObservationIgnored private var loadAttempted: Bool = false
    @ObservationIgnored private var inFlight: Task<Void, Error>?

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 3600
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    private init() {
        let support: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        modelsDirectory = support.appendingPathComponent("Colophon", isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
        if Upscaler.installed(in: modelsDirectory) { status = .ready }
    }

    // MARK: Paths

    private var compiledURL: URL { modelsDirectory.appendingPathComponent(Upscaler.compiledName, isDirectory: true) }
    private var downloadsURL: URL { modelsDirectory.appendingPathComponent("UpscalerDownloads", isDirectory: true) }

    private static func installed(in dir: URL) -> Bool {
        FileManager.default.fileExists(atPath: dir.appendingPathComponent(compiledName).path)
    }

    // MARK: Loading

    /// Loads the compiled model on first use. Caller holds `lock`.
    private func loadIfNeededLocked() -> Bool {
        if model != nil { return true }
        if loadAttempted { return false }
        loadAttempted = true
        guard Upscaler.installed(in: modelsDirectory) else { return false }
        let config = MLModelConfiguration()
        config.computeUnits = .all
        do {
            let m: MLModel = try MLModel(contentsOf: compiledURL, configuration: config)
            model = m
            return true
        } catch {
            setStatus(.failed(Upscaler.message(for: error)))
            return false
        }
    }

    private func setStatus(_ s: Status) {
        if Thread.isMainThread {
            status = s
        } else {
            DispatchQueue.main.async { [weak self] in self?.status = s }
        }
    }

    // MARK: Install

    /// Downloads, verifies, unpacks, compiles and loads the model. Idempotent; concurrent calls share one task.
    @MainActor
    func install() async throws {
        if status == .ready && Upscaler.installed(in: modelsDirectory) { return }
        if let running = inFlight { return try await running.value }
        let task: Task<Void, Error> = Task { @MainActor in
            try await self.performInstall()
        }
        inFlight = task
        defer { inFlight = nil }
        try await task.value
    }

    @MainActor
    private func performInstall() async throws {
        status = .downloading(0)
        let dir: URL = modelsDirectory
        let downloads: URL = downloadsURL
        let compiled: URL = compiledURL
        let report: @Sendable (Double) -> Void = { [weak self] p in
            DispatchQueue.main.async { self?.status = .downloading(p) }
        }
        let installing: @Sendable () -> Void = { [weak self] in
            DispatchQueue.main.async { self?.status = .installing }
        }
        do {
            try await Task.detached(priority: .userInitiated) {
                try Upscaler.installFiles(dir: dir, downloads: downloads, compiled: compiled, progress: report, installing: installing)
            }.value
            lock.lock()
            model = nil
            loadAttempted = false
            let ok: Bool = loadIfNeededLocked()
            lock.unlock()
            if ok {
                status = .ready
            } else if case .failed = status {
                throw UpscalerError.notReady
            } else {
                status = .failed("The model didn't load after installing.")
                throw UpscalerError.notReady
            }
        } catch {
            status = .failed(Upscaler.message(for: error))
            throw error
        }
    }

    /// Blocking file work: runs off the main thread.
    private static func installFiles(dir: URL, downloads: URL, compiled: URL,
                                     progress: @escaping @Sendable (Double) -> Void,
                                     installing: @escaping @Sendable () -> Void) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: downloads, withIntermediateDirectories: true, attributes: nil)

        // Manifest (optional: verification is skipped when it's missing).
        var manifest: [String: (size: Int?, sha256: String?)] = [:]
        if let mURL = url(for: manifestAsset) {
            let mDest: URL = downloads.appendingPathComponent(manifestAsset)
            if (try? download(mURL, to: mDest, progress: { _ in })) != nil {
                manifest = TasteEngine.parseManifest(mDest)
            }
        }

        let name: String = modelAsset
        let dest: URL = downloads.appendingPathComponent(name)
        let entry: (size: Int?, sha256: String?)? = manifest[name]
        var reuse: Bool = false
        if fm.fileExists(atPath: dest.path), let expected = entry?.sha256 {
            reuse = (try? TasteEngine.sha256(of: dest)) == expected.lowercased()
        }
        if !reuse {
            guard let remote = url(for: name) else { throw UpscalerError.badURL(name) }
            try download(remote, to: dest, progress: { p in progress(min(0.999, p)) })
            if let expected = entry?.sha256 {
                let actual: String = try TasteEngine.sha256(of: dest)
                guard actual == expected.lowercased() else {
                    try? fm.removeItem(at: dest)
                    throw UpscalerError.checksum(name)
                }
            }
        }
        progress(0.999)
        installing()

        // Unpack.
        let stage: URL = downloads.appendingPathComponent("stage", isDirectory: true)
        try? fm.removeItem(at: stage)
        try fm.createDirectory(at: stage, withIntermediateDirectories: true, attributes: nil)
        try unzip(dest, into: stage)
        let package: URL = try locate(packageName, under: stage)

        // Compile and move into place.
        try fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        let compiledTemp: URL = try MLModel.compileModel(at: package)
        try replace(at: compiled, with: compiledTemp)
        try? fm.removeItem(at: downloads)
    }

    private static func url(for name: String) -> URL? {
        URL(string: baseURL + name)
    }

    private static func replace(at dest: URL, with source: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
        do {
            try fm.moveItem(at: source, to: dest)
        } catch {
            do {
                try fm.copyItem(at: source, to: dest)
            } catch {
                throw UpscalerError.writeFailed(dest.lastPathComponent)
            }
        }
    }

    /// Finds a file or folder by name directly under `root` or deeper (zips may wrap a folder).
    private static func locate(_ name: String, under root: URL) throws -> URL {
        let fm = FileManager.default
        let direct: URL = root.appendingPathComponent(name)
        if fm.fileExists(atPath: direct.path) { return direct }
        if let walker = fm.enumerator(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            while let next = walker.nextObject() {
                guard let u = next as? URL else { continue }
                if u.lastPathComponent == name { return u }
            }
        }
        throw UpscalerError.badFile(name)
    }

    private static func unzip(_ zip: URL, into dir: URL) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        p.arguments = ["-x", "-k", zip.path, dir.path]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
        } catch {
            throw UpscalerError.unzipFailed(zip.lastPathComponent)
        }
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { throw UpscalerError.unzipFailed(zip.lastPathComponent) }
    }

    /// Streams a download to `dest`, reporting 0...1 progress when the server sends a length.
    /// A 404 means the asset hasn't been published yet.
    private static func download(_ remote: URL, to dest: URL, progress: @escaping @Sendable (Double) -> Void) throws {
        let fm = FileManager.default
        let temp: URL = dest.appendingPathExtension("part")
        try? fm.removeItem(at: temp)
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<URL, Error> = .failure(UpscalerError.badURL(remote.lastPathComponent))
        let delegate = DownloadDelegate(progress: progress) { r in
            result = r
            semaphore.signal()
        }
        let session = URLSession(configuration: Upscaler.session.configuration, delegate: delegate, delegateQueue: nil)
        let task: URLSessionDownloadTask = session.downloadTask(with: remote)
        task.resume()
        semaphore.wait()
        session.finishTasksAndInvalidate()
        let location: URL = try result.get()
        try? fm.removeItem(at: dest)
        do {
            try fm.moveItem(at: location, to: dest)
        } catch {
            throw UpscalerError.writeFailed(dest.lastPathComponent)
        }
    }

    /// Collects download progress and the final file for `download`.
    private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
        private let progress: @Sendable (Double) -> Void
        private let completion: (Result<URL, Error>) -> Void
        private var finished: Bool = false
        private var lastReported: Double = -1

        init(progress: @escaping @Sendable (Double) -> Void, completion: @escaping (Result<URL, Error>) -> Void) {
            self.progress = progress
            self.completion = completion
        }

        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                        totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
            guard totalBytesExpectedToWrite > 0 else { return }
            let p: Double = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            if p - lastReported >= 0.01 {
                lastReported = p
                progress(p)
            }
        }

        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
            // The file is deleted when this returns, so move it right away.
            let name: String = downloadTask.originalRequest?.url?.lastPathComponent ?? "asset"
            if let http = downloadTask.response as? HTTPURLResponse, http.statusCode != 200 {
                if http.statusCode == 404 {
                    finish(.failure(UpscalerError.notPublished))
                } else {
                    finish(.failure(UpscalerError.http(http.statusCode, name)))
                }
                return
            }
            let keep: URL = location.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + "-" + name)
            do {
                try FileManager.default.moveItem(at: location, to: keep)
                finish(.success(keep))
            } catch {
                finish(.failure(UpscalerError.writeFailed(name)))
            }
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            if let error { finish(.failure(error)) }
            else if !finished {
                let name: String = task.originalRequest?.url?.lastPathComponent ?? "asset"
                finish(.failure(UpscalerError.writeFailed(name)))
            }
        }

        private func finish(_ r: Result<URL, Error>) {
            if finished { return }
            finished = true
            completion(r)
        }
    }

    static func message(for error: Error) -> String {
        if let e = error as? UpscalerError { return e.errorDescription ?? "Install failed." }
        return TasteEngine.message(for: error)
    }

    // MARK: Tiling

    /// Tile origins along one axis: a fixed stride of `tile - overlap`, with the last tile pulled back so it
    /// ends exactly on the edge. A side shorter than one tile gets a single tile at 0 (padded when read).
    static func tileOrigins(length: Int, tileSize: Int = tile, overlap: Int = overlap) -> [Int] {
        guard length > tileSize else { return [0] }
        let stride: Int = max(1, tileSize - overlap)
        var out: [Int] = []
        var x: Int = 0
        while x + tileSize < length {
            out.append(x)
            x += stride
        }
        out.append(length - tileSize)
        return out
    }

    /// Top-left corners (input space) of every tile needed to cover a `width` x `height` picture.
    static func tilesFor(width: Int, height: Int) -> [(x: Int, y: Int)] {
        let xs: [Int] = tileOrigins(length: width)
        let ys: [Int] = tileOrigins(length: height)
        var out: [(x: Int, y: Int)] = []
        out.reserveCapacity(xs.count * ys.count)
        for y in ys {
            for x in xs { out.append((x: x, y: y)) }
        }
        return out
    }

    /// A 1-D blend weight per pixel of a tile edge: ramps up over `overlap` pixels at each end
    /// (never exactly zero, so a lone contributor still defines its pixel) and is 1 in the middle.
    static func stitchWeights(tileSize: Int, overlap: Int) -> [Float] {
        var w: [Float] = Array(repeating: 1, count: max(0, tileSize))
        let ramp: Int = max(0, min(overlap, tileSize / 2))
        guard ramp > 0 else { return w }
        for i in 0..<ramp {
            let v: Float = Float(i + 1) / Float(ramp + 1)
            w[i] = v
            w[tileSize - 1 - i] = v
        }
        return w
    }

    /// Accumulates weighted tile outputs into one picture, one tile at a time, so only the running sums
    /// (not every tile) stay in memory.
    final class StitchAccumulator {
        let outW: Int
        let outH: Int
        let tileOut: Int
        private let ramp: [Float]
        private var acc: [Float]
        private var wsum: [Float]

        init(tileOut: Int, overlapOut: Int, outW: Int, outH: Int) {
            let w: Int = max(0, outW)
            let h: Int = max(0, outH)
            let side: Int = max(0, tileOut)
            self.outW = w
            self.outH = h
            self.tileOut = side
            ramp = Upscaler.stitchWeights(tileSize: side, overlap: overlapOut)
            acc = Array(repeating: 0, count: w * h * 3)
            wsum = Array(repeating: 0, count: w * h)
        }

        /// Adds a CHW float tile (3 x tileOut x tileOut, values 0...1) whose top-left corner sits at (`x`, `y`)
        /// in output space; parts outside the picture are ignored.
        func add(x: Int, y: Int, pixels: [Float]) {
            let side: Int = tileOut
            let plane: Int = side * side
            guard pixels.count >= plane * 3, outW > 0, outH > 0 else { return }
            let w0: Int = outW
            let h0: Int = outH
            let weights: [Float] = ramp
            pixels.withUnsafeBufferPointer { src in
                acc.withUnsafeMutableBufferPointer { a in
                    wsum.withUnsafeMutableBufferPointer { ws in
                        for ty in 0..<side {
                            let oy: Int = y + ty
                            if oy < 0 || oy >= h0 { continue }
                            let wy: Float = weights[ty]
                            for tx in 0..<side {
                                let ox: Int = x + tx
                                if ox < 0 || ox >= w0 { continue }
                                let w: Float = wy * weights[tx]
                                let si: Int = ty * side + tx
                                let oi: Int = oy * w0 + ox
                                a[oi * 3] += src[si] * w
                                a[oi * 3 + 1] += src[plane + si] * w
                                a[oi * 3 + 2] += src[plane * 2 + si] * w
                                ws[oi] += w
                            }
                        }
                    }
                }
            }
        }

        /// Normalizes the sums into RGBA8 rows (alpha 255).
        func finish() -> [UInt8] {
            let count: Int = outW * outH
            var out: [UInt8] = Array(repeating: 255, count: count * 4)
            out.withUnsafeMutableBufferPointer { dst in
                for i in 0..<count {
                    let w: Float = wsum[i]
                    let inv: Float = w > 0 ? 1 / w : 0
                    for c in 0..<3 {
                        let v: Float = acc[i * 3 + c] * inv
                        let scaled: Float = min(255, max(0, (v * 255).rounded()))
                        dst[i * 4 + c] = UInt8(scaled)
                    }
                    dst[i * 4 + 3] = 255
                }
            }
            return out
        }
    }

    /// Blends tile outputs into one `outW` x `outH` RGBA8 picture. Each tile's `pixels` is CHW float
    /// (3 x tileOut x tileOut, values 0...1) placed with its top-left corner at (`x`, `y`) in output space;
    /// tiles are weighted by a ramp over `overlapOut` at every edge and normalized, so seams feather away.
    static func stitch(tileOutputs: [(x: Int, y: Int, pixels: [Float])], tileOut: Int, overlapOut: Int,
                       outW: Int, outH: Int) -> [UInt8] {
        guard outW > 0, outH > 0, tileOut > 0 else { return [] }
        let acc = StitchAccumulator(tileOut: tileOut, overlapOut: overlapOut, outW: outW, outH: outH)
        for t in tileOutputs { acc.add(x: t.x, y: t.y, pixels: t.pixels) }
        return acc.finish()
    }

    // MARK: Pixels

    /// The picture as tightly packed BGRA8 rows (the layout the Core ML pixel buffer wants), shrunk so the
    /// longest side is at most `maxSide`.
    static func bgraPixels(_ image: CGImage, maxSide: Int) -> (pixels: [UInt8], width: Int, height: Int)? {
        let w0: Int = image.width
        let h0: Int = image.height
        guard w0 > 0, h0 > 0 else { return nil }
        let longest: Int = max(w0, h0)
        let f: Double = longest > maxSide ? Double(maxSide) / Double(longest) : 1
        let w: Int = max(1, Int((Double(w0) * f).rounded()))
        let h: Int = max(1, Int((Double(h0) * f).rounded()))
        var pixels: [UInt8] = Array(repeating: 0, count: w * h * 4)
        let info: UInt32 = CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        let ok: Bool = pixels.withUnsafeMutableBytes { raw -> Bool in
            guard let base = raw.baseAddress,
                  let ctx = CGContext(data: base, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: Gfx.sRGB, bitmapInfo: info) else { return false }
            ctx.interpolationQuality = .high
            ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        return ok ? (pixels, w, h) : nil
    }

    /// Fills a `side` x `side` BGRA pixel buffer with the tile at (`x`, `y`), clamping reads past the
    /// right and bottom edges so every tile is full size.
    static func tileBuffer(from pixels: [UInt8], width: Int, height: Int, x: Int, y: Int, side: Int) -> CVPixelBuffer? {
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        var pb: CVPixelBuffer?
        let status: CVReturn = CVPixelBufferCreate(kCFAllocatorDefault, side, side, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &pb)
        guard status == kCVReturnSuccess, let buffer = pb else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let rowBytes: Int = CVPixelBufferGetBytesPerRow(buffer)
        let dst = base.assumingMemoryBound(to: UInt8.self)
        pixels.withUnsafeBufferPointer { src in
            for ty in 0..<side {
                let sy: Int = min(height - 1, max(0, y + ty))
                let drow: Int = ty * rowBytes
                let srow: Int = sy * width * 4
                for tx in 0..<side {
                    let sx: Int = min(width - 1, max(0, x + tx))
                    let s: Int = srow + sx * 4
                    let d: Int = drow + tx * 4
                    dst[d] = src[s]
                    dst[d + 1] = src[s + 1]
                    dst[d + 2] = src[s + 2]
                    dst[d + 3] = src[s + 3]
                }
            }
        }
        return buffer
    }

    /// Copies a 1 x 3 x H x W multi-array into a dense CHW float array (values as stored, 0...1).
    static func chwFloats(_ array: MLMultiArray, side: Int) -> [Float]? {
        let shape: [Int] = array.shape.map { $0.intValue }
        guard shape.count >= 3 else { return nil }
        let strides: [Int] = array.strides.map { $0.intValue }
        let n: Int = shape.count
        let channels: Int = shape[n - 3]
        let height: Int = shape[n - 2]
        let width: Int = shape[n - 1]
        guard channels >= 3, height == side, width == side else { return nil }
        let sc: Int = strides[n - 3]
        let sh: Int = strides[n - 2]
        let sw: Int = strides[n - 1]
        var out: [Float] = Array(repeating: 0, count: 3 * side * side)
        switch array.dataType {
        case .float32:
            let p = array.dataPointer.assumingMemoryBound(to: Float.self)
            out.withUnsafeMutableBufferPointer { dst in
                for c in 0..<3 {
                    for y in 0..<side {
                        let rowBase: Int = c * sc + y * sh
                        let o: Int = c * side * side + y * side
                        for x in 0..<side { dst[o + x] = p[rowBase + x * sw] }
                    }
                }
            }
        case .double:
            let p = array.dataPointer.assumingMemoryBound(to: Double.self)
            out.withUnsafeMutableBufferPointer { dst in
                for c in 0..<3 {
                    for y in 0..<side {
                        let rowBase: Int = c * sc + y * sh
                        let o: Int = c * side * side + y * side
                        for x in 0..<side { dst[o + x] = Float(p[rowBase + x * sw]) }
                    }
                }
            }
        default:
            // Float16 or anything else: the slow but general path.
            for c in 0..<3 {
                for y in 0..<side {
                    for x in 0..<side {
                        let idx: [NSNumber] = n == 4 ? [0, c, y, x] as [NSNumber] : [c, y, x] as [NSNumber]
                        out[c * side * side + y * side + x] = array[idx].floatValue
                    }
                }
            }
        }
        return out
    }

    /// Wraps RGBA8 rows in a CGImage (alpha ignored, so it encodes as JPEG).
    static func image(fromRGBA rgba: [UInt8], width: Int, height: Int) -> CGImage? {
        guard width > 0, height > 0, rgba.count >= width * height * 4 else { return nil }
        let data = Data(rgba)
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                       space: Gfx.sRGB, bitmapInfo: info, provider: provider, decode: nil, shouldInterpolate: true,
                       intent: .defaultIntent)
    }

    // MARK: Upscale

    /// Enlarges a picture 4x. Pictures longer than 1600 px on a side are shrunk first. Returns nil when the
    /// model isn't installed or a prediction fails. `progress` is called once per tile (0...1).
    func upscale(_ image: CGImage, progress: ((Double) -> Void)? = nil) -> CGImage? {
        guard let src = Upscaler.bgraPixels(image, maxSide: Upscaler.maxInputSide) else { return nil }
        let w: Int = src.width
        let h: Int = src.height
        let side: Int = Upscaler.tile
        let scale: Int = Upscaler.scale
        let tileOut: Int = side * scale
        let origins: [(x: Int, y: Int)] = Upscaler.tilesFor(width: w, height: h)
        let outW: Int = w * scale
        let outH: Int = h * scale
        lock.lock()
        defer { lock.unlock() }
        guard loadIfNeededLocked(), let model else { return nil }
        let acc = StitchAccumulator(tileOut: tileOut, overlapOut: Upscaler.overlap * scale, outW: outW, outH: outH)
        for (i, o) in origins.enumerated() {
            guard let buffer = Upscaler.tileBuffer(from: src.pixels, width: w, height: h, x: o.x, y: o.y, side: side) else { return nil }
            let input: MLDictionaryFeatureProvider
            do {
                input = try MLDictionaryFeatureProvider(dictionary: [Upscaler.inputName: MLFeatureValue(pixelBuffer: buffer)])
            } catch {
                return nil
            }
            guard let result = try? model.prediction(from: input),
                  let array = result.featureValue(for: Upscaler.outputName)?.multiArrayValue,
                  let floats = Upscaler.chwFloats(array, side: tileOut) else { return nil }
            acc.add(x: o.x * scale, y: o.y * scale, pixels: floats)
            progress?(Double(i + 1) / Double(origins.count))
        }
        let rgba: [UInt8] = acc.finish()
        return Upscaler.image(fromRGBA: rgba, width: outW, height: outH)
    }
}
