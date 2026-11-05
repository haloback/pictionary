import CoreGraphics
import CoreML
import CoreVideo
import CryptoKit
import Foundation
import Observation

/// Errors raised while installing or running the taste models.
enum TasteEngineError: LocalizedError {
    case badURL(String)
    case http(Int, String)
    case checksum(String)
    case unzipFailed(String)
    case badFile(String)
    case notReady
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .badURL(let f): return "Couldn't build a download address for \(f)."
        case .http(let code, let f): return "The model server answered \(code) for \(f). Try again later."
        case .checksum(let f): return "\(f) downloaded damaged (checksum mismatch). Try again."
        case .unzipFailed(let f): return "Couldn't unpack \(f)."
        case .badFile(let f): return "\(f) isn't in the expected format."
        case .notReady: return "The taste models aren't installed yet."
        case .writeFailed(let f): return "Couldn't save \(f) to the model cache."
        }
    }
}

/// What the taste engine thinks of a cover.
struct TasteReport {
    /// Every genre with its zero-shot probability, best first.
    var genreFit: [(genre: Genre, score: Double)]
    var moodTags: [String]
    /// Probability (0...1) that the cover reads as professionally designed.
    var professionalism: Double
    /// LAION aesthetic score mapped to 0...1 (nil when the head isn't installed).
    var aesthetic: Double?
    /// The probability of the book's own genre in `genreFit`.
    var fitForBook: Double
}

/// Local "taste": OpenAI CLIP ViT-B/32 (MIT) converted to Core ML and published as release
/// assets, plus the LAION aesthetic head. Everything downloads on demand into
/// Application Support/Colophon/Models; predictions are safe to call from any thread.
@Observable
final class TasteEngine {
    static let shared = TasteEngine()

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

    static let baseURL: String = "https://github.com/haloback/pictionary/releases/download/models-v1/"
    static let imageAsset: String = "clip-vit-b32-image.mlpackage.zip"
    static let textAsset: String = "clip-vit-b32-text.mlpackage.zip"
    static let tokenizerAsset: String = "clip-tokenizer.zip"
    static let aestheticAsset: String = "aesthetic-vit-b32.json"
    /// Optional: a head trained on real covers; when present, genre fit uses it instead of zero-shot prompts.
    static let genreHeadAsset: String = "genre-head-vit-b32.json"
    static let manifestAsset: String = "manifest.json"
    static let imageSide: Int = 224
    static let contextLength: Int = 77

    /// Short labels for the zero-shot genre prompts.
    static func promptLabel(_ g: Genre) -> String {
        switch g {
        case .thriller: return "thriller"
        case .mystery: return "mystery"
        case .horror: return "horror"
        case .romance: return "romance"
        case .fantasy: return "fantasy"
        case .scienceFiction: return "science fiction"
        case .literary: return "literary"
        case .historical: return "historical"
        case .youngAdult: return "young adult"
        case .cozy: return "cozy mystery"
        case .nonfiction: return "nonfiction"
        case .memoir: return "memoir"
        }
    }

    /// Several phrasings per genre; their embeddings are averaged (CLIP's prompt ensembling), which reads
    /// covers far more reliably than one sentence.
    static func genrePrompts(_ g: Genre) -> [String] {
        let label = promptLabel(g)
        var out = ["a \(label) book cover", "the cover of a \(label) book", "a \(label) novel, paperback cover design"]
        switch g {
        case .thriller: out += ["a tense thriller book cover with bold type", "a suspense thriller paperback"]
        case .mystery: out += ["a mystery crime novel cover", "a detective novel book jacket"]
        case .horror: out += ["a scary horror novel cover", "a frightening dark horror book jacket", "a creepy horror paperback"]
        case .romance: out += ["a romance novel cover", "a love story book cover"]
        case .fantasy: out += ["an epic fantasy novel cover", "a fantasy book jacket with swords, crowns or dragons"]
        case .scienceFiction: out += ["a science fiction novel cover", "a sci-fi book cover with space or technology"]
        case .literary: out += ["a literary fiction book cover", "an elegant literary novel jacket"]
        case .historical: out += ["a historical fiction novel cover", "a period drama book cover"]
        case .youngAdult: out += ["a young adult novel cover", "a YA book cover with bold colorful type"]
        case .cozy: out += ["a cozy mystery book cover", "a charming cozy novel cover with a village, tea or a cat"]
        case .nonfiction: out += ["a nonfiction book cover", "a business or self-help book cover with a big one-word title"]
        case .memoir: out += ["a memoir book cover", "an autobiography book cover with a photograph"]
        }
        return out
    }

