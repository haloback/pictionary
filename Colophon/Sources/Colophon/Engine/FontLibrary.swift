import AppKit
import CoreText
import Foundation
import Observation

/// Errors raised while fetching a Google Fonts family.
enum FontLibraryError: LocalizedError {
    case catalogMissing
    case badURL(String)
    case http(Int)
    case notAFont(String)
    case writeFailed(String)
    case registrationFailed(String)

    var errorDescription: String? {
        switch self {
        case .catalogMissing: return "The font catalog is missing from this copy of Colophon."
        case .badURL(let file): return "Couldn't build a download address for \(file)."
        case .http(let code): return "The font server answered \(code). Try again later."
        case .notAFont(let file): return "\(file) didn't download as a valid font."
        case .writeFailed(let file): return "Couldn't save \(file) to the font cache."
        case .registrationFailed(let file): return "macOS couldn't load \(file)."
        }
    }
}

/// Limits how many font files download at once.
private actor DownloadGate {
    private let limit: Int
    private var running: Int = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) { self.limit = limit }

    func acquire() async {
        if running < limit {
            running += 1
            return
        }
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            waiters.append(c)
        }
    }

    func release() {
        if waiters.isEmpty {
            running = max(0, running - 1)
        } else {
            // Hand the slot straight to the next waiter; `running` stays the same.
            let next: CheckedContinuation<Void, Never> = waiters.removeFirst()
            next.resume()
        }
    }
}

/// The Google Fonts collection (OFL / Apache 2.0 / UFL): a catalog ships with the app,
/// families download on demand from github.com/google/fonts, are cached and registered for this process.
@Observable
final class FontLibrary {
    static let shared = FontLibrary()

    struct Style: Hashable {
        let italic: Bool
        let weight: Int
        let file: String
        let postScriptName: String
    }

    struct Family: Identifiable, Hashable {
        let id: String
        let name: String
        let category: Category
        let designer: String
        let license: String
        let path: String
        let tags: [String]
        let styles: [Style]

        /// Distinct font files for this family (several styles can share one variable font file).
        var files: [String] {
            var seen: Set<String> = []
            var out: [String] = []
            for s in styles where !seen.contains(s.file) {
                seen.insert(s.file)
                out.append(s.file)
            }
            return out
        }
    }

    enum Category: String, CaseIterable, Identifiable {
        case serif
        case sans = "sans_serif"
        case display
        case handwriting
        case monospace

        var id: String { rawValue }

        var label: String {
            switch self {
            case .serif: return "Serif"
            case .sans: return "Sans"
            case .display: return "Display"
            case .handwriting: return "Handwriting"
            case .monospace: return "Mono"
            }
        }
    }

    enum State: Equatable {
        case notDownloaded
        case downloading
        case ready
        case failed(String)
    }

    /// ~/Library/Application Support/Colophon/Fonts/Google
    let cacheDirectory: URL

    // Observed state (mutated on the main thread only).
    private var transient: [String: State] = [:]
    private var registeredFiles: Set<String> = []

    // Unobserved bookkeeping, guarded by `lock` so it can be read from any thread.
    private let lock = NSLock()
    @ObservationIgnored private var loadedFamilies: [Family]?
    @ObservationIgnored private var commit: String = ""
    @ObservationIgnored private var fileForPostScript: [String: String] = [:]
    @ObservationIgnored private var namesInFile: [String: [String]] = [:]
    @ObservationIgnored private var inFlight: [String: Task<[String], Error>] = [:]
    private let gate = DownloadGate(limit: 4)

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 180
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    private init() {
        let support: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        cacheDirectory = support.appendingPathComponent("Colophon", isDirectory: true)
            .appendingPathComponent("Fonts", isDirectory: true)
            .appendingPathComponent("Google", isDirectory: true)
        let scan: (files: Set<String>, names: [String: [String]]) = FontLibrary.scanAndRegister(cacheDirectory)
        lock.lock()
        namesInFile = scan.names
        lock.unlock()
        registeredFiles = scan.files
    }

    // MARK: Catalog

