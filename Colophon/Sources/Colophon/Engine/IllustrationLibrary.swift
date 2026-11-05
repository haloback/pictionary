import AppKit
import CoreGraphics
import Foundation
import Observation

/// A recolorable silhouette or line icon from `IllustrationLibrary`.
struct IllustrationContent: Codable, Hashable {
    var itemID: String
    var color: RGBA
    /// Optional second color: the silhouette is filled with a top-to-bottom gradient from `color` to `color2`.
    var color2: RGBA? = nil
    var flipped: Bool = false
}

extension IllustrationContent {
    // Declared in an extension so the memberwise initializer stays available.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(itemID: try c.decodeIfPresent(String.self, forKey: .itemID) ?? "",
                  color: try c.decodeIfPresent(RGBA.self, forKey: .color) ?? .nearWhite)
        color2 = try c.decodeIfPresent(RGBA.self, forKey: .color2)
        flipped = try c.decodeIfPresent(Bool.self, forKey: .flipped) ?? false
    }
}

enum IllustrationLibraryError: LocalizedError {
    case http(Int)
    case unzipFailed(String)
    case noAsset

    var errorDescription: String? {
        switch self {
        case .http(let code): return "The download server answered \(code). Try again later."
        case .unzipFailed(let why): return "Couldn't unpack the illustration pack: \(why)"
        case .noAsset: return "Couldn't find a download for this pack."
        }
    }
}

/// Thousands of monochrome SVG icons and silhouettes (Tabler, Phosphor, Game-icons.net), downloaded once per pack
/// into Application Support, indexed by name and motif synonyms, and rendered tinted at any size.
@Observable
final class IllustrationLibrary {
    static let shared = IllustrationLibrary()

    enum Style: String, Codable, CaseIterable, Identifiable {
        case outline, filled
        var id: String { rawValue }
        var label: String { self == .outline ? "Outline" : "Filled" }
    }

    struct Pack: Identifiable, Hashable {
        let id: String
        let name: String
        let license: String
        /// What must be printed when items from this pack are used; empty when nothing is required.
        let attribution: String
        let url: URL
        var isInstalled: Bool
        /// Rough download size for the browser chips.
        let approximateSize: String
    }

    struct Item: Identifiable, Hashable, Codable {
        /// "tabler.outline.sword", "phosphor.fill.sword", "gameicons.lorc.broadsword".
        let id: String
        let name: String
        let pack: String
        /// Relative to the pack's folder.
        let path: String
        let tags: [String]
        let style: Style
        /// Game-icons.net only: the folder name, which is the artist to credit.
        var artist: String? = nil

        static func == (a: Item, b: Item) -> Bool { a.id == b.id }
        func hash(into h: inout Hasher) { h.combine(id) }
    }

    enum State: Equatable {
        case notInstalled
        case downloading(String)
        case ready
        case failed(String)
    }

    static let tablerFallbackURL = URL(string: "https://github.com/tabler/tabler-icons/releases/download/v3.34.1/tabler-icons-3.34.1.zip")!
    static let gameIconsURL = URL(string: "https://game-icons.net/archives/svg/zip/000000/transparent/game-icons.net.svg.zip")!
    static let phosphorURL = URL(string: "https://github.com/phosphor-icons/core/archive/refs/heads/main.zip")!

    /// ~/Library/Application Support/Colophon/Illustrations
    let directory: URL

    private(set) var packs: [Pack] = []
    private(set) var items: [Item] = []
    private(set) var states: [String: State] = [:]

    @ObservationIgnored private var index: [String: Item] = [:]
    @ObservationIgnored private var inFlight: [String: Task<Void, Error>] = [:]
    @ObservationIgnored private let thumbs = NSCache<NSString, CGImage>()
    @ObservationIgnored private let lock = NSLock()

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 900
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    private init() {
        let support: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        directory = support.appendingPathComponent("Colophon", isDirectory: true)
            .appendingPathComponent("Illustrations", isDirectory: true)
        thumbs.countLimit = 1500
        packs = [
            Pack(id: "tabler", name: "Tabler Icons", license: "MIT", attribution: "", url: IllustrationLibrary.tablerFallbackURL,
                 isInstalled: false, approximateSize: "about 15 MB"),
            Pack(id: "gameicons", name: "Game-icons.net", license: "CC BY 3.0",
                 attribution: "game-icons.net, CC BY 3.0", url: IllustrationLibrary.gameIconsURL,
                 isInstalled: false, approximateSize: "about 30 MB"),
            Pack(id: "phosphor", name: "Phosphor Icons", license: "MIT", attribution: "", url: IllustrationLibrary.phosphorURL,
                 isInstalled: false, approximateSize: "about 45 MB")
        ]
        for p in packs { states[p.id] = .notInstalled }
        loadCachedIndexes()
    }

    // MARK: Packs

    func pack(_ id: String) -> Pack? { packs.first { $0.id == id } }

    func state(of pack: Pack) -> State { states[pack.id] ?? .notInstalled }

    func packDirectory(_ packID: String) -> URL { directory.appendingPathComponent(packID, isDirectory: true) }

    private func indexURL(_ packID: String) -> URL { packDirectory(packID).appendingPathComponent("index.json") }

    /// Loads every pack's `index.json` (fast; no file walking).
    private func loadCachedIndexes() {
        for i in packs.indices {
            let url = indexURL(packs[i].id)
            guard let data = try? Data(contentsOf: url),
                  let decoded = try? JSONDecoder().decode([Item].self, from: data) else { continue }
            packs[i].isInstalled = true
            states[packs[i].id] = .ready
            register(items: decoded)
        }
    }

    /// Adds items to the searchable index (also used by tests to insert synthetic items without any download).
    func register(items new: [Item]) {
        lock.lock()
        var added: [Item] = []
        for it in new where index[it.id] == nil {
            index[it.id] = it
            added.append(it)
        }
        lock.unlock()
        if !added.isEmpty { items.append(contentsOf: added) }
    }

    func item(_ id: String) -> Item? {
        lock.lock()
        defer { lock.unlock() }
        return index[id]
    }

    func fileURL(for item: Item) -> URL { packDirectory(item.pack).appendingPathComponent(item.path) }

    // MARK: Install

    @MainActor
    func install(_ pack: Pack) async throws {
        if state(of: pack) == .ready { return }
        if let running = inFlight[pack.id] { return try await running.value }
        let task: Task<Void, Error> = Task { @MainActor in
            try await self.performInstall(pack)
        }
        inFlight[pack.id] = task
        defer { inFlight[pack.id] = nil }
        try await task.value
    }

