import Foundation
import XCTest
@testable import Colophon

final class StockPhotoTests: XCTestCase {
    /// A throwaway defaults domain so keys and attribution records never touch the user's settings.
    private func freshService() -> (StockPhotoService, UserDefaults, String) {
        let suite = "colophon.tests.stock.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (StockPhotoService(defaults: defaults), defaults, suite)
    }

    private static let unsplashJSON = """
    {
      "total": 1, "total_pages": 1,
      "results": [
        {
          "id": "abc123", "width": 3000, "height": 4500,
          "urls": {
            "raw": "https://images.unsplash.com/raw",
            "full": "https://images.unsplash.com/full",
            "regular": "https://images.unsplash.com/regular",
            "small": "https://images.unsplash.com/small",
            "thumb": "https://images.unsplash.com/thumb"
          },
          "links": { "html": "https://unsplash.com/photos/abc123", "download_location": "https://api.unsplash.com/photos/abc123/download" },
          "user": { "name": "Ada Lovelace", "links": { "html": "https://unsplash.com/@ada" } }
        }
      ]
    }
    """

    private static let pexelsJSON = """
    {
      "page": 1, "per_page": 30, "total_results": 1,
      "photos": [
        {
          "id": 987, "width": 2000, "height": 3000,
          "url": "https://www.pexels.com/photo/987/",
          "photographer": "Grace Hopper",
          "photographer_url": "https://www.pexels.com/@grace",
          "src": {
            "original": "https://images.pexels.com/original.jpg",
            "large2x": "https://images.pexels.com/large2x.jpg",
            "large": "https://images.pexels.com/large.jpg",
            "medium": "https://images.pexels.com/medium.jpg",
            "small": "https://images.pexels.com/small.jpg",
            "tiny": "https://images.pexels.com/tiny.jpg"
          }
        }
      ]
    }
    """

    func testParsesUnsplashResponse() throws {
        let photos = try StockPhotoService.parse(Data(Self.unsplashJSON.utf8), provider: .unsplash)
        XCTAssertEqual(photos.count, 1)
        let p = try XCTUnwrap(photos.first)
        XCTAssertEqual(p.id, "unsplash:abc123")
        XCTAssertEqual(p.provider, .unsplash)
        XCTAssertEqual(p.thumbURL.absoluteString, "https://images.unsplash.com/thumb")
        XCTAssertEqual(p.previewURL.absoluteString, "https://images.unsplash.com/small")
        XCTAssertEqual(p.fullURL.absoluteString, "https://images.unsplash.com/full")
        XCTAssertEqual(p.width, 3000)
        XCTAssertEqual(p.height, 4500)
        XCTAssertEqual(p.photographer, "Ada Lovelace")
        XCTAssertEqual(p.photographerURL?.absoluteString, "https://unsplash.com/@ada")
        XCTAssertEqual(p.pageURL?.absoluteString, "https://unsplash.com/photos/abc123")
        XCTAssertEqual(p.downloadTrigger?.absoluteString, "https://api.unsplash.com/photos/abc123/download")
        XCTAssertEqual(p.attribution, "Photo by Ada Lovelace on Unsplash")
    }

    func testParsesPexelsResponse() throws {
        let photos = try StockPhotoService.parse(Data(Self.pexelsJSON.utf8), provider: .pexels)
        XCTAssertEqual(photos.count, 1)
        let p = try XCTUnwrap(photos.first)
        XCTAssertEqual(p.id, "pexels:987")
        XCTAssertEqual(p.provider, .pexels)
        XCTAssertEqual(p.thumbURL.absoluteString, "https://images.pexels.com/tiny.jpg")
        XCTAssertEqual(p.previewURL.absoluteString, "https://images.pexels.com/medium.jpg")
        XCTAssertEqual(p.fullURL.absoluteString, "https://images.pexels.com/original.jpg")
        XCTAssertEqual(p.width, 2000)
        XCTAssertEqual(p.height, 3000)
        XCTAssertEqual(p.photographer, "Grace Hopper")
        XCTAssertEqual(p.photographerURL?.absoluteString, "https://www.pexels.com/@grace")
        XCTAssertEqual(p.pageURL?.absoluteString, "https://www.pexels.com/photo/987/")
        XCTAssertNil(p.downloadTrigger)
        XCTAssertEqual(p.attribution, "Photo by Grace Hopper on Pexels")
    }