    /// Every family in the catalog, sorted by name. Loaded on first use.
    var families: [Family] {
        lock.lock()
        defer { lock.unlock() }
        if let f = loadedFamilies { return f }
        let loaded: (commit: String, families: [Family]) = FontLibrary.loadCatalog()
        commit = loaded.commit
        loadedFamilies = loaded.families
        for family in loaded.families {
            for style in family.styles {
                let key: String = family.path + "/" + style.file
                if fileForPostScript[style.postScriptName] == nil { fileForPostScript[style.postScriptName] = key }
            }
        }
        // Names CoreText reported for files registered from the cache.
        for (key, names) in namesInFile {
            for n in names where fileForPostScript[n] == nil { fileForPostScript[n] = key }
        }
        return loaded.families
    }

    func family(named name: String) -> Family? {
        families.first { $0.name == name }
    }

    private static func catalogURL() -> URL? {
        var candidates: [URL] = []
        if let r = Bundle.main.resourceURL { candidates.append(r.appendingPathComponent("google-fonts.json")) }
        // Sources/Colophon/Engine/FontLibrary.swift -> package root -> Resources
        let source = URL(fileURLWithPath: #filePath)
        let root: URL = source.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        candidates.append(root.appendingPathComponent("Resources").appendingPathComponent("google-fonts.json"))
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        return nil
    }

    private static func loadCatalog() -> (commit: String, families: [Family]) {
        guard let url = catalogURL(),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let root = json as? [String: Any],
              let list = root["families"] as? [[String: Any]] else {
            return ("", [])
        }
        let commit: String = (root["commit"] as? String) ?? "main"
        var out: [Family] = []
        out.reserveCapacity(list.count)
        for item in list {
            guard let name = item["n"] as? String, let path = item["p"] as? String else { continue }
            let categoryRaw: String = (item["c"] as? String) ?? "display"
            let category: Category = Category(rawValue: categoryRaw) ?? .display
            var styles: [Style] = []
            if let fonts = item["f"] as? [[Any]] {
                for f in fonts where f.count >= 4 {
                    guard let styleName = f[0] as? String,
                          let file = f[2] as? String,
                          let ps = f[3] as? String else { continue }
                    var weight: Int = 400
                    if let n = f[1] as? NSNumber { weight = n.intValue } else if let i = f[1] as? Int { weight = i }
                    styles.append(Style(italic: styleName == "italic", weight: weight, file: file, postScriptName: ps))
                }
            }
            guard !styles.isEmpty else { continue }
            styles.sort { a, b in
                if a.weight != b.weight { return a.weight < b.weight }
                return !a.italic && b.italic
            }
            out.append(Family(id: name,
                              name: name,
                              category: category,
                              designer: (item["d"] as? String) ?? "",
                              license: (item["l"] as? String) ?? "OFL",
                              path: path,
                              tags: (item["k"] as? [String]) ?? [],
                              styles: styles))
        }
        out.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return (commit, out)
    }

    private var catalogCommit: String {
        _ = families
        lock.lock()
        defer { lock.unlock() }
        return commit
    }

    // MARK: Queries

    func state(of family: Family) -> State {
        if let s = transient[family.id] { return s }
        let files: [String] = family.files
        if files.isEmpty { return .notDownloaded }
        for f in files where !registeredFiles.contains(family.path + "/" + f) {
            return .notDownloaded
        }
        return .ready
    }

    func search(_ query: String, category: Category?) -> [Family] {
        let q: String = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var pool: [Family] = families
        if let category { pool = pool.filter { $0.category == category } }
        guard !q.isEmpty else { return pool }
        var prefix: [Family] = []
        var other: [Family] = []
        for f in pool {
            let name: String = f.name.lowercased()
            if name.hasPrefix(q) {
                prefix.append(f)
            } else if name.contains(q)
                        || f.designer.lowercased().contains(q)
                        || f.tags.contains(where: { $0.lowercased().contains(q) })
                        || f.category.label.lowercased() == q {
                other.append(f)
            }
        }
        return prefix + other
    }

    /// Best default style for a family (regular 400 upright, else closest).
    func defaultStyle(_ family: Family) -> Style {
        var best: Style? = nil
        var bestScore: Int = Int.max
        for s in family.styles {
            let score: Int = (s.italic ? 1000 : 0) + abs(s.weight - 400) * 2 + (s.weight < 400 ? 1 : 0)
            if score < bestScore {
                bestScore = score
                best = s
            }
        }
        return best ?? Style(italic: false, weight: 400, file: "", postScriptName: family.name)
    }

    /// The PostScript name to use for a style once it's registered: the catalog name if
    /// CoreText resolves it, otherwise the name CoreText reported for the style's file.
    func resolvedName(_ style: Style, in family: Family) -> String {
        if NSFont(name: style.postScriptName, size: 12) != nil { return style.postScriptName }
        let key: String = family.path + "/" + style.file
        lock.lock()
        let names: [String] = namesInFile[key] ?? []
        lock.unlock()
        for n in names where NSFont(name: n, size: 12) != nil { return n }
        return style.postScriptName
    }

    /// PostScript names of a ready family that can be used right now, in style order.
    func availableNames(_ family: Family) -> [String] {
        var out: [String] = []
        for s in family.styles {
            let n: String = resolvedName(s, in: family)
            if !out.contains(n) && NSFont(name: n, size: 12) != nil { out.append(n) }
        }
        return out
    }

    /// Raw font file data for a PostScript name if it came from this library (for embedding in documents).
    func fontData(postScriptName: String) -> Data? {
        _ = families
        lock.lock()
        let key: String? = fileForPostScript[postScriptName]
        lock.unlock()
        guard let key else { return nil }
        let url: URL = cacheDirectory.appendingPathComponent(key)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? Data(contentsOf: url)
    }

    // MARK: Install

    /// Downloads (if needed) and registers the family; returns PostScript names now usable with NSFont(name:size:).
    @MainActor
    func install(_ family: Family) async throws -> [String] {
        if state(of: family) == .ready { return availableNames(family) }
        if let running = inFlight[family.id] { return try await running.value }
        let task: Task<[String], Error> = Task { @MainActor in
            try await self.performInstall(family)
        }
        inFlight[family.id] = task
        defer { inFlight[family.id] = nil }
        return try await task.value
    }

    @MainActor
    private func performInstall(_ family: Family) async throws -> [String] {
        transient[family.id] = .downloading
        do {
            let commit: String = catalogCommit
            guard !commit.isEmpty else { throw FontLibraryError.catalogMissing }
            var jobs: [(key: String, remote: URL, dest: URL)] = []
            for file in family.files {
                let key: String = family.path + "/" + file
                if registeredFiles.contains(key) { continue }
                guard let remote = FontLibrary.remoteURL(commit: commit, path: family.path, file: file) else {
                    throw FontLibraryError.badURL(file)
                }
                jobs.append((key: key, remote: remote, dest: cacheDirectory.appendingPathComponent(key)))
            }
            let gate: DownloadGate = self.gate
            let results: [(String, [String])] = try await withThrowingTaskGroup(of: (String, [String]).self) { group in
                for job in jobs {
                    let key: String = job.key
                    let remote: URL = job.remote
                    let dest: URL = job.dest
                    group.addTask {
                        let names: [String] = try await FontLibrary.fetchAndRegister(remote: remote, dest: dest, gate: gate)
                        return (key, names)
                    }
                }
                var out: [(String, [String])] = []
                for try await item in group { out.append(item) }
                return out
            }
            lock.lock()
            for (key, names) in results {
                namesInFile[key] = names
                for n in names where fileForPostScript[n] == nil { fileForPostScript[n] = key }
            }
            lock.unlock()
            var files: Set<String> = registeredFiles
            for (key, _) in results { files.insert(key) }
            registeredFiles = files
            transient[family.id] = nil
            return availableNames(family)
        } catch {
            transient[family.id] = .failed(FontLibrary.message(for: error))
            throw error
        }
    }

    /// Registers everything already cached (call at launch; cheap).
    func registerCached() {
        let scan: (files: Set<String>, names: [String: [String]]) = FontLibrary.scanAndRegister(cacheDirectory)
        lock.lock()
        for (key, names) in scan.names {
            namesInFile[key] = names
            if loadedFamilies != nil {
                for n in names where fileForPostScript[n] == nil { fileForPostScript[n] = key }
            }
        }
        lock.unlock()
        let found: Set<String> = scan.files
        if Thread.isMainThread {
            markRegistered(found)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.markRegistered(found)
            }
        }
    }