    static let moodVocabulary: [String] = [
        "moody", "foggy", "warm", "cold", "bold", "quiet", "elegant", "gritty", "dreamy", "dark", "bright", "vintage",
        "modern", "minimal", "ornate", "romantic", "eerie", "epic", "cozy", "cosmic", "urban", "rural", "stormy", "sunny",
        "nocturnal", "pastel", "neon", "monochrome", "painterly", "photographic", "typographic", "hand-lettered",
        "luxurious", "playful", "serious", "tense", "melancholy", "hopeful", "wild", "industrial", "nautical", "floral",
        "wintry", "autumnal", "desert", "forest", "royal", "noir"
    ]

    static let professionalPrompt: String = "a professionally designed bestselling book cover by an award-winning designer"
    static let amateurPrompt: String = "an amateur self-published book cover with clip art and default fonts"

    /// ~/Library/Application Support/Colophon/Models
    let modelsDirectory: URL

    // Unobserved, guarded by `lock` (models) or self-synchronizing (caches).
    private let lock = NSLock()
    @ObservationIgnored private var imageModel: MLModel?
    @ObservationIgnored private var textModel: MLModel?
    @ObservationIgnored private var tokenizer: ClipTokenizer?
    @ObservationIgnored private var aestheticHead: (weight: [Float], bias: Float)?
    @ObservationIgnored private var genreHead: (genres: [Genre], weight: [[Float]], bias: [Float])?
    @ObservationIgnored private var loadAttempted: Bool = false
    @ObservationIgnored private var inFlight: Task<Void, Error>?

    private final class Vector {
        let values: [Float]
        init(_ v: [Float]) { values = v }
    }

