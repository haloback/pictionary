import Foundation
import XCTest
@testable import Colophon

final class BlurbWriterTests: XCTestCase {
    /// Twelve sentences; the last one resolves the plot and must never reach the blurb.
    static let thrillerSynopsis: [String] = [
        "Detective Mara Voss has spent six years trying to forget the night her partner vanished from a rain-soaked pier in Halden.",
        "When a body surfaces in the harbor wearing his watch, the missing-persons case becomes a murder investigation overnight.",
        "The dead man is not her partner, but he was carrying a key to a storage unit rented in her name.",
        "Inside the unit Mara finds a wall of photographs tracking her every move for the past year.",
        "Her captain orders her off the case, which only convinces her that someone in the department is hiding something.",
        "A journalist named Teo Lindqvist claims to have proof that the pier was never a crime scene at all.",
        "Together they trace a trail of forged shipping manifests to a cold-storage firm owned by the city's most generous donor.",
        "Someone starts following Teo home, and the photographs in the unit begin to change.",
        "Mara realizes the watch was planted to lure her back to the harbor on a specific night.",
        "The donor turns out to be running a smuggling route through the harbor with help from the captain.",
        "Mara confronts the captain on the pier and finally learns that her partner chose to disappear.",
        "In the end she lets him stay gone and closes the case for good."
    ]

    private var synopsis: String { Self.thrillerSynopsis.joined(separator: " ") }

    private var book: BookInfo {
        var b = BookInfo()
        b.title = "The Harbor Watch"
        b.author = "A. Writer"
        b.genre = .thriller
        return b
    }

    func testExtractiveDraftShape() {
        let draft = BlurbWriter.extractiveDraft(book: book, synopsis: synopsis, tone: .gripping)
        let paragraphs = draft.components(separatedBy: "\n\n").filter { !$0.isEmpty }
        XCTAssertEqual(paragraphs.count, 3, draft)
        let words = BlurbWriter.wordCount(draft)
        XCTAssertGreaterThanOrEqual(words, 60, draft)
        XCTAssertLessThanOrEqual(words, 200, draft)
        let firstThird = Self.thrillerSynopsis.prefix(4)
        XCTAssertTrue(firstThird.contains { draft.contains($0) || draft.contains(String($0.prefix(40))) }, draft)
        XCTAssertFalse(draft.contains("In the end"), draft)
        XCTAssertFalse(draft.contains("finally learns"), draft)
        // The stakes line comes from the template set, never from the synopsis.
        XCTAssertTrue(BlurbWriter.templates.contains { $0.text == paragraphs[2] }, paragraphs[2])
    }

    func testDraftIsDeterministicAndAsyncEntryPointWorks() async {
        let a = BlurbWriter.extractiveDraft(book: book, synopsis: synopsis, tone: .literary)
        let b = BlurbWriter.extractiveDraft(book: book, synopsis: synopsis, tone: .literary)
        XCTAssertEqual(a, b)
        let viaDraft = await BlurbWriter.draft(book: book, synopsis: synopsis, tone: .literary)
        XCTAssertGreaterThanOrEqual(BlurbWriter.wordCount(viaDraft), 40)
    }

    func testEmptySynopsisStillGivesAStakesLine() {
        let draft = BlurbWriter.extractiveDraft(book: book, synopsis: "", tone: .witty)
        XCTAssertFalse(draft.isEmpty)
        XCTAssertTrue(BlurbWriter.templates.contains { $0.text == draft })
    }

    func testFragmentTrimsLongSentencesAtCommas() {
        let long = "When the tide went out, the harbor gave up the body it had been keeping, and nobody in Halden was surprised, least of all Mara."
        let f = BlurbWriter.fragment(long)
        XCTAssertLessThanOrEqual(BlurbWriter.wordCount(f), 21, f)
        XCTAssertTrue(f.hasSuffix("."), f)
        XCTAssertTrue(long.hasPrefix(String(f.dropLast())), f)
        XCTAssertEqual(BlurbWriter.fragment("No commas here at all."), "No commas here at all.")
    }