    private func markRegistered(_ found: Set<String>) {
        if !found.isSubset(of: registeredFiles) {
            registeredFiles = registeredFiles.union(found)
        }
    }

    // MARK: Helpers (nonisolated, run off the main thread)

    private static let unreserved: CharacterSet = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    private static func encode(_ component: String) -> String {
        component.addingPercentEncoding(withAllowedCharacters: unreserved) ?? component
    }

    static func remoteURL(commit: String, path: String, file: String) -> URL? {
        let encodedPath: String = path.split(separator: "/").map { encode(String($0)) }.joined(separator: "/")
        return URL(string: "https://raw.githubusercontent.com/google/fonts/\(encode(commit))/\(encodedPath)/\(encode(file))")
    }

    private static func fetchAndRegister(remote: URL, dest: URL, gate: DownloadGate) async throws -> [String] {
        let fm = FileManager.default
        if !fm.fileExists(atPath: dest.path) {
            await gate.acquire()
            let result: (Data, URLResponse)
            do {
                result = try await session.data(from: remote)
            } catch {
                await gate.release()
                throw error
            }
            await gate.release()
            let data: Data = result.0
            let response: URLResponse = result.1
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                throw FontLibraryError.http(http.statusCode)
            }
            let fileName: String = dest.lastPathComponent
            guard isFont(data) else { throw FontLibraryError.notAFont(fileName) }
            do {
                try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                try data.write(to: dest, options: [.atomic])
            } catch {
                throw FontLibraryError.writeFailed(fileName)
            }
        }
        guard let names = register(dest) else {
            throw FontLibraryError.registrationFailed(dest.lastPathComponent)
        }
        return names
    }

    private static func isFont(_ data: Data) -> Bool {
        guard data.count > 12, let provider = CGDataProvider(data: data as CFData) else { return false }
        return CGFont(provider) != nil
    }

    /// Registers one cached file with CoreText; returns the PostScript names it contains, or nil if unusable.
    private static func register(_ url: URL) -> [String]? {
        var error: Unmanaged<CFError>?
        let ok: Bool = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        var names: [String] = []
        if let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] {
            for d in descriptors {
                if let n = CTFontDescriptorCopyAttribute(d, kCTFontNameAttribute) as? String, !names.contains(n) {
                    names.append(n)
                }
            }
        }
        if !ok {
            // Already registered is fine; anything else means the file is unusable.
            var alreadyRegistered: Bool = false
            if let e = error?.takeRetainedValue() {
                alreadyRegistered = CFErrorGetCode(e) == CFIndex(CTFontManagerError.alreadyRegistered.rawValue)
            }
            if !alreadyRegistered && names.isEmpty { return nil }
        }
        return names
    }

    private static func scanAndRegister(_ dir: URL) -> (files: Set<String>, names: [String: [String]]) {
        var files: Set<String> = []
        var names: [String: [String]] = [:]
        let fm = FileManager.default
        guard fm.fileExists(atPath: dir.path),
              let walker = fm.enumerator(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return (files, names)
        }
        let base: String = dir.resolvingSymlinksInPath().path
        let prefix: String = base.hasSuffix("/") ? base : base + "/"
        while let next = walker.nextObject() {
            guard let url = next as? URL else { continue }
            let ext: String = url.pathExtension.lowercased()
            guard ext == "ttf" || ext == "otf" else { continue }
            let full: String = url.resolvingSymlinksInPath().path
            guard full.hasPrefix(prefix) else { continue }
            let key: String = String(full.dropFirst(prefix.count))
            if let found = register(url) {
                files.insert(key)
                names[key] = found
            }
        }
        return (files, names)
    }

    static func message(for error: Error) -> String {
        if let e = error as? FontLibraryError { return e.errorDescription ?? "Download failed." }
        if error is CancellationError { return "Download cancelled." }
        if let u = error as? URLError {
            switch u.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost,
                 .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff:
                return "You're offline. Connect to the internet and try again."
            case .timedOut:
                return "The download timed out. Try again."
            case .cancelled:
                return "Download cancelled."
            default:
                return "Download failed (\(u.code.rawValue))."
            }
        }
        return error.localizedDescription
    }
}