    private let imageCache: NSCache<NSString, Vector> = {
        let c = NSCache<NSString, Vector>()
        c.countLimit = 300
        return c
    }()
    private let textCache: NSCache<NSString, Vector> = {
        let c = NSCache<NSString, Vector>()
        c.countLimit = 2000
        return c
    }()
    private let designCache: NSCache<NSString, Vector> = {
        let c = NSCache<NSString, Vector>()
        c.countLimit = 400
        return c
    }()

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
        if TasteEngine.installed(in: modelsDirectory) { status = .ready }
    }

    // MARK: Paths

    private var compiledImageURL: URL { modelsDirectory.appendingPathComponent("clip-vit-b32-image.mlmodelc", isDirectory: true) }
    private var compiledTextURL: URL { modelsDirectory.appendingPathComponent("clip-vit-b32-text.mlmodelc", isDirectory: true) }
    private var tokenizerURL: URL { modelsDirectory.appendingPathComponent("clip-tokenizer", isDirectory: true) }
    private var aestheticURL: URL { modelsDirectory.appendingPathComponent(TasteEngine.aestheticAsset) }
    private var genreHeadURL: URL { modelsDirectory.appendingPathComponent(TasteEngine.genreHeadAsset) }
    /// Whether genre fit comes from the head trained on real covers.
    var usesTrainedGenreHead: Bool { genreHead != nil }
    private var downloadsURL: URL { modelsDirectory.appendingPathComponent("Downloads", isDirectory: true) }

    private static func installed(in dir: URL) -> Bool {
        let fm = FileManager.default
        let needed: [String] = ["clip-vit-b32-image.mlmodelc", "clip-vit-b32-text.mlmodelc", "clip-tokenizer/vocab.json", "clip-tokenizer/merges.txt"]
        for n in needed where !fm.fileExists(atPath: dir.appendingPathComponent(n).path) { return false }
        return true
    }

    // MARK: Loading

    /// Loads the compiled models on first use. Caller holds `lock`.
    private func loadIfNeededLocked() -> Bool {
        if imageModel != nil && textModel != nil && tokenizer != nil { return true }
        if loadAttempted { return false }
        loadAttempted = true
        guard TasteEngine.installed(in: modelsDirectory) else { return false }
        let config = MLModelConfiguration()
        config.computeUnits = .all
        do {
            let image: MLModel = try MLModel(contentsOf: compiledImageURL, configuration: config)
            let text: MLModel = try MLModel(contentsOf: compiledTextURL, configuration: config)
            let tok: ClipTokenizer = try ClipTokenizer(directory: tokenizerURL)
            imageModel = image
            textModel = text
            tokenizer = tok
            aestheticHead = TasteEngine.loadHead(aestheticURL)
            genreHead = TasteEngine.loadGenreHead(genreHeadURL)
            return true
        } catch {
            let message: String = TasteEngine.message(for: error)
            setStatus(.failed(message))
            return false
        }
    }

    /// The trained genre head: rows of 512 weights per genre, in the file's genre order.
    private static func loadGenreHead(_ url: URL) -> (genres: [Genre], weight: [[Float]], bias: [Float])? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let root = json as? [String: Any],
              let names = root["genres"] as? [String],
              let rows = root["weight"] as? [[NSNumber]],
              let biases = root["bias"] as? [NSNumber], rows.count == names.count, biases.count == names.count else { return nil }
        var genres: [Genre] = []
        var weight: [[Float]] = []
        var bias: [Float] = []
        for (i, n) in names.enumerated() {
            guard let g = Genre(rawValue: n), rows[i].count == 512 else { continue }
            genres.append(g)
            weight.append(rows[i].map { $0.floatValue })
            bias.append(biases[i].floatValue)
        }
        return genres.count >= 6 ? (genres, weight, bias) : nil
    }

    private static func loadHead(_ url: URL) -> (weight: [Float], bias: Float)? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let root = json as? [String: Any],
              let w = root["weight"] as? [Any] else { return nil }
        var weight: [Float] = []
        weight.reserveCapacity(w.count)
        for v in w {
            guard let n = v as? NSNumber else { return nil }
            weight.append(n.floatValue)
        }
        guard weight.count == 512 else { return nil }
        let bias: Float = (root["bias"] as? NSNumber)?.floatValue ?? 0
        return (weight, bias)
    }

    private func setStatus(_ s: Status) {
        if Thread.isMainThread {
            status = s
        } else {
            DispatchQueue.main.async { [weak self] in self?.status = s }
        }
    }

    // MARK: Install

    /// Downloads, verifies, unpacks, compiles and loads the models. Idempotent; concurrent calls share one task.
    @MainActor
    func install() async throws {
        if status == .ready && TasteEngine.installed(in: modelsDirectory) { return }
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
        let compiledImage: URL = compiledImageURL
        let compiledText: URL = compiledTextURL
        let tokenizerDest: URL = tokenizerURL
        let aestheticDest: URL = aestheticURL
        let report: @Sendable (Double) -> Void = { [weak self] p in
            DispatchQueue.main.async { self?.status = .downloading(p) }
        }
        let installing: @Sendable () -> Void = { [weak self] in
            DispatchQueue.main.async { self?.status = .installing }
        }
        do {
            try await Task.detached(priority: .userInitiated) {
                try TasteEngine.installFiles(dir: dir, downloads: downloads, compiledImage: compiledImage,
                                             compiledText: compiledText, tokenizerDest: tokenizerDest,
                                             aestheticDest: aestheticDest, progress: report, installing: installing)
            }.value
            lock.lock()
            imageModel = nil
            textModel = nil
            tokenizer = nil
            loadAttempted = false
            let ok: Bool = loadIfNeededLocked()
            lock.unlock()
            imageCache.removeAllObjects()
            textCache.removeAllObjects()
            designCache.removeAllObjects()
            calibrationLock.lock()
            referenceVectors = nil; genreBaselines = [:]; tagBaselines = [:]; proBaseline = nil; designBiases = [:]; promptSetVectors = nil
            calibrationLock.unlock()
            if ok {
                status = .ready
            } else if case .failed = status {
                throw TasteEngineError.notReady
            } else {
                status = .failed("The models didn't load after installing.")
                throw TasteEngineError.notReady
            }
        } catch {
            status = .failed(TasteEngine.message(for: error))
            throw error
        }
    }

    /// Blocking file work: runs off the main thread.
    private static func installFiles(dir: URL, downloads: URL, compiledImage: URL, compiledText: URL,
                                     tokenizerDest: URL, aestheticDest: URL,
                                     progress: @escaping @Sendable (Double) -> Void,
                                     installing: @escaping @Sendable () -> Void) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: downloads, withIntermediateDirectories: true, attributes: nil)

        // Manifest (optional: verification is skipped when it's missing).
        var manifest: [String: (size: Int?, sha256: String?)] = [:]
        if let mURL = url(for: manifestAsset) {
            let mDest: URL = downloads.appendingPathComponent(manifestAsset)
            if (try? download(mURL, to: mDest, progress: { _ in })) != nil {
                manifest = parseManifest(mDest)
            }
        }

        let names: [String] = [imageAsset, textAsset, tokenizerAsset, aestheticAsset]
        let weights: [Double] = [0.62, 0.3, 0.04, 0.04]
        var done: Double = 0
        for (i, name) in names.enumerated() {
            let dest: URL = downloads.appendingPathComponent(name)
            let entry: (size: Int?, sha256: String?)? = manifest[name]
            var reuse: Bool = false
            if fm.fileExists(atPath: dest.path), let expected = entry?.sha256 {
                reuse = (try? sha256(of: dest)) == expected.lowercased()
            }
            if !reuse {
                guard let remote = url(for: name) else { throw TasteEngineError.badURL(name) }
                let base: Double = done
                let w: Double = weights[i]
                try download(remote, to: dest, progress: { p in progress(min(0.999, base + w * p)) })
                if let expected = entry?.sha256 {
                    let actual: String = try sha256(of: dest)
                    guard actual == expected.lowercased() else {
                        try? fm.removeItem(at: dest)
                        throw TasteEngineError.checksum(name)
                    }
                }
            }
            done += weights[i]
            progress(min(0.999, done))
        }
        installing()

        // Unpack.
        let stage: URL = downloads.appendingPathComponent("stage", isDirectory: true)
        try? fm.removeItem(at: stage)
        try fm.createDirectory(at: stage, withIntermediateDirectories: true, attributes: nil)
        try unzip(downloads.appendingPathComponent(imageAsset), into: stage)
        try unzip(downloads.appendingPathComponent(textAsset), into: stage)
        try unzip(downloads.appendingPathComponent(tokenizerAsset), into: stage)
        let imagePackage: URL = try locate("clip-vit-b32-image.mlpackage", under: stage)
        let textPackage: URL = try locate("clip-vit-b32-text.mlpackage", under: stage)
        let tokenizerFolder: URL = try locate("clip-tokenizer", under: stage)
        guard fm.fileExists(atPath: tokenizerFolder.appendingPathComponent("vocab.json").path),
              fm.fileExists(atPath: tokenizerFolder.appendingPathComponent("merges.txt").path) else {
            throw TasteEngineError.badFile(tokenizerAsset)
        }

        // Compile and move into place.
        try fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        let compiledImageTemp: URL = try MLModel.compileModel(at: imagePackage)
        try replace(at: compiledImage, with: compiledImageTemp)
        let compiledTextTemp: URL = try MLModel.compileModel(at: textPackage)
        try replace(at: compiledText, with: compiledTextTemp)
        try replace(at: tokenizerDest, with: tokenizerFolder)
        try replace(at: aestheticDest, with: downloads.appendingPathComponent(aestheticAsset))
        // The trained genre head is optional: absent from older releases, and nothing breaks without it.
        if let headURL = url(for: genreHeadAsset) {
            let headTemp: URL = downloads.appendingPathComponent(genreHeadAsset)
            if (try? download(headURL, to: headTemp, progress: { _ in })) != nil, fm.fileExists(atPath: headTemp.path),
               ((try? Data(contentsOf: headTemp))?.count ?? 0) > 1000 {
                try? replace(at: dir.appendingPathComponent(genreHeadAsset), with: headTemp)
            }
        }
        let manifestSource: URL = downloads.appendingPathComponent(manifestAsset)
        if fm.fileExists(atPath: manifestSource.path) {
            try? replace(at: dir.appendingPathComponent(manifestAsset), with: manifestSource)
        }
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
                throw TasteEngineError.writeFailed(dest.lastPathComponent)
            }
        }
    }

    /// Finds a file or folder by name directly under `root` or one level down (zips may wrap a folder).
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
        throw TasteEngineError.badFile(name)
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
            throw TasteEngineError.unzipFailed(zip.lastPathComponent)
        }
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { throw TasteEngineError.unzipFailed(zip.lastPathComponent) }
    }

    /// Streams a download to `dest`, reporting 0...1 progress when the server sends a length.
    private static func download(_ remote: URL, to dest: URL, progress: @escaping @Sendable (Double) -> Void) throws {
        let fm = FileManager.default
        let temp: URL = dest.appendingPathExtension("part")
        try? fm.removeItem(at: temp)
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<URL, Error> = .failure(TasteEngineError.badURL(remote.lastPathComponent))
        let delegate = DownloadDelegate(progress: progress) { r in
            result = r
            semaphore.signal()
        }
        let session = URLSession(configuration: TasteEngine.session.configuration, delegate: delegate, delegateQueue: nil)
        let task: URLSessionDownloadTask = session.downloadTask(with: remote)
        task.resume()
        semaphore.wait()
        session.finishTasksAndInvalidate()
        let location: URL = try result.get()
        try? fm.removeItem(at: dest)
        do {
            try fm.moveItem(at: location, to: dest)
        } catch {
            throw TasteEngineError.writeFailed(dest.lastPathComponent)
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
                finish(.failure(TasteEngineError.http(http.statusCode, name)))
                return
            }
            let keep: URL = location.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + "-" + name)
            do {
                try FileManager.default.moveItem(at: location, to: keep)
                finish(.success(keep))
            } catch {
                finish(.failure(TasteEngineError.writeFailed(name)))
            }
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            if let error { finish(.failure(error)) }
            else if !finished {
                let name: String = task.originalRequest?.url?.lastPathComponent ?? "asset"
                finish(.failure(TasteEngineError.writeFailed(name)))
            }
        }

        private func finish(_ r: Result<URL, Error>) {
            if finished { return }
            finished = true
            completion(r)
        }
    }

    static func sha256(of url: URL) throws -> String {
        let handle: FileHandle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let chunk: Data = handle.readData(ofLength: 4 << 20)
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        let digest = hasher.finalize()
        var hex: String = ""
        hex.reserveCapacity(64)
        for b in digest { hex += String(format: "%02x", b) }
        return hex
    }

    /// Reads a manifest of `{file: {bytes|size, sha256}}`, `{files: {...}}` or `{files: [{name, size, sha256}]}` shapes.
    static func parseManifest(_ url: URL) -> [String: (size: Int?, sha256: String?)] {
        var out: [String: (size: Int?, sha256: String?)] = [:]
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data, options: []) else { return out }
        func take(_ name: String, _ item: Any) {
            guard let d = item as? [String: Any] else { return }
            let size: Int? = ((d["size"] as? NSNumber) ?? (d["bytes"] as? NSNumber))?.intValue
            let sha: String? = (d["sha256"] as? String) ?? (d["sha"] as? String)
            if size != nil || sha != nil { out[name] = (size, sha) }
        }
        func scan(_ node: Any) {
            if let dict = node as? [String: Any] {
                for (k, v) in dict {
                    if let entry = v as? [String: Any], entry["sha256"] != nil || entry["size"] != nil || entry["bytes"] != nil {
                        take(k, entry)
                    } else if k == "files" || k == "assets" {
                        scan(v)
                    }
                }
            } else if let list = node as? [Any] {
                for item in list {
                    guard let d = item as? [String: Any] else { continue }
                    let name: String? = (d["name"] as? String) ?? (d["file"] as? String) ?? (d["path"] as? String)
                    if let name { take((name as NSString).lastPathComponent, d) }
                }
            }
        }
        scan(json)
        return out
    }

    static func message(for error: Error) -> String {
        if let e = error as? TasteEngineError { return e.errorDescription ?? "Install failed." }
        if error is CancellationError { return "Install cancelled." }
        if let u = error as? URLError {
            switch u.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost,
                 .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff:
                return "You're offline. Connect to the internet and try again."
            case .timedOut: return "The download timed out. Try again."
            case .cancelled: return "Install cancelled."
            default: return "Download failed (\(u.code.rawValue))."
            }
        }
        return error.localizedDescription
    }

    // MARK: Embeddings

    /// Cosine similarity of two vectors (0 when lengths differ or either is zero).
    static func cosine(_ a: [Float], _ b: [Float]) -> Float {
        let n: Int = min(a.count, b.count)
        guard n > 0 else { return 0 }
        var dot: Float = 0
        var na: Float = 0
        var nb: Float = 0
        for i in 0..<n {
            dot += a[i] * b[i]
            na += a[i] * a[i]
            nb += b[i] * b[i]
        }
        guard na > 0, nb > 0 else { return 0 }
        return dot / (na.squareRoot() * nb.squareRoot())
    }

    /// The unit CLIP embedding of an image (center-cropped and resized to 224). `key` enables an in-memory cache.
    func imageEmbedding(_ image: CGImage, key: String? = nil) -> [Float]? {
        if let key, let hit = imageCache.object(forKey: key as NSString) { return hit.values }
        guard let buffer = TasteEngine.pixelBuffer(image, side: TasteEngine.imageSide) else { return nil }
        lock.lock()
        defer { lock.unlock() }
        guard loadIfNeededLocked(), let model = imageModel else { return nil }
        let input: MLDictionaryFeatureProvider
        do {
            input = try MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: buffer)])
        } catch {
            return nil
        }
        guard let out = try? model.prediction(from: input),
              let array = out.featureValue(for: "embedding")?.multiArrayValue else { return nil }
        let v: [Float] = TasteEngine.floats(array)
        if let key { imageCache.setObject(Vector(v), forKey: key as NSString) }
        return v
    }

    /// The unit CLIP embedding of a text, cached by the string.
    func textEmbedding(_ text: String) -> [Float]? {
        if let hit = textCache.object(forKey: text as NSString) { return hit.values }
        lock.lock()
        defer { lock.unlock() }
        guard loadIfNeededLocked(), let model = textModel, let tokenizer else { return nil }
        let encoded: (ids: [Int32], mask: [Int32]) = tokenizer.encode(text, length: TasteEngine.contextLength)
        guard let ids = TasteEngine.int32Array(encoded.ids), let mask = TasteEngine.int32Array(encoded.mask) else { return nil }
        let input: MLDictionaryFeatureProvider
        do {
            input = try MLDictionaryFeatureProvider(dictionary: [
                "input_ids": MLFeatureValue(multiArray: ids),
                "attention_mask": MLFeatureValue(multiArray: mask)
            ])
        } catch {
            return nil
        }
        guard let out = try? model.prediction(from: input),
              let array = out.featureValue(for: "embedding")?.multiArrayValue else { return nil }
        let v: [Float] = TasteEngine.floats(array)
        textCache.setObject(Vector(v), forKey: text as NSString)
        return v
    }

    /// LAION aesthetic score of a unit image embedding mapped to 0...1 (`(raw - 3.5) / 4.5`, clamped).
    func aestheticScore(_ embedding: [Float]) -> Double? {
        lock.lock()
        _ = loadIfNeededLocked()
        let head: (weight: [Float], bias: Float)? = aestheticHead
        lock.unlock()
        guard let head, head.weight.count == embedding.count else { return nil }
        var raw: Float = head.bias
        for i in 0..<embedding.count { raw += head.weight[i] * embedding[i] }
        let mapped: Double = (Double(raw) - 3.5) / 4.5
        return min(1, max(0, mapped))
    }

    private static func int32Array(_ values: [Int32]) -> MLMultiArray? {
        guard let arr = try? MLMultiArray(shape: [1, NSNumber(value: values.count)], dataType: .int32) else { return nil }
        for (i, v) in values.enumerated() { arr[i] = NSNumber(value: v) }
        return arr
    }

    private static func floats(_ array: MLMultiArray) -> [Float] {
        let n: Int = array.count
        var out: [Float] = Array(repeating: 0, count: n)
        if array.dataType == .float32 {
            let p: UnsafeMutablePointer<Float> = array.dataPointer.bindMemory(to: Float.self, capacity: n)
            for i in 0..<n { out[i] = p[i] }
        } else {
            for i in 0..<n { out[i] = array[i].floatValue }
        }
        return out
    }

    /// Center-crops to a square and draws into a 224x224 BGRA pixel buffer.
    static func pixelBuffer(_ image: CGImage, side: Int) -> CVPixelBuffer? {
        let w: Int = image.width
        let h: Int = image.height
        guard w > 0, h > 0 else { return nil }
        let s: Int = min(w, h)
        let crop = CGRect(x: (w - s) / 2, y: (h - s) / 2, width: s, height: s)
        let square: CGImage = image.cropping(to: crop) ?? image
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
        let info: UInt32 = CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard let ctx = CGContext(data: base, width: side, height: side, bitsPerComponent: 8,
                                  bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: Gfx.sRGB, bitmapInfo: info) else {
            return nil
        }
        ctx.interpolationQuality = .high
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
        ctx.draw(square, in: CGRect(x: 0, y: 0, width: side, height: side))
        return buffer
    }

    // MARK: Zero-shot helpers

    private static func softmax(_ logits: [Double]) -> [Double] {
        guard let m = logits.max() else { return [] }
        var exps: [Double] = []
        exps.reserveCapacity(logits.count)
        var sum: Double = 0
        for l in logits {
            let e: Double = exp(l - m)
            exps.append(e)
            sum += e
        }
        guard sum > 0 else { return logits.map { _ in 1.0 / Double(max(1, logits.count)) } }
        return exps.map { $0 / sum }
    }

    /// Zero-shot genre probabilities for an image, best first (nil when the models aren't ready).
    func genreFit(_ image: CGImage, key: String? = nil) -> [(genre: Genre, score: Double)]? {
        guard let img = imageEmbedding(image, key: key) else { return nil }
        return genreFit(embedding: img)
    }

    // MARK: Calibration
    //
    // Raw CLIP similarities are sticky: some prompts ("nonfiction", "minimal") score high for every picture.
    // Every judgment here is read against a reference set of covers (two Signature designs per genre), so
    // what's reported is how much more than usual a cover reads as horror, foggy, or professional.

    private var calibrationLock = NSLock()
    private var referenceVectors: [[Float]]?
    private var genreBaselines: [Genre: Double] = [:]
    private var tagBaselines: [String: Float] = [:]
    private var proBaseline: Double?

    /// Image embeddings of the reference covers, computed once (about two seconds the first time).
    private func references() -> [[Float]] {
        calibrationLock.lock()
        if let r = referenceVectors { calibrationLock.unlock(); return r }
        calibrationLock.unlock()
        var picked: [SignatureDesign] = []
        for g in Genre.allCases {
            picked.append(contentsOf: SignatureLibrary.all.filter { $0.genre == g && !$0.usesPhoto }.prefix(2))
        }
        var vectors: [[Float]] = []
        for d in picked { if let v = designEmbedding(d) { vectors.append(v) } }
        calibrationLock.lock()
        referenceVectors = vectors
        calibrationLock.unlock()
        return vectors
    }

    private func genreBaseline(_ g: Genre, _ t: [Float]) -> Double {
        calibrationLock.lock()
        if let b = genreBaselines[g] { calibrationLock.unlock(); return b }
        calibrationLock.unlock()
        let refs = references()
        guard !refs.isEmpty else { return 0 }
        let mean = refs.reduce(0.0) { $0 + Double(TasteEngine.cosine($1, t)) * 100 } / Double(refs.count)
        calibrationLock.lock(); genreBaselines[g] = mean; calibrationLock.unlock()
        return mean
    }

    private func tagBaseline(_ tag: String, _ t: [Float]) -> Float {
        calibrationLock.lock()
        if let b = tagBaselines[tag] { calibrationLock.unlock(); return b }
        calibrationLock.unlock()
        let refs = references()
        guard !refs.isEmpty else { return 0 }
        let mean = refs.reduce(Float(0)) { $0 + TasteEngine.cosine($1, t) } / Float(refs.count)
        calibrationLock.lock(); tagBaselines[tag] = mean; calibrationLock.unlock()
        return mean
    }

    private func genreFit(embedding img: [Float]) -> [(genre: Genre, score: Double)]? {
        var genres: [Genre] = []
        var logits: [Double] = []
        if let head = genreHead {
            // Learned from real covers: a straight linear read of the embedding.
            for (i, g) in head.genres.enumerated() {
                var z: Float = head.bias[i]
                let w = head.weight[i]
                for k in 0..<min(w.count, img.count) { z += w[k] * img[k] }
                genres.append(g)
                logits.append(Double(z))
            }
            for g in Genre.allCases where !genres.contains(g) { genres.append(g); logits.append((logits.min() ?? 0) - 2) }
            let probs: [Double] = TasteEngine.softmax(logits)
            var out: [(genre: Genre, score: Double)] = []
            for (i, g) in genres.enumerated() { out.append((genre: g, score: probs[i])) }
            out.sort { $0.score > $1.score }
            return out
        }
        for g in Genre.allCases {
            guard let t = genreEmbedding(g) else { return nil }
            genres.append(g)
            logits.append(Double(TasteEngine.cosine(img, t)) * 100 - genreBaseline(g, t))
        }
        let probs: [Double] = TasteEngine.softmax(logits)
        var out: [(genre: Genre, score: Double)] = []
        for (i, g) in genres.enumerated() { out.append((genre: g, score: probs[i])) }
        out.sort { $0.score > $1.score }
        return out
    }

    /// The averaged, re-normalized embedding of a genre's prompts.
    private func genreEmbedding(_ g: Genre) -> [Float]? {
        let key = "genre:\(g.rawValue)" as NSString
        if let hit = textCache.object(forKey: key) { return hit.values }
        var sum = [Float](repeating: 0, count: 512)
        var n: Float = 0
        for p in TasteEngine.genrePrompts(g) {
            guard let e = textEmbedding(p), e.count == sum.count else { continue }
            for i in 0..<sum.count { sum[i] += e[i] }
            n += 1
        }
        guard n > 0 else { return nil }
        var norm: Float = 0
        for v in sum { norm += v * v }
        norm = max(1e-6, norm.squareRoot())
        let out = sum.map { $0 / norm }
        textCache.setObject(Vector(out), forKey: key)
        return out
    }

    /// The strongest mood tags for an image: the top `limit` by cosine, within 0.03 of the best.
    func moodTags(_ image: CGImage, key: String? = nil, limit: Int = 5) -> [String]? {
        guard let img = imageEmbedding(image, key: key) else { return nil }
        return moodTags(embedding: img, limit: limit)
    }

    private func moodTags(embedding img: [Float], limit: Int) -> [String]? {
        var scored: [(tag: String, score: Float)] = []
        for tag in TasteEngine.moodVocabulary {
            guard let t = textEmbedding("a \(tag) book cover") else { return nil }
            scored.append((tag: tag, score: TasteEngine.cosine(img, t) - tagBaseline(tag, t)))
        }
        scored.sort { $0.score > $1.score }
        guard let best = scored.first?.score else { return [] }
        var out: [String] = []
        // Only tags that stand out from the reference set, and within reach of the strongest one.
        for s in scored.prefix(max(0, limit)) where s.score > 0.004 && best - s.score <= 0.02 {
            out.append(s.tag)
        }
        return out
    }

    /// Probability (0...1) that the image reads as a professionally designed cover rather than an amateur one.
    func professionalism(_ image: CGImage, key: String? = nil) -> Double? {
        guard let img = imageEmbedding(image, key: key) else { return nil }
        return professionalism(embedding: img)
    }

    private func professionalism(embedding img: [Float]) -> Double? {
        guard let pro = textEmbedding(TasteEngine.professionalPrompt),
              let amateur = textEmbedding(TasteEngine.amateurPrompt) else { return nil }
        let diff = Double(TasteEngine.cosine(img, pro) - TasteEngine.cosine(img, amateur)) * 100
        calibrationLock.lock()
        let cached = proBaseline
        calibrationLock.unlock()
        let base: Double
        if let cached {
            base = cached
        } else {
            let refs = references()
            base = refs.isEmpty ? 0 : refs.reduce(0.0) { $0 + Double(TasteEngine.cosine($1, pro) - TasteEngine.cosine($1, amateur)) * 100 } / Double(refs.count)
            calibrationLock.lock(); proBaseline = base; calibrationLock.unlock()
        }
        // Half the reference set lands above 50; a cover that reads clearly better than the set approaches 90.
        return 1 / (1 + exp(-(diff - base) * 0.8))
    }

    /// Renders a document 224 px tall (preview quality) for embedding.
    static func thumbnail(_ doc: CoverDocument) -> CGImage? {
        let h: Double = Double(imageSide)
        let w: Double = max(1, (h / max(0.1, doc.canvas.aspect)).rounded())
        return CoverRenderer.shared.render(doc, size: CGSize(width: w, height: h), quality: .preview)
    }

    /// The full report for a document, or nil when the models aren't ready.
    func taste(of doc: CoverDocument) -> TasteReport? {
        guard isReady || TasteEngine.installed(in: modelsDirectory) else { return nil }
        guard let image = TasteEngine.thumbnail(doc), let img = imageEmbedding(image) else { return nil }
        guard let fit = genreFit(embedding: img),
              let tags = moodTags(embedding: img, limit: 5),
              let pro = professionalism(embedding: img) else { return nil }
        let own: Double = fit.first { $0.genre == doc.book.genre }?.score ?? 0
        return TasteReport(genreFit: fit, moodTags: tags, professionalism: pro,
                           aesthetic: aestheticScore(img), fitForBook: own)
    }

    // MARK: Signature search

    /// The embedding of a design's sample render, computed once per design id.
    func designEmbedding(_ d: SignatureDesign) -> [Float]? {
        let key: NSString = d.id as NSString
        if let hit = designCache.object(forKey: key) { return hit.values }
        let doc: CoverDocument = SignatureLibrary.build(d, palette: 0, base: SignatureLibrary.sampleDocument(d))
        guard let image = TasteEngine.thumbnail(doc), let v = imageEmbedding(image) else { return nil }
        designCache.setObject(Vector(v), forKey: key)
        return v
    }

    private var designBiases: [String: Float] = [:]
    private var promptSetVectors: [[Float]]?

    /// Mean similarity of a design to a broad set of prompts (genres and moods): its stickiness.
    private func designBias(_ d: SignatureDesign, _ v: [Float]) -> Float {
        calibrationLock.lock()
        if let b = designBiases[d.id] { calibrationLock.unlock(); return b }
        var prompts = promptSetVectors
        calibrationLock.unlock()
        if prompts == nil {
            var set: [[Float]] = []
            for g in Genre.allCases { if let e = genreEmbedding(g) { set.append(e) } }
            for tag in TasteEngine.moodVocabulary { if let e = textEmbedding("a \(tag) book cover") { set.append(e) } }
            calibrationLock.lock(); promptSetVectors = set; calibrationLock.unlock()
            prompts = set
        }
        guard let ps = prompts, !ps.isEmpty else { return 0 }
        let mean = ps.reduce(Float(0)) { $0 + TasteEngine.cosine(v, $1) } / Float(ps.count)
        calibrationLock.lock(); designBiases[d.id] = mean; calibrationLock.unlock()
        return mean
    }

    /// Designs ranked by how well their sample render matches a text query (empty when not ready).
    func search(_ query: String, in designs: [SignatureDesign], limit: Int = 12) -> [(design: SignatureDesign, score: Double)] {
        let q: String = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, let t = textEmbedding(q) else { return [] }
        // A design's usual similarity to any prompt is subtracted, so "sticky" designs don't top every search.
        var out: [(design: SignatureDesign, score: Double)] = []
        for d in designs {
            guard let v = designEmbedding(d) else { continue }
            out.append((design: d, score: Double(TasteEngine.cosine(v, t) - designBias(d, v))))
        }
        out.sort { $0.score > $1.score }
        if out.count > limit { out = Array(out.prefix(max(0, limit))) }
        return out
    }
}