    func testAttributionStrings() {
        XCTAssertEqual(StockPhoto.attributionLine(photographer: "Jane Doe", provider: .unsplash), "Photo by Jane Doe on Unsplash")
        XCTAssertEqual(StockPhoto.attributionLine(photographer: "  Jane Doe ", provider: .pexels), "Photo by Jane Doe on Pexels")
        XCTAssertEqual(StockPhoto.attributionLine(photographer: "", provider: .pexels), "Photo by Unknown on Pexels")
    }

    func testBadJSONIsReported() {
        XCTAssertThrowsError(try StockPhotoService.parse(Data("not json".utf8), provider: .unsplash)) { error in
            guard case StockPhotoError.badResponse = error else { return XCTFail("Expected badResponse, got \(error)") }
        }
    }

    func testMissingKeyError() {
        let (service, defaults, suite) = freshService()
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertFalse(service.hasKey(for: .unsplash))
        XCTAssertThrowsError(try service.searchRequest("forest", provider: .unsplash, page: 1)) { error in
            guard case StockPhotoError.missingKey(let p) = error else { return XCTFail("Expected missingKey, got \(error)") }
            XCTAssertEqual(p, .unsplash)
        }
        XCTAssertEqual(StockPhotoError.rateLimited.errorDescription, "Rate limit reached, try again in an hour.")
    }

    func testSearchRequestCarriesKeyAndQuery() throws {
        let (service, defaults, suite) = freshService()
        defer { defaults.removePersistentDomain(forName: suite) }
        service.setAPIKey(" secret-123 ", for: .unsplash)
        service.setAPIKey("pex-456", for: .pexels)
        XCTAssertEqual(defaults.string(forKey: "stock.unsplash.key"), "secret-123")
        XCTAssertEqual(defaults.string(forKey: "stock.pexels.key"), "pex-456")

        let u = try service.searchRequest("dark forest", provider: .unsplash, page: 2)
        XCTAssertEqual(u.value(forHTTPHeaderField: "Authorization"), "Client-ID secret-123")
        let uURL = try XCTUnwrap(u.url?.absoluteString)
        XCTAssertTrue(uURL.hasPrefix("https://api.unsplash.com/search/photos?"))
        XCTAssertTrue(uURL.contains("query=dark%20forest"))
        XCTAssertTrue(uURL.contains("per_page=30"))
        XCTAssertTrue(uURL.contains("page=2"))
        XCTAssertTrue(uURL.contains("orientation=portrait"))

        let p = try service.searchRequest("lighthouse", provider: .pexels, page: 1)
        XCTAssertEqual(p.value(forHTTPHeaderField: "Authorization"), "pex-456")
        XCTAssertTrue(p.url?.absoluteString.hasPrefix("https://api.pexels.com/v1/search?") ?? false)

        service.setAPIKey("", for: .pexels)
        XCTAssertFalse(service.hasKey(for: .pexels))
    }

    func testCreditsForRecordedAssetInDocument() throws {
        let (service, defaults, suite) = freshService()
        defer { defaults.removePersistentDomain(forName: suite) }
        let photos = try StockPhotoService.parse(Data(Self.pexelsJSON.utf8), provider: .pexels)
        let photo = try XCTUnwrap(photos.first)

        var doc = CoverDocument()
        let used = doc.addAsset(Data([1, 2, 3]))
        let unused = UUID()
        service.record(photo, assetID: used)
        service.record(photo, assetID: unused)

        XCTAssertEqual(service.record(for: used)?.photographer, "Grace Hopper")
        let lines = service.credits(for: doc)
        XCTAssertEqual(lines, ["Photo by Grace Hopper on Pexels — https://www.pexels.com/photo/987/"])

        // Same photo twice in one document is credited once; an empty document has no credits.
        let again = doc.addAsset(Data([4, 5, 6]))
        service.record(photo, assetID: again)
        XCTAssertEqual(service.credits(for: doc).count, 1)
        XCTAssertTrue(service.credits(for: CoverDocument()).isEmpty)
    }

    func testSuggestedQueryUsesGenre() {
        var book = BookInfo()
        book.title = "The Lighthouse Keeper"
        book.genre = .scienceFiction
        let q = StockPhotoService.suggestedQuery(for: book)
        // Keyword tagging comes from NLTagger, so only the deterministic genre suffix is asserted.
        XCTAssertTrue(q.hasSuffix("science fiction"))
        book.genre = .horror
        XCTAssertTrue(StockPhotoService.suggestedQuery(for: book).hasSuffix("horror"))
    }
}
