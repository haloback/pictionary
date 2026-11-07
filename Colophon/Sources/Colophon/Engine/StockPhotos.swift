import AppKit
import Foundation
import Observation

/// Errors raised while searching or fetching a stock photo.
enum StockPhotoError: LocalizedError {
    case missingKey(StockPhotoService.Provider)
    case badURL
    case http(Int)
    case rateLimited
    case badResponse
    case notAnImage

    var errorDescription: String? {
        switch self {
        case .missingKey(let p): return "Add your \(p.label) API key first (free from \(p.keySite))."
        case .badURL: return "Couldn't build the search address."
        case .http(let code): return "\(code): the photo server answered with an error. Try again later."
        case .rateLimited: return "Rate limit reached, try again in an hour."
        case .badResponse: return "The photo server sent something Colophon couldn't read."
        case .notAnImage: return "The download wasn't a usable image."
        }
    }
}

/// One search result from Unsplash or Pexels.
struct StockPhoto: Identifiable, Hashable {
    let id: String
    let provider: StockPhotoService.Provider
    let thumbURL: URL
    let previewURL: URL
    let fullURL: URL
    let width: Int
    let height: Int
    let photographer: String
    let photographerURL: URL?
    let pageURL: URL?
    /// Unsplash asks that this endpoint be hit whenever a photo is actually used.
    let downloadTrigger: URL?
    /// "Photo by NAME on Unsplash" / "Photo by NAME on Pexels".
    let attribution: String

    static func attributionLine(photographer: String, provider: StockPhotoService.Provider) -> String {
        let name = photographer.trimmingCharacters(in: .whitespacesAndNewlines)
        return "Photo by \(name.isEmpty ? "Unknown" : name) on \(provider.label)"
    }
}

/// Searches Unsplash and Pexels with the user's own (free) API keys, downloads chosen photos
/// and remembers who shot each imported asset so exports can credit them.
@Observable
final class StockPhotoService {
    static let shared = StockPhotoService()

    enum Provider: String, CaseIterable, Identifiable {
        case unsplash, pexels

        var id: String { rawValue }

        var label: String {
            switch self {
            case .unsplash: return "Unsplash"
            case .pexels: return "Pexels"
            }
        }

        /// Where a free key comes from (shown to the user, never fetched).
        var keySite: String {
            switch self {
            case .unsplash: return "unsplash.com/developers"
            case .pexels: return "pexels.com/api"
            }
        }

        /// UserDefaults key under which the user's API key is stored.
        var defaultsKey: String {
            switch self {
            case .unsplash: return "stock.unsplash.key"
            case .pexels: return "stock.pexels.key"
            }
        }
    }

    /// UserDefaults key for the attribution records (asset id → provider / photographer / page).
    static let recordsKey = "stock.attributions"

    private let defaults: UserDefaults

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 180
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: Keys

    func apiKey(for provider: Provider) -> String {
        (defaults.string(forKey: provider.defaultsKey) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func setAPIKey(_ key: String, for provider: Provider) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            defaults.removeObject(forKey: provider.defaultsKey)
        } else {
            defaults.set(trimmed, forKey: provider.defaultsKey)
        }
    }

    func hasKey(for provider: Provider) -> Bool { !apiKey(for: provider).isEmpty }

    // MARK: Search