    @MainActor
    private func performInstall(_ pack: Pack) async throws {
        states[pack.id] = .downloading("Finding the download…")
        do {
            let remote: URL = try await IllustrationLibrary.resolveURL(for: pack)
            states[pack.id] = .downloading("Downloading \(pack.name)…")
            let (tmp, response) = try await IllustrationLibrary.session.download(from: remote)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                throw IllustrationLibraryError.http(http.statusCode)
            }
            let fm = FileManager.default
            let dir = packDirectory(pack.id)
            try? fm.removeItem(at: dir)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let zip = directory.appendingPathComponent("\(pack.id).zip")
            try? fm.removeItem(at: zip)
            try fm.moveItem(at: tmp, to: zip)
            states[pack.id] = .downloading("Unpacking \(pack.name)…")
            try await IllustrationLibrary.unzip(zip, into: dir)
            try? fm.removeItem(at: zip)
            states[pack.id] = .downloading("Indexing \(pack.name)…")
            let packID: String = pack.id
            let found: [Item] = await Task.detached(priority: .userInitiated) {
                IllustrationLibrary.indexPack(packID, at: dir)
            }.value
            if let data = try? JSONEncoder().encode(found) {
                try? data.write(to: indexURL(pack.id), options: .atomic)
            }
            register(items: found)
            if let i = packs.firstIndex(where: { $0.id == pack.id }) { packs[i].isInstalled = true }
            states[pack.id] = .ready
        } catch {
            states[pack.id] = .failed(error.localizedDescription)
            throw error
        }
    }

    /// Tabler publishes a versioned zip per release, so the name is looked up: GitHub's API first, then the
    /// `releases/latest` redirect, then a pinned version.
    private static func resolveURL(for pack: Pack) async throws -> URL {
        guard pack.id == "tabler" else { return pack.url }
        if let api = URL(string: "https://api.github.com/repos/tabler/tabler-icons/releases/latest"),
           let (data, resp) = try? await session.data(from: api),
           (resp as? HTTPURLResponse).map({ $0.statusCode < 400 }) ?? true,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let assets = json["assets"] as? [[String: Any]] {
            for a in assets {
                if let name = a["name"] as? String, name.hasSuffix(".zip"),
                   let s = a["browser_download_url"] as? String, let u = URL(string: s) { return u }
            }
        }
        // Follow the redirect of releases/latest to learn the tag ("v3.50.0") and build the asset name.
        if let latest = URL(string: "https://github.com/tabler/tabler-icons/releases/latest") {
            var req = URLRequest(url: latest)
            req.httpMethod = "HEAD"
            if let (_, resp) = try? await session.data(for: req), let landed = resp.url,
               landed.lastPathComponent.hasPrefix("v") {
                let ver = String(landed.lastPathComponent.dropFirst())
                if let u = URL(string: "https://github.com/tabler/tabler-icons/releases/download/v\(ver)/tabler-icons-\(ver).zip") {
                    return u
                }
            }
        }
        return pack.url
    }

    private static func unzip(_ zip: URL, into dir: URL) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                p.arguments = ["-x", "-k", zip.path, dir.path]
                let err = Pipe()
                p.standardError = err
                p.standardOutput = FileHandle.nullDevice
                do {
                    try p.run()
                    p.waitUntilExit()
                } catch {
                    cont.resume(throwing: IllustrationLibraryError.unzipFailed(error.localizedDescription))
                    return
                }
                if p.terminationStatus != 0 {
                    let msg = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    cont.resume(throwing: IllustrationLibraryError.unzipFailed(msg.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else {
                    cont.resume()
                }
            }
        }
    }

    // MARK: Indexing

    /// Walks a pack folder and builds its items. Pure; safe off the main thread.
    static func indexPack(_ packID: String, at dir: URL) -> [Item] {
        let fm = FileManager.default
        guard let walker = fm.enumerator(at: dir, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { return [] }
        var out: [Item] = []
        var seen: Set<String> = []
        let base = dir.standardizedFileURL.path
        while let url = walker.nextObject() as? URL {
            guard url.pathExtension.lowercased() == "svg" else { continue }
            let full = url.standardizedFileURL.path
            guard full.hasPrefix(base) else { continue }
            var rel = String(full.dropFirst(base.count))
            if rel.hasPrefix("/") { rel.removeFirst() }
            guard let it = classify(packID: packID, relativePath: rel) else { continue }
            if seen.insert(it.id).inserted { out.append(it) }
        }
        out.sort { $0.name < $1.name }
        return out
    }

    /// Decides whether a file in a pack is an icon we show, and names/tags it.
    static func classify(packID: String, relativePath rel: String) -> Item? {
        let parts = rel.split(separator: "/").map(String.init)
        guard let file = parts.last else { return nil }
        let folders = parts.dropLast().map { $0.lowercased() }
        var slug = String(file.dropLast(4)).lowercased()
        var style: Style = .filled
        var artist: String? = nil
        let id: String
        switch packID {
        case "tabler":
            if folders.contains("filled") { style = .filled }
            else if folders.contains("outline") { style = .outline }
            else { return nil }
            if slug.hasSuffix("-filled") { slug = String(slug.dropLast(7)) }
            id = "tabler.\(style.rawValue).\(slug)"
        case "phosphor":
            if folders.contains("fill") {
                style = .filled
                if slug.hasSuffix("-fill") { slug = String(slug.dropLast(5)) }
            } else if folders.contains("regular") {
                style = .outline
            } else { return nil }
            id = "phosphor.\(style.rawValue).\(slug)"
        case "gameicons":
            guard let a = folders.last, !a.isEmpty else { return nil }
            artist = a
            style = .filled
            id = "gameicons.\(a).\(slug)"
        default:
            id = "\(packID).\(style.rawValue).\(slug)"
        }
        let name = displayName(slug)
        var tags = IllustrationLibrary.tags(forSlug: slug)
        tags.append(packID)
        if let artist { tags.append(artist.lowercased()) }
        return Item(id: id, name: name, pack: packID, path: rel, tags: tags, style: style, artist: artist)
    }

    static func displayName(_ slug: String) -> String {
        slug.split(whereSeparator: { $0 == "-" || $0 == "_" || $0 == " " })
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    static func words(_ s: String) -> [String] {
        s.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    /// The file name's words, their singular forms and every synonym/motif they map to.
    static func tags(forSlug slug: String) -> [String] {
        var out: [String] = []
        var seen: Set<String> = []
        func add(_ w: String) {
            if !w.isEmpty, seen.insert(w).inserted { out.append(w) }
        }
        for w in words(slug) {
            add(w)
            let s = singular(w)
            add(s)
            for syn in synonyms[s] ?? synonyms[w] ?? [] { add(syn) }
        }
        return out
    }

    static func singular(_ w: String) -> String {
        if w.hasSuffix("ies"), w.count > 4 { return String(w.dropLast(3)) + "y" }
        if w.hasSuffix("ses") || w.hasSuffix("xes") || w.hasSuffix("ches") || w.hasSuffix("shes") { return String(w.dropLast(2)) }
        if w.hasSuffix("s"), !w.hasSuffix("ss"), w.count > 3 { return String(w.dropLast()) }
        return w
    }

    /// Words found in icon names, mapped to the cover motifs and genres a designer would search for.
    static let synonyms: [String: [String]] = [
        "sword": ["fantasy", "epic", "blade", "weapon", "knight", "battle"],
        "dagger": ["thriller", "crime", "blade", "weapon", "assassin"],
        "knife": ["thriller", "crime", "horror", "blade", "weapon"],
        "axe": ["fantasy", "viking", "weapon", "lumber"],
        "bow": ["fantasy", "archer", "weapon", "hunt"],
        "arrow": ["direction", "archer", "hunt", "fantasy"],
        "shield": ["fantasy", "knight", "protection", "heraldry", "epic"],
        "helmet": ["knight", "warrior", "fantasy", "viking"],
        "armor": ["knight", "warrior", "fantasy"],
        "spear": ["fantasy", "warrior", "weapon"],
        "gun": ["thriller", "crime", "noir", "weapon", "pistol"],
        "pistol": ["thriller", "crime", "noir", "weapon", "gun"],
        "rifle": ["thriller", "war", "weapon", "hunt"],
        "bullet": ["thriller", "crime", "noir"],
        "bomb": ["thriller", "war", "explosion"],
        "skull": ["horror", "death", "pirate", "gothic", "danger", "poison"],
        "bone": ["horror", "death", "skeleton"],
        "skeleton": ["horror", "death", "bone"],
        "ghost": ["horror", "haunted", "spirit", "paranormal"],
        "zombie": ["horror", "undead"],
        "vampire": ["horror", "gothic", "paranormal", "fangs"],
        "bat": ["horror", "gothic", "night", "vampire"],
        "spider": ["horror", "web", "creepy"],
        "web": ["spider", "horror", "trap", "network"],
        "coffin": ["horror", "death", "gothic", "funeral"],
        "grave": ["horror", "death", "cemetery", "gothic"],
        "tombstone": ["horror", "death", "cemetery", "gothic"],
        "blood": ["horror", "thriller", "crime", "drop"],
        "scythe": ["horror", "death", "reaper", "harvest"],
        "heart": ["romance", "love", "valentine", "passion"],
        "hearts": ["romance", "love"],
        "kiss": ["romance", "love", "lips"],
        "lips": ["romance", "kiss", "beauty"],
        "ring": ["romance", "wedding", "engagement", "marriage", "jewel"],
        "rose": ["romance", "love", "flower", "gothic", "beauty"],
        "flower": ["romance", "cozy", "garden", "spring", "floral", "botanical"],
        "tulip": ["flower", "spring", "garden", "cozy"],
        "lily": ["flower", "funeral", "purity"],
        "lotus": ["flower", "zen", "meditation", "calm"],
        "sunflower": ["flower", "summer", "cozy", "cheerful"],
        "leaf": ["nature", "botanical", "autumn", "garden", "eco"],
        "tree": ["nature", "forest", "literary", "family", "growth"],
        "forest": ["nature", "trees", "wild", "fantasy", "fairy"],
        "pine": ["forest", "winter", "christmas", "nature"],
        "palm": ["beach", "tropical", "summer", "island", "vacation"],
        "cactus": ["desert", "western", "southwest"],
        "mushroom": ["forest", "fairy", "fantasy", "cottagecore", "cozy"],
        "acorn": ["autumn", "forest", "nature"],
        "wheat": ["harvest", "farm", "rural", "historical", "bread"],
        "rocket": ["scifi", "space", "launch", "future", "startup"],
        "planet": ["scifi", "space", "astronomy", "cosmos"],
        "alien": ["scifi", "space", "ufo"],
        "ufo": ["scifi", "space", "alien"],
        "robot": ["scifi", "ai", "android", "future", "tech"],
        "satellite": ["scifi", "space", "orbit", "signal"],
        "astronaut": ["scifi", "space"],
        "galaxy": ["scifi", "space", "cosmos", "stars"],
        "atom": ["science", "physics", "scifi", "nonfiction"],
        "dna": ["science", "biology", "thriller", "genetics", "nonfiction"],
        "microscope": ["science", "lab", "nonfiction"],
        "flask": ["science", "potion", "lab", "chemistry", "alchemy"],
        "potion": ["fantasy", "magic", "witch", "alchemy", "flask"],
        "cauldron": ["witch", "magic", "fantasy", "halloween"],
        "wand": ["magic", "fantasy", "wizard", "fairy"],
        "crystal": ["magic", "fantasy", "gem", "mystic"],
        "gem": ["jewel", "treasure", "fantasy", "luxury", "diamond"],
        "diamond": ["jewel", "luxury", "gem", "wedding"],
        "teacup": ["cozy", "tea", "comfort", "afternoon", "british"],
        "teapot": ["cozy", "tea", "comfort", "afternoon", "british"],
        "tea": ["cozy", "comfort", "teacup"],
        "cup": ["cozy", "coffee", "tea", "cafe"],
        "coffee": ["cozy", "cafe", "morning", "comfort"],
        "mug": ["cozy", "coffee", "tea", "comfort"],
        "cake": ["cozy", "bakery", "birthday", "sweet", "dessert"],
        "cookie": ["cozy", "bakery", "sweet", "dessert"],
        "cupcake": ["cozy", "bakery", "sweet", "dessert"],
        "bread": ["bakery", "cozy", "kitchen", "food"],
        "croissant": ["bakery", "french", "paris", "cozy"],
        "pie": ["cozy", "bakery", "dessert", "homemade"],
        "wine": ["romance", "dinner", "vineyard", "glass"],
        "beer": ["pub", "tavern", "drink"],
        "cocktail": ["noir", "glamour", "party", "drink", "bar"],
        "bottle": ["drink", "message", "potion", "wine"],
        "feather": ["literary", "historical", "quill", "writing", "poetry", "angel"],
        "quill": ["literary", "historical", "writing", "author", "poetry", "feather"],
        "pen": ["literary", "writing", "author", "journal"],
        "pencil": ["writing", "sketch", "school", "draw"],
        "ink": ["literary", "writing", "calligraphy", "tattoo"],
        "typewriter": ["literary", "writer", "vintage", "noir", "memoir"],
        "book": ["literary", "library", "reading", "story", "school", "knowledge"],
        "books": ["literary", "library", "reading"],
        "scroll": ["historical", "fantasy", "ancient", "document", "parchment"],
        "letter": ["romance", "historical", "mail", "envelope", "correspondence"],
        "envelope": ["letter", "mail", "message", "romance"],
        "stamp": ["mail", "vintage", "travel", "historical"],
        "crown": ["royal", "fantasy", "king", "queen", "monarchy", "historical"],
        "throne": ["royal", "fantasy", "king", "queen", "power"],
        "castle": ["fantasy", "medieval", "royal", "gothic", "historical"],
        "tower": ["fantasy", "gothic", "castle", "landmark"],
        "scepter": ["royal", "fantasy", "king", "power"],
        "raven": ["gothic", "horror", "omen", "bird", "poe", "dark"],
        "crow": ["gothic", "horror", "omen", "bird", "dark"],
        "owl": ["wisdom", "night", "mystery", "forest", "bird"],
        "bird": ["freedom", "nature", "flight", "literary"],
        "dove": ["peace", "romance", "wedding", "bird", "hope"],
        "swan": ["romance", "grace", "lake", "ballet", "bird"],
        "eagle": ["america", "power", "freedom", "bird", "patriotic"],
        "butterfly": ["transformation", "romance", "spring", "literary", "garden"],
        "bee": ["garden", "honey", "cozy", "busy", "summer"],
        "dragon": ["fantasy", "epic", "myth", "fire", "medieval"],
        "dragonfly": ["summer", "pond", "nature", "lake"],
        "wolf": ["fantasy", "wild", "howl", "moon", "thriller", "pack", "werewolf"],
        "fox": ["cunning", "forest", "fairy", "fable", "autumn"],
        "bear": ["wild", "forest", "mountain", "strength"],
        "deer": ["forest", "nature", "stag", "hunt", "gentle"],
        "stag": ["forest", "nature", "deer", "hunt", "fantasy"],
        "horse": ["western", "historical", "ride", "cavalry", "regency"],
        "unicorn": ["fantasy", "magic", "fairy", "rainbow"],
        "cat": ["cozy", "witch", "mystery", "pet", "curious"],
        "dog": ["cozy", "loyal", "pet", "companion", "friendship"],
        "rabbit": ["spring", "easter", "fairy", "cozy", "bunny"],
        "snake": ["danger", "poison", "temptation", "thriller", "serpent"],
        "serpent": ["danger", "myth", "fantasy", "snake"],
        "lion": ["courage", "royal", "heraldry", "africa", "pride"],
        "fish": ["ocean", "sea", "fishing", "coastal"],
        "shark": ["ocean", "danger", "thriller", "sea"],
        "whale": ["ocean", "sea", "literary", "voyage"],
        "octopus": ["sea", "ocean", "kraken", "horror", "tentacle"],
        "kraken": ["sea", "ocean", "monster", "fantasy", "horror"],
        "shell": ["beach", "ocean", "coastal", "summer"],
        "key": ["mystery", "secret", "unlock", "door", "antique", "treasure"],
        "lock": ["mystery", "secret", "security", "locked", "thriller"],
        "door": ["mystery", "threshold", "entrance", "portal", "home"],
        "window": ["home", "view", "light", "literary"],
        "house": ["home", "cozy", "family", "suburb", "haunted"],
        "home": ["house", "cozy", "family"],
        "lighthouse": ["coastal", "sea", "hope", "guide", "literary"],
        "bridge": ["connection", "city", "journey", "literary"],
        "church": ["faith", "gothic", "historical", "wedding"],
        "city": ["urban", "skyline", "thriller", "contemporary"],
        "building": ["city", "urban", "architecture"],
        "moon": ["night", "gothic", "romance", "mystery", "lunar", "werewolf", "dream"],
        "sun": ["summer", "day", "hope", "warm", "sunrise"],
        "star": ["night", "scifi", "magic", "wish", "fame", "sparkle"],
        "stars": ["night", "scifi", "magic", "sparkle"],
        "comet": ["space", "scifi", "omen", "night"],
        "cloud": ["sky", "weather", "dream", "soft"],
        "rain": ["weather", "melancholy", "noir", "storm"],
        "storm": ["weather", "thriller", "drama", "sea"],
        "lightning": ["storm", "power", "energy", "thriller", "electric", "thunder"],
        "bolt": ["lightning", "power", "energy", "electric"],
        "snowflake": ["winter", "cold", "christmas", "snow", "ice"],
        "snow": ["winter", "cold", "christmas", "ice"],
        "ice": ["winter", "cold", "frozen"],
        "flame": ["fire", "passion", "danger", "heat", "candle", "burn"],
        "fire": ["flame", "passion", "danger", "heat", "burn", "camp"],
        "campfire": ["camp", "wild", "outdoor", "fire", "adventure"],
        "candle": ["gothic", "romance", "historical", "light", "vigil", "cozy"],
        "lantern": ["light", "historical", "night", "guide", "cozy"],
        "lamp": ["light", "night", "study", "genie"],
        "torch": ["light", "fire", "cave", "dungeon", "fantasy"],
        "wave": ["ocean", "sea", "surf", "coastal", "summer"],
        "water": ["ocean", "sea", "river", "drop"],
        "drop": ["water", "rain", "blood", "tear"],
        "river": ["water", "nature", "journey", "literary"],
        "mountain": ["adventure", "nature", "hiking", "wild", "peak", "literary"],
        "mountains": ["adventure", "nature", "hiking", "wild"],
        "volcano": ["fire", "disaster", "island", "eruption"],
        "island": ["beach", "tropical", "sea", "adventure", "castaway"],
        "desert": ["sand", "western", "dune", "heat"],
        "cave": ["dungeon", "fantasy", "adventure", "dark"],
        "compass": ["adventure", "travel", "navigation", "explorer", "historical", "sea"],
        "map": ["adventure", "travel", "treasure", "explorer", "journey", "fantasy"],
        "globe": ["travel", "world", "nonfiction", "explorer"],
        "ship": ["sea", "sail", "voyage", "pirate", "historical", "adventure"],
        "sailboat": ["sea", "sail", "voyage", "summer"],
        "boat": ["sea", "river", "voyage", "fishing"],
        "anchor": ["sea", "nautical", "navy", "sailor", "coastal", "steady"],
        "helm": ["sea", "nautical", "pirate", "steer", "wheel"],
        "wheel": ["steer", "car", "ship", "fortune"],
        "trident": ["sea", "myth", "poseidon", "fantasy"],
        "mermaid": ["sea", "fantasy", "myth", "romance"],
        "pirate": ["sea", "adventure", "skull", "treasure"],
        "treasure": ["pirate", "adventure", "gold", "chest"],
        "chest": ["treasure", "pirate", "fantasy", "box"],
        "coin": ["money", "treasure", "fortune", "finance", "nonfiction"],
        "money": ["finance", "business", "wealth", "crime", "nonfiction"],
        "dollar": ["money", "finance", "business", "nonfiction"],
        "plane": ["travel", "flight", "adventure", "war", "aviation"],
        "airplane": ["travel", "flight", "adventure", "aviation"],
        "train": ["travel", "journey", "historical", "steam", "railway"],
        "car": ["road", "travel", "thriller", "drive", "retro"],
        "bicycle": ["travel", "summer", "cozy", "ride", "paris"],
        "bike": ["travel", "summer", "cozy", "ride"],
        "road": ["journey", "travel", "literary", "highway"],
        "suitcase": ["travel", "journey", "memoir", "leaving"],
        "backpack": ["travel", "adventure", "hiking", "school"],
        "tent": ["camp", "outdoor", "adventure", "circus"],
        "balloon": ["party", "birthday", "celebration", "whimsical", "float"],
        "hourglass": ["time", "death", "historical", "fantasy", "deadline", "sand"],
        "clock": ["time", "mystery", "deadline", "thriller", "history"],
        "watch": ["time", "luxury", "thriller", "detective"],
        "calendar": ["time", "date", "planner", "nonfiction"],
        "mask": ["mystery", "masquerade", "theater", "thriller", "identity", "venice"],
        "eye": ["mystery", "watch", "surveillance", "thriller", "vision", "horror"],
        "hand": ["touch", "help", "reach", "literary", "gesture"],
        "fist": ["power", "protest", "fight", "strength"],
        "footprint": ["mystery", "trail", "crime", "track"],
        "fingerprint": ["mystery", "crime", "detective", "thriller", "identity"],
        "magnifier": ["mystery", "detective", "search", "clue"],
        "magnifying": ["mystery", "detective", "search", "clue"],
        "detective": ["mystery", "crime", "noir", "clue"],
        "hat": ["fashion", "detective", "noir", "western", "cowboy"],
        "umbrella": ["rain", "noir", "british", "cozy", "weather"],
        "glasses": ["reading", "intellectual", "nonfiction", "spectacles"],
        "camera": ["photo", "memory", "journalism", "nonfiction"],
        "film": ["cinema", "movie", "hollywood", "noir"],
        "microphone": ["music", "podcast", "voice", "speech"],
        "music": ["song", "melody", "concert", "note"],
        "note": ["music", "song", "melody"],
        "guitar": ["music", "rock", "country", "song"],
        "piano": ["music", "classical", "romance", "elegant"],
        "violin": ["music", "classical", "romance", "orchestra"],
        "drum": ["music", "rhythm", "tribal", "war"],
        "theater": ["drama", "stage", "mask", "performance"],
        "brain": ["psychology", "nonfiction", "thriller", "mind", "science"],
        "lightbulb": ["idea", "nonfiction", "business", "creativity", "innovation"],
        "bulb": ["idea", "nonfiction", "creativity"],
        "chess": ["strategy", "thriller", "game", "intellect"],
        "dice": ["chance", "gamble", "game", "luck", "casino"],
        "cards": ["poker", "gamble", "casino", "game", "luck"],
        "puzzle": ["mystery", "game", "piece", "solve"],
        "target": ["aim", "goal", "thriller", "business", "focus"],
        "trophy": ["award", "winner", "sport", "success"],
        "medal": ["award", "winner", "military", "honor"],
        "flag": ["nation", "patriotic", "war", "banner", "finish"],
        "scale": ["justice", "law", "balance", "court", "nonfiction"],
        "gavel": ["justice", "law", "court", "legal", "thriller"],
        "handcuffs": ["crime", "police", "thriller", "arrest"],
        "police": ["crime", "thriller", "law", "detective"],
        "badge": ["police", "sheriff", "western", "law"],
        "cross": ["faith", "religion", "church", "gothic", "memorial"],
        "angel": ["faith", "heaven", "wings", "paranormal", "romance"],
        "wings": ["angel", "flight", "freedom", "fantasy", "paranormal"],
        "devil": ["horror", "evil", "temptation", "demon"],
        "demon": ["horror", "evil", "paranormal", "fantasy"],
        "halo": ["angel", "faith", "saint"],
        "pentagram": ["occult", "witch", "horror", "magic"],
        "tarot": ["occult", "fortune", "mystic", "witch"],
        "witch": ["magic", "halloween", "occult", "fantasy", "cozy"],
        "wizard": ["magic", "fantasy", "wisdom"],
        "fairy": ["fantasy", "magic", "whimsical", "fae", "forest"],
        "elf": ["fantasy", "fae", "forest", "christmas"],
        "gnome": ["fantasy", "garden", "whimsical"],
        "troll": ["fantasy", "monster", "folklore"],
        "giant": ["fantasy", "monster", "folklore"],
        "monster": ["horror", "fantasy", "creature", "beast"],
        "beast": ["fantasy", "monster", "wild", "romance"],
        "gear": ["steampunk", "machine", "industry", "tech", "mechanic"],
        "cog": ["steampunk", "machine", "industry", "mechanic"],
        "clockwork": ["steampunk", "machine", "mechanic"],
        "circuit": ["tech", "scifi", "computer", "electronic"],
        "chip": ["tech", "scifi", "computer"],
        "computer": ["tech", "office", "hacker", "nonfiction"],
        "laptop": ["tech", "office", "business", "remote"],
        "phone": ["contact", "modern", "thriller", "call"],
        "code": ["tech", "programming", "hacker", "cipher"],
        "binary": ["tech", "hacker", "data", "scifi"],
        "lock-open": ["unlock", "secret", "freedom"],
        "chain": ["bound", "prison", "slavery", "link", "strength"],
        "cage": ["prison", "trapped", "bird", "freedom"],
        "prison": ["crime", "trapped", "bars", "thriller"],
        "needle": ["sewing", "craft", "medical", "drug", "cozy"],
        "thread": ["sewing", "craft", "fate", "connection"],
        "scissors": ["craft", "cut", "salon", "sewing"],
        "hammer": ["tool", "build", "craft", "thor", "judge"],
        "wrench": ["tool", "repair", "mechanic"],
        "anvil": ["blacksmith", "forge", "fantasy", "craft"],
        "shovel": ["dig", "grave", "garden", "mystery"],
        "pickaxe": ["mine", "dig", "adventure", "gold"],
        "plant": ["garden", "growth", "nature", "cozy", "botanical"],
        "seed": ["growth", "garden", "beginning", "farm"],
        "apple": ["fruit", "temptation", "school", "autumn", "orchard"],
        "cherry": ["fruit", "summer", "sweet", "romance"],
        "lemon": ["fruit", "summer", "fresh", "cozy"],
        "grape": ["wine", "vineyard", "fruit", "harvest"],
        "pumpkin": ["autumn", "halloween", "harvest", "cozy"],
        "ghost-face": ["horror", "halloween"],
        "gift": ["christmas", "birthday", "present", "celebration"],
        "bell": ["christmas", "church", "alarm", "school"],
        "ribbon": ["award", "gift", "elegant", "decor"],
        "bow-tie": ["formal", "gentleman", "elegant"],
        "dress": ["fashion", "romance", "wedding", "elegant", "regency"],
        "shoe": ["fashion", "walk", "cinderella", "dance"],
        "boot": ["travel", "hiking", "cowboy", "western", "military"],
        "crown-simple": ["royal", "fantasy"],
        "baby": ["family", "birth", "parenting", "memoir"],
        "child": ["family", "childhood", "memoir", "school"],
        "family": ["home", "memoir", "generations", "saga"],
        "user": ["person", "people", "portrait", "profile"],
        "person": ["people", "portrait", "human", "silhouette"],
        "woman": ["female", "portrait", "silhouette", "romance"],
        "man": ["male", "portrait", "silhouette"],
        "couple": ["romance", "love", "wedding", "relationship"],
        "friends": ["friendship", "group", "team", "youngadult"],
        "graduation": ["school", "college", "youngadult", "academic"],
        "school": ["education", "youngadult", "academic", "teacher"],
        "hospital": ["medical", "doctor", "health", "nonfiction"],
        "stethoscope": ["medical", "doctor", "health", "nonfiction"],
        "pill": ["medical", "drug", "health", "addiction", "thriller"],
        "syringe": ["medical", "horror", "drug", "vaccine"],
        "virus": ["pandemic", "thriller", "science", "medical"],
        "radiation": ["scifi", "nuclear", "danger", "apocalypse"],
        "biohazard": ["scifi", "danger", "apocalypse", "thriller"],
        "gasmask": ["apocalypse", "war", "dystopia", "scifi"],
        "dystopia": ["scifi", "future", "oppression"],
        "tank": ["war", "military", "history"],
        "soldier": ["war", "military", "history", "veteran"],
        "military": ["war", "soldier", "army", "history"],
        "cannon": ["war", "pirate", "historical", "navy"],
        "cannonball": ["war", "pirate", "historical"],
        "knight": ["medieval", "fantasy", "chivalry", "armor", "historical"],
        "viking": ["norse", "historical", "fantasy", "raid", "sea"],
        "samurai": ["japan", "historical", "warrior", "honor"],
        "ninja": ["japan", "stealth", "assassin", "warrior"],
        "pharaoh": ["egypt", "ancient", "historical", "royal"],
        "pyramid": ["egypt", "ancient", "historical", "mystery"],
        "temple": ["ancient", "faith", "historical", "ruins"],
        "column": ["ancient", "greek", "classical", "architecture"],
        "statue": ["ancient", "art", "museum", "classical"],
        "vase": ["ancient", "art", "decor", "flower"],
        "amphora": ["ancient", "greek", "historical"],
        "laurel": ["victory", "classical", "award", "roman"],
        "wreath": ["victory", "christmas", "memorial", "laurel"],
        "infinity": ["eternal", "forever", "romance", "math", "scifi"],
        "spiral": ["hypnosis", "psychological", "thriller", "vortex"],
        "maze": ["labyrinth", "mystery", "psychological", "puzzle"],
        "labyrinth": ["maze", "myth", "mystery", "psychological"],
        "mirror": ["reflection", "psychological", "vanity", "fairy", "identity"],
        "shadow": ["noir", "mystery", "thriller", "dark"],
        "silhouette": ["noir", "mystery", "figure", "shadow"],
        "footprints": ["trail", "mystery", "journey", "beach"],
        "telescope": ["astronomy", "scifi", "explorer", "discovery"],
        "binoculars": ["watch", "spy", "surveillance", "birdwatching"],
        "spy": ["thriller", "espionage", "secret", "agent"],
        "radio": ["vintage", "broadcast", "war", "signal"],
        "signal": ["radio", "broadcast", "scifi", "contact"],
        "antenna": ["signal", "scifi", "broadcast", "radio"],
        "bomb-shell": ["war", "thriller"],
        "paper": ["document", "writing", "letter", "literary"],
        "notebook": ["journal", "diary", "writing", "memoir", "literary"],
        "journal": ["diary", "writing", "memoir", "literary"],
        "diary": ["journal", "secret", "memoir", "youngadult"],
        "bookmark": ["reading", "literary", "library"],
        "library": ["books", "literary", "reading", "academic"],
        "poetry": ["literary", "verse", "poem"],
        "quote": ["literary", "speech", "wisdom"],
        "beach": ["summer", "coastal", "vacation", "romance", "sand"],
        "surf": ["beach", "summer", "ocean", "wave"],
        "sunset": ["romance", "evening", "beach", "horizon"],
        "sunrise": ["hope", "morning", "new", "horizon"],
        "horizon": ["journey", "hope", "distance", "literary"],
        "rainbow": ["hope", "pride", "whimsical", "colorful"],
        "christmas": ["holiday", "winter", "festive", "cozy"],
        "halloween": ["horror", "autumn", "spooky", "witch"],
        "cowboy": ["western", "ranch", "horse", "frontier"],
        "cowboy-hat": ["western", "ranch", "frontier"],
        "sheriff": ["western", "law", "badge", "frontier"],
        "saloon": ["western", "bar", "frontier"],
        "wagon": ["western", "pioneer", "historical", "journey"],
        "barn": ["farm", "rural", "country", "cozy"],
        "farm": ["rural", "country", "cozy", "harvest"],
        "tractor": ["farm", "rural", "country"],
        "windmill": ["rural", "dutch", "historical", "countryside"],
        "fence": ["farm", "boundary", "rural", "suburb"],
        "garden": ["cozy", "flower", "botanical", "nature", "english"],
        "watering": ["garden", "cozy", "plant"],
        "kettle": ["cozy", "kitchen", "tea"],
        "pot": ["kitchen", "cooking", "cozy", "cauldron"],
        "chef": ["cooking", "kitchen", "restaurant", "food"],
        "knife-fork": ["dinner", "restaurant", "food"],
        "spoon": ["kitchen", "cooking", "food", "cozy"],
        "yarn": ["knitting", "craft", "cozy", "cat"],
        "knitting": ["craft", "cozy", "yarn", "grandmother"],
        "sofa": ["cozy", "home", "living", "comfort"],
        "armchair": ["cozy", "home", "reading", "comfort"],
        "fireplace": ["cozy", "home", "winter", "warm"],
        "bed": ["sleep", "romance", "dream", "home"],
        "pillow": ["sleep", "dream", "cozy"],
        "dream": ["sleep", "fantasy", "surreal", "literary"],
        "egg": ["easter", "birth", "beginning", "spring"],
        "nest": ["home", "bird", "family", "spring"],
        "ladybug": ["garden", "luck", "spring", "cozy"],
        "snail": ["slow", "garden", "cozy", "spiral"],
        "frog": ["pond", "fairy", "prince", "nature"],
        "turtle": ["slow", "sea", "patience", "nature"],
        "elephant": ["africa", "memory", "wisdom", "safari"],
        "giraffe": ["africa", "safari", "nature"],
        "monkey": ["jungle", "mischief", "nature"],
        "tiger": ["jungle", "india", "power", "wild"],
        "panda": ["china", "cute", "nature"],
        "koala": ["australia", "cute", "nature"],
        "kangaroo": ["australia", "nature"],
        "penguin": ["antarctic", "winter", "cute", "ice"],
        "polar": ["arctic", "winter", "ice", "bear"],
        "camel": ["desert", "arabia", "journey", "caravan"],
        "goat": ["farm", "mountain", "devil", "rural"],
        "sheep": ["farm", "rural", "pastoral", "cozy", "wool"],
        "cow": ["farm", "rural", "country"],
        "pig": ["farm", "rural", "country"],
        "chicken": ["farm", "rural", "country"],
        "rooster": ["farm", "morning", "rural"],
        "hummingbird": ["garden", "summer", "tiny", "bird"],
        "parrot": ["tropical", "pirate", "bird", "jungle"],
        "flamingo": ["tropical", "summer", "pink", "bird"],
        "peacock": ["beauty", "vanity", "india", "royal", "bird"],
        "phoenix": ["fantasy", "rebirth", "fire", "myth"],
        "griffin": ["fantasy", "myth", "heraldry"],
        "pegasus": ["fantasy", "myth", "flight"],
        "centaur": ["fantasy", "myth", "greek"],
        "minotaur": ["fantasy", "myth", "greek", "labyrinth"],
        "medusa": ["fantasy", "myth", "greek", "snake"],
        "hydra": ["fantasy", "myth", "monster"],
        "werewolf": ["horror", "paranormal", "wolf", "moon"],
        "mummy": ["horror", "egypt", "undead"],
        "witch-hat": ["witch", "halloween", "magic"],
        "broom": ["witch", "halloween", "cleaning", "cozy"],
        "spellbook": ["magic", "witch", "fantasy", "grimoire"],
        "rune": ["magic", "norse", "viking", "fantasy", "mystic"],
        "portal": ["fantasy", "scifi", "door", "dimension"],
        "orb": ["magic", "fantasy", "crystal", "fortune"],
        "hourglass-half": ["time", "deadline"],
        "balance": ["justice", "law", "equilibrium"],
        "peace": ["hope", "dove", "sixties", "protest"],
        "fist-raised": ["protest", "power", "revolution"],
        "crowd": ["people", "protest", "society", "nonfiction"],
        "network": ["connection", "tech", "social", "nonfiction"],
        "chart": ["business", "finance", "data", "nonfiction", "growth"],
        "graph": ["business", "finance", "data", "nonfiction"],
        "briefcase": ["business", "office", "career", "nonfiction", "lawyer"],
        "tie": ["business", "office", "formal", "career"],
        "handshake": ["business", "deal", "partnership", "nonfiction"],
        "megaphone": ["marketing", "announce", "protest", "loud"],
        "trending": ["business", "growth", "success", "nonfiction"],
        "medal-star": ["award", "winner"],
        "fingerprint-scan": ["identity", "security", "thriller"],
        "seal": ["stamp", "official", "wax", "historical", "royal"],
        "wax": ["seal", "letter", "historical", "candle"],
        "lace": ["romance", "wedding", "vintage", "victorian"],
        "lantern-paper": ["asia", "festival", "night"],
        "fan": ["japan", "regency", "elegant", "asia"],
        "kimono": ["japan", "asia", "historical"],
        "pagoda": ["asia", "japan", "china", "temple"],
        "cherry-blossom": ["japan", "spring", "romance", "sakura"],
        "bamboo": ["asia", "zen", "nature", "panda"],
        "yin-yang": ["balance", "zen", "asia", "philosophy"],
        "zen": ["calm", "meditation", "mindfulness", "nonfiction"],
        "meditation": ["zen", "calm", "mindfulness", "yoga", "nonfiction"],
        "yoga": ["wellness", "calm", "mindfulness", "nonfiction"],
        "dumbbell": ["fitness", "gym", "strength", "nonfiction"],
        "running": ["fitness", "sport", "marathon", "escape"],
        "football": ["sport", "team", "game"],
        "basketball": ["sport", "team", "game", "youngadult"],
        "baseball": ["sport", "america", "summer", "game"],
        "tennis": ["sport", "summer", "club"],
        "golf": ["sport", "club", "leisure"],
        "swimming": ["sport", "summer", "pool", "water"],
        "ski": ["winter", "snow", "mountain", "sport"],
        "skateboard": ["youngadult", "street", "urban"],
        "headphones": ["music", "youngadult", "podcast", "listen"],
        "gamepad": ["game", "youngadult", "tech", "play"],
        "heart-broken": ["heartbreak", "romance", "loss", "grief"],
        "broken": ["heartbreak", "loss", "grief", "damaged"],
        "tear": ["grief", "sad", "cry", "literary"],
        "cry": ["grief", "sad", "tear", "emotion"],
        "smile": ["happy", "cozy", "joy", "cheerful"],
        "laugh": ["comedy", "humor", "joy"],
        "clown": ["circus", "horror", "comedy"],
        "circus": ["carnival", "whimsical", "historical", "clown"],
        "carousel": ["carnival", "childhood", "whimsical", "nostalgia"],
        "ferris": ["carnival", "fair", "summer", "romance"],
        "roller": ["carnival", "thrill", "youngadult"],
        "ticket": ["cinema", "travel", "event", "admission"],
        "popcorn": ["cinema", "movie", "snack"],
        "pizza": ["food", "italy", "youngadult", "party"],
        "burger": ["food", "diner", "america", "retro"],
        "ice-cream": ["summer", "sweet", "childhood", "cozy"],
        "candy": ["sweet", "childhood", "halloween", "whimsical"],
        "chocolate": ["sweet", "romance", "valentine", "cozy"],
        "honey": ["bee", "sweet", "cozy", "golden"],
        "jar": ["kitchen", "preserve", "cozy", "firefly"],
        "basket": ["picnic", "cozy", "harvest", "market"],
        "picnic": ["summer", "cozy", "romance", "park"],
        "park": ["city", "bench", "nature", "cozy"],
        "bench": ["park", "wait", "literary", "lonely"],
        "fountain": ["park", "city", "romance", "wish"],
        "street": ["city", "urban", "noir", "lamp"],
        "streetlight": ["city", "noir", "night", "urban"],
        "subway": ["city", "urban", "commute", "thriller"],
        "taxi": ["city", "urban", "new york", "noir"],
        "skyline": ["city", "urban", "contemporary", "thriller"],
        "skyscraper": ["city", "urban", "business", "contemporary"],
        "eiffel": ["paris", "france", "romance", "travel"],
        "bigben": ["london", "british", "travel", "historical"],
        "colosseum": ["rome", "italy", "ancient", "travel"],
        "statue-liberty": ["new york", "america", "freedom"],
        "taj": ["india", "romance", "travel", "monument"],
        "sphinx": ["egypt", "ancient", "riddle", "mystery"],
        "totem": ["tribal", "native", "spirit", "nature"],
        "dreamcatcher": ["dream", "native", "spirit", "bohemian"],
        "feather-pen": ["literary", "historical", "writing"],
        "candelabra": ["gothic", "romance", "historical", "phantom"],
        "chandelier": ["luxury", "ballroom", "regency", "gothic"],
        "goblet": ["medieval", "fantasy", "wine", "royal", "feast"],
        "chalice": ["holy", "fantasy", "medieval", "grail"],
        "grail": ["holy", "quest", "fantasy", "medieval"],
        "quest": ["fantasy", "adventure", "journey"],
        "adventure": ["journey", "quest", "explorer", "travel"],
        "journey": ["travel", "adventure", "road", "literary"],
        "explorer": ["adventure", "travel", "discovery", "historical"]
    ]

    // MARK: Search

    /// Relevance-ranked word match over names and tags: every query word must hit something; name hits outrank tag hits.
    func search(_ query: String, pack: String? = nil, style: Style? = nil, limit: Int = 600) -> [Item] {
        let words = IllustrationLibrary.words(query)
        let all = items
        var scored: [(Item, Int)] = []
        scored.reserveCapacity(min(all.count, limit * 2))
        let joined = words.joined(separator: " ")
        for it in all {
            if let pack, it.pack != pack { continue }
            if let style, it.style != style { continue }
            if words.isEmpty {
                scored.append((it, 0))
                continue
            }
            let nameWords = IllustrationLibrary.words(it.name)
            let lowerName = it.name.lowercased()
            var score = 0
            var ok = true
            for w in words {
                var best = 0
                if lowerName == w { best = 40 }
                for n in nameWords where best < 20 {
                    if n == w { best = 20; break }
                    if n.hasPrefix(w) { best = max(best, 10) }
                }
                if best < 10 {
                    for t in it.tags {
                        if t == w { best = max(best, 6); break }
                        if t.hasPrefix(w) { best = max(best, 2) }
                    }
                }
                if best == 0 { ok = false; break }
                score += best
            }
            if !ok { continue }
            if lowerName == joined { score += 50 }
            // Shorter names are more exactly what was asked for.
            score -= min(8, nameWords.count)
            scored.append((it, score))
        }
        if !words.isEmpty {
            scored.sort { a, b in a.1 != b.1 ? a.1 > b.1 : a.0.name < b.0.name }
        }
        if scored.count > limit { scored.removeSubrange(limit...) }
        return scored.map { $0.0 }
    }

    // MARK: Rendering

    func render(_ c: IllustrationContent, size: CGSize) -> CGImage? {
        guard let it = item(c.itemID) else { return nil }
        return render(it, size: size, color: c.color, color2: c.color2, flipped: c.flipped)
    }

    /// Transparent raster of the icon, aspect-fit into `size` and filled with `color` (a vertical gradient to
    /// `color2` when given). The SVGs are monochrome, so only their alpha is used.
    func render(_ item: Item, size: CGSize, color: RGBA, color2: RGBA? = nil, flipped: Bool = false) -> CGImage? {
        IllustrationLibrary.render(svg: fileURL(for: item), size: size, color: color, color2: color2, flipped: flipped)
    }

    /// Renders any SVG file as a tinted silhouette (also used directly by tests).
    static func render(svg url: URL, size: CGSize, color: RGBA, color2: RGBA? = nil, flipped: Bool = false) -> CGImage? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        return render(image: image, size: size, color: color, color2: color2, flipped: flipped)
    }

    static func render(image: NSImage, size: CGSize, color: RGBA, color2: RGBA? = nil, flipped: Bool = false) -> CGImage? {
        let w = min(12000, max(1, Int(size.width.rounded())))
        let h = min(12000, max(1, Int(size.height.rounded())))
        guard let ctx = Gfx.context(w, h) else { return nil }
        let W = CGFloat(w)
        let H = CGFloat(h)
        var iw = image.size.width
        var ih = image.size.height
        if iw <= 0 || ih <= 0 { iw = 1; ih = 1 }
        let s = min(W / iw, H / ih)
        let dw = iw * s
        let dh = ih * s
        let dest = CGRect(x: (W - dw) / 2, y: (H - dh) / 2, width: dw, height: dh)
        if flipped {
            ctx.translateBy(x: W, y: 0)
            ctx.scaleBy(x: -1, y: 1)
        }
        NSGraphicsContext.saveGraphicsState()
        let ns = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.current = ns
        image.draw(in: dest, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: false, hints: [.interpolation: NSImageInterpolation.high])
        NSGraphicsContext.restoreGraphicsState()
        // Keep only the alpha; the icon sets are monochrome, so the fill is the whole color story.
        ctx.setBlendMode(.sourceIn)
        let whole = CGRect(x: 0, y: 0, width: W, height: H)
        if let c2 = color2 {
            Gfx.linearGradient(ctx, whole, [color, c2], angle: 90)
        } else {
            ctx.setFillColor(color.cgColor)
            ctx.fill(whole)
        }
        ctx.setBlendMode(.normal)
        return ctx.makeImage()
    }

    /// Small tinted preview for browsers, cached.
    func thumbnail(_ item: Item, size: CGSize = CGSize(width: 160, height: 160), color: RGBA) -> CGImage? {
        let key = "\(item.id)|\(color.hex)|\(Int(size.width))" as NSString
        if let hit = thumbs.object(forKey: key) { return hit }
        guard let img = render(item, size: size, color: color) else { return nil }
        thumbs.setObject(img, forKey: key)
        return img
    }

    // MARK: Credits

    /// The credit line one item needs (nil for MIT packs).
    func credit(for item: Item) -> String? {
        guard let p = pack(item.pack), !p.attribution.isEmpty else { return nil }
        if let a = item.artist { return "\(IllustrationLibrary.displayName(a)) — \(p.attribution)" }
        return p.attribution
    }

    /// Attribution text for every CC BY illustration used in the document; empty when none is needed.
    func credits(for doc: CoverDocument) -> String {
        var lines: [String] = []
        var seen: Set<String> = []
        for l in doc.layers {
            guard let x = l.illustrationContent, let it = item(x.itemID), let line = credit(for: it) else { continue }
            if seen.insert(line).inserted { lines.append(line) }
        }
        guard !lines.isEmpty else { return "" }
        lines.sort()
        var out = "Illustration credits\n\n"
        out += lines.joined(separator: "\n")
        out += "\n\nIcons from game-icons.net are licensed under Creative Commons BY 3.0 (https://creativecommons.org/licenses/by/3.0/)."
        return out
    }
}