    func testShortenRespectsLimitAndSentenceBoundaries() {
        let blurb = Self.thrillerSynopsis.prefix(6).joined(separator: " ") + "\n\n" + Self.thrillerSynopsis.suffix(6).joined(separator: " ")
        for limit in [20, 40, 75, 150] {
            let s = BlurbWriter.shorten(blurb, to: limit)
            XCTAssertLessThanOrEqual(BlurbWriter.wordCount(s), limit, "limit \(limit)")
            // Every kept sentence is one of the originals, whole.
            let kept = s.components(separatedBy: "\n\n").flatMap { BlurbWriter.sentences($0) }
            XCTAssertFalse(kept.isEmpty)
            for k in kept { XCTAssertTrue(Self.thrillerSynopsis.contains(k), k) }
        }
        XCTAssertEqual(BlurbWriter.shorten(blurb, to: 10_000), blurb)
        let tiny = BlurbWriter.shorten("A sentence of more than four words.", to: 4)
        XCTAssertLessThanOrEqual(BlurbWriter.wordCount(tiny), 4)
    }

    func testWordCount() {
        XCTAssertEqual(BlurbWriter.wordCount(""), 0)
        XCTAssertEqual(BlurbWriter.wordCount("  one two\nthree  "), 3)
    }

    func testLexiconAndTemplateSizes() {
        XCTAssertGreaterThanOrEqual(BlurbWriter.lexicon.count, 100)
        XCTAssertGreaterThanOrEqual(BlurbWriter.templates.count, 24)
        for g in Genre.allCases {
            for t in BlurbWriter.Tone.allCases {
                XCTAssertFalse(BlurbWriter.stakesLine(genre: g, tone: t, seed: 7).isEmpty)
            }
        }
        XCTAssertEqual(BlurbWriter.stakesLine(genre: .thriller, tone: .gripping, seed: 0),
                       BlurbWriter.stakesLine(genre: .thriller, tone: .gripping, seed: 0))
    }

    func testResolutionDetection() {
        XCTAssertTrue(BlurbWriter.looksLikeResolution("In the end she lets him go."))
        XCTAssertTrue(BlurbWriter.looksLikeResolution("Mara finally realizes who did it."))
        XCTAssertFalse(BlurbWriter.looksLikeResolution("A body surfaces in the harbor."))
    }

    func testPromptMentionsTheBrief() {
        let p = BlurbWriter.prompt(book: book, synopsis: synopsis, tone: .epic)
        XCTAssertTrue(p.contains("The Harbor Watch"))
        XCTAssertTrue(p.contains("thriller"))
        XCTAssertTrue(p.contains("120 to 180 words"))
        XCTAssertTrue(p.contains(Self.thrillerSynopsis[0]))
    }

    func testCleanStripsQuotesAndMarkup() {
        let cleaned = BlurbWriter.clean("# Blurb\n\n\"A hook.\"\n\n- Second paragraph.\n\n\n“Last line?”\n")
        XCTAssertEqual(cleaned, "Blurb\n\nA hook.\n\nSecond paragraph.\n\nLast line?")
    }

    func testBookInfoDecodesOldJSONAndRoundTrips() throws {
        let old = #"{"title":"Old Book","subtitle":"","author":"Someone","series":"","tagline":"A line","genre":"romance"}"#
        let decoded = try JSONDecoder().decode(BookInfo.self, from: Data(old.utf8))
        XCTAssertEqual(decoded.title, "Old Book")
        XCTAssertEqual(decoded.genre, .romance)
        XCTAssertEqual(decoded.synopsis, "")
        XCTAssertEqual(decoded.blurb, "")

        let bare = try JSONDecoder().decode(BookInfo.self, from: Data("{}".utf8))
        XCTAssertEqual(bare, BookInfo())

        var full = book
        full.synopsis = synopsis
        full.blurb = "A blurb.\n\nWith two paragraphs."
        let data = try JSONEncoder().encode(full)
        let back = try JSONDecoder().decode(BookInfo.self, from: data)
        XCTAssertEqual(back, full)
        XCTAssertEqual(back.synopsis, synopsis)
        XCTAssertEqual(back.blurb, full.blurb)
    }

    func testPaperbackFallsBackToBookBlurb() {
        var doc = CoverDocument()
        XCTAssertEqual(PrintWrap.backBlurb(doc), "")
        doc.book.blurb = "From the Book panel."
        XCTAssertEqual(PrintWrap.backBlurb(doc), "From the Book panel.")
        doc.paperback.blurb = "Paperback's own."
        XCTAssertEqual(PrintWrap.backBlurb(doc), "Paperback's own.")
    }
}