    /// Builds the search request; throws when the key is missing. Separated so tests can inspect it offline.
    func searchRequest(_ query: String, provider: Provider, page: Int) throws -> URLRequest {
        let key = apiKey(for: provider)
        guard !key.isEmpty else { throw StockPhotoError.missingKey(provider) }
        var comps: URLComponents?
        switch provider {
        case .unsplash: comps = URLComponents(string: "https://api.unsplash.com/search/photos")
        case .pexels: comps = URLComponents(string: "https://api.pexels.com/v1/search")
        }
        comps?.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "per_page", value: "30"),
            URLQueryItem(name: "page", value: String(max(1, page))),
            URLQueryItem(name: "orientation", value: "portrait")
        ]
        guard let url = comps?.url else { throw StockPhotoError.badURL }
        var req = URLRequest(url: url)
        switch provider {
        case .unsplash:
            req.setValue("Client-ID \(key)", forHTTPHeaderField: "Authorization")
            req.setValue("v1", forHTTPHeaderField: "Accept-Version")
        case .pexels:
            req.setValue(key, forHTTPHeaderField: "Authorization")
        }
        return req
    }

    func search(_ query: String, provider: Provider, page: Int = 1) async throws -> [StockPhoto] {
        let req = try searchRequest(query, provider: provider, page: page)
        let (data, response) = try await StockPhotoService.session.data(for: req)
        try StockPhotoService.check(response)
        return try StockPhotoService.parse(data, provider: provider)
    }

    private static func check(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        if http.statusCode == 403 || http.statusCode == 429 { throw StockPhotoError.rateLimited }
        if http.statusCode < 200 || http.statusCode >= 300 { throw StockPhotoError.http(http.statusCode) }
    }

    // MARK: Parsing (no network; used by tests)

    static func parse(_ data: Data, provider: Provider) throws -> [StockPhoto] {
        switch provider {
        case .unsplash: return try parseUnsplash(data)
        case .pexels: return try parsePexels(data)
        }
    }

    private struct UnsplashResponse: Decodable {
        struct Photo: Decodable {
            struct URLs: Decodable { let thumb: String?; let small: String?; let regular: String?; let full: String? }
            struct Links: Decodable { let html: String?; let download_location: String? }
            struct User: Decodable {
                struct Links: Decodable { let html: String? }
                let name: String?
                let links: Links?
            }
            let id: String
            let width: Int?
            let height: Int?
            let urls: URLs
            let links: Links?
            let user: User?
        }
        let results: [Photo]
    }

    private struct PexelsResponse: Decodable {
        struct Photo: Decodable {
            struct Src: Decodable { let tiny: String?; let medium: String?; let large: String?; let large2x: String?; let original: String? }
            let id: Int
            let width: Int?
            let height: Int?
            let url: String?
            let photographer: String?
            let photographer_url: String?
            let src: Src
        }
        let photos: [Photo]
    }

    static func parseUnsplash(_ data: Data) throws -> [StockPhoto] {
        let decoded: UnsplashResponse
        do { decoded = try JSONDecoder().decode(UnsplashResponse.self, from: data) } catch { throw StockPhotoError.badResponse }
        var out: [StockPhoto] = []
        for p in decoded.results {
            guard let full = url(p.urls.full ?? p.urls.regular) else { continue }
            let thumb = url(p.urls.thumb ?? p.urls.small) ?? full
            let preview = url(p.urls.small ?? p.urls.regular) ?? full
            let name = p.user?.name ?? ""
            out.append(StockPhoto(
                id: "unsplash:\(p.id)",
                provider: .unsplash,
                thumbURL: thumb,
                previewURL: preview,
                fullURL: full,
                width: p.width ?? 0,
                height: p.height ?? 0,
                photographer: name,
                photographerURL: url(p.user?.links?.html),
                pageURL: url(p.links?.html),
                downloadTrigger: url(p.links?.download_location),
                attribution: StockPhoto.attributionLine(photographer: name, provider: .unsplash)))
        }
        return out
    }

    static func parsePexels(_ data: Data) throws -> [StockPhoto] {
        let decoded: PexelsResponse
        do { decoded = try JSONDecoder().decode(PexelsResponse.self, from: data) } catch { throw StockPhotoError.badResponse }
        var out: [StockPhoto] = []
        for p in decoded.photos {
            guard let full = url(p.src.original ?? p.src.large2x ?? p.src.large) else { continue }
            let thumb = url(p.src.tiny ?? p.src.medium) ?? full
            let preview = url(p.src.medium ?? p.src.large) ?? full
            let name = p.photographer ?? ""
            out.append(StockPhoto(
                id: "pexels:\(p.id)",
                provider: .pexels,
                thumbURL: thumb,
                previewURL: preview,
                fullURL: full,
                width: p.width ?? 0,
                height: p.height ?? 0,
                photographer: name,
                photographerURL: url(p.photographer_url),
                pageURL: url(p.url),
                downloadTrigger: nil,
                attribution: StockPhoto.attributionLine(photographer: name, provider: .pexels)))
        }
        return out
    }

    private static func url(_ s: String?) -> URL? {
        guard let s, !s.isEmpty else { return nil }
        return URL(string: s)
    }

    // MARK: Download

    /// Fetches the full-size file, downsamples it to the asset store's working size and re-encodes it.
    /// For Unsplash the `download_location` endpoint is pinged, as its guidelines require.
    func download(_ photo: StockPhoto) async throws -> Data {
        var req = URLRequest(url: photo.fullURL)
        req.timeoutInterval = 120
        let (raw, response) = try await StockPhotoService.session.data(for: req)
        try StockPhotoService.check(response)
        guard let img = AssetStore.decode(raw, maxPixel: AssetStore.Resolution.full.rawValue),
              let data = AssetStore.encode(img) else { throw StockPhotoError.notAnImage }
        if photo.provider == .unsplash, let trigger = photo.downloadTrigger {
            let key = apiKey(for: .unsplash)
            if !key.isEmpty {
                var t = URLRequest(url: trigger)
                t.setValue("Client-ID \(key)", forHTTPHeaderField: "Authorization")
                t.setValue("v1", forHTTPHeaderField: "Accept-Version")
                _ = try? await StockPhotoService.session.data(for: t)
            }
        }
        return data
    }

    // MARK: Attribution bookkeeping

    /// What's remembered about an imported stock photo. Stored in UserDefaults keyed by the asset id.
    struct Record: Codable, Hashable {
        var provider: String
        var photographer: String
        var photographerURL: String?
        var pageURL: String?
        var attribution: String
    }

    private func loadRecords() -> [String: Record] {
        guard let data = defaults.data(forKey: StockPhotoService.recordsKey),
              let decoded = try? JSONDecoder().decode([String: Record].self, from: data) else { return [:] }
        return decoded
    }

    private func saveRecords(_ records: [String: Record]) {
        if let data = try? JSONEncoder().encode(records) { defaults.set(data, forKey: StockPhotoService.recordsKey) }
    }

    /// Remembers that `assetID` came from `photo`.
    func record(_ photo: StockPhoto, assetID: UUID) {
        var records = loadRecords()
        records[assetID.uuidString] = Record(
            provider: photo.provider.rawValue,
            photographer: photo.photographer,
            photographerURL: photo.photographerURL?.absoluteString,
            pageURL: photo.pageURL?.absoluteString,
            attribution: photo.attribution)
        saveRecords(records)
    }

    func record(for assetID: UUID) -> Record? { loadRecords()[assetID.uuidString] }

    /// Credit lines for every stock photo whose asset is in the document, sorted and deduplicated.
    /// Each line is the attribution followed by the photo's page when known.
    func credits(for doc: CoverDocument) -> [String] {
        let records = loadRecords()
        guard !records.isEmpty else { return [] }
        var lines: [String] = []
        var seen: Set<String> = []
        for key in doc.assets.keys {
            guard let r = records[key] else { continue }
            var line = r.attribution
            if let page = r.pageURL, !page.isEmpty { line += " — " + page }
            if seen.insert(line).inserted { lines.append(line) }
        }
        lines.sort()
        return lines
    }

    /// The query "Search for my book" starts from: brief keywords plus the genre.
    static func suggestedQuery(for book: BookInfo) -> String {
        let mood = BriefMood.analyze(title: book.title, subtitle: book.subtitle, tagline: book.tagline, blurb: book.blurb)
        var words: [String] = Array(mood.keywords.prefix(3))
        if words.isEmpty { words = Array(mood.tags.prefix(2)) }
        let genreWords: [String]
        switch book.genre {
        case .scienceFiction: genreWords = ["science fiction"]
        case .youngAdult: genreWords = ["young adult"]
        case .cozy: genreWords = ["cozy"]
        case .mystery: genreWords = ["mystery"]
        default: genreWords = [book.genre.rawValue]
        }
        words.append(contentsOf: genreWords)
        return words.joined(separator: " ")
    }
}
