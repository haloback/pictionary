import CoreGraphics
import CoreVideo
import Foundation
import XCTest
@testable import Colophon

final class TasteEngineTests: XCTestCase {
    // MARK: Tokenizer (no download needed)

    func testBytesToUnicodeIsABijectionOf256() {
        let table = ClipTokenizer.bytesToUnicode()
        XCTAssertEqual(table.count, 256)
        XCTAssertEqual(Set(table.values).count, 256)
        for (_, s) in table { XCTAssertEqual(s.unicodeScalars.count, 1) }
        // Printable ASCII maps to itself; space and control bytes move up past U+0100.
        XCTAssertEqual(table[UInt8(ascii: "a")], "a")
        XCTAssertEqual(table[UInt8(ascii: "!")], "!")
        XCTAssertEqual(table[UInt8(ascii: " ")], "Ġ")
        XCTAssertEqual(table[0], "Ā")
    }

    func testRegexSplitsContractionsWordsDigitsAndPunctuation() {
        let cleaned = ClipTokenizer.clean("  Don't   stop, it's\n3am!  ")
        XCTAssertEqual(cleaned, "don't stop, it's 3am!")
        XCTAssertEqual(ClipTokenizer.split(cleaned), ["don", "'t", "stop", ",", "it", "'s", "3", "am", "!"])
        XCTAssertEqual(ClipTokenizer.split("“quiet” hours — 42"), ["“", "quiet", "”", "hours", "—", "4", "2"])
    }

    func testBPEMergesWithEndOfWordConvention() {
        let vocab: [String: Int] = ["c": 1, "a": 2, "t": 3, "t</w>": 4, "ca": 5, "cat</w>": 6, "cat": 7,
                                    "<|startoftext|>": 49406, "<|endoftext|>": 49407]
        // The last symbol of a word carries "</w>", so a "ca t" merge never fires on "cat"...
        let partial = ClipTokenizer(vocab: vocab, merges: ["#version: 0.2", "c a", "ca t"])
        XCTAssertEqual(partial.bpe(word: "cat"), ["ca", "t</w>"])
        // ...while "ca t</w>" does.
        let full = ClipTokenizer(vocab: vocab, merges: ["#version: 0.2", "c a", "ca t</w>"])
        XCTAssertEqual(full.bpe(word: "cat"), ["cat</w>"])
        XCTAssertEqual(full.ids("cat"), [6])
        XCTAssertEqual(full.ids("Cat  cat"), [6, 6])
        // Rank order matters: a later "a t</w>" merge loses to the earlier "c a".
        let ranked = ClipTokenizer(vocab: vocab, merges: ["c a", "a t</w>"])
        XCTAssertEqual(ranked.bpe(word: "cat"), ["ca", "t</w>"])
        // A word with no applicable merges stays as symbols, last one ending the word.
        XCTAssertEqual(full.bpe(word: "tac"), ["t", "a", "c</w>"])
        XCTAssertEqual(full.bpe(word: "t"), ["t</w>"])
    }

    func testEncodePadsAndTruncatesWithBOSFirstAndEOSLast() {
        var vocab: [String: Int] = ["<|startoftext|>": 49406, "<|endoftext|>": 49407]
        for (i, s) in ClipTokenizer.byteEncoder.enumerated() {
            vocab[s] = i
            vocab[s + "</w>"] = 256 + i
        }
        let tok = ClipTokenizer(vocab: vocab, merges: [])
        let short = tok.encode("ab")
        XCTAssertEqual(short.ids.count, 77)
        XCTAssertEqual(short.mask.count, 77)
        XCTAssertEqual(Array(short.ids.prefix(4)), [49406, Int32(UInt8(ascii: "a")), 256 + Int32(UInt8(ascii: "b")), 49407])
        XCTAssertEqual(Array(short.mask.prefix(5)), [1, 1, 1, 1, 0])
        XCTAssertEqual(short.ids[4...].filter { $0 != 0 }.count, 0)

        let long = tok.encode(String(repeating: "a ", count: 100))
        XCTAssertEqual(long.ids.count, 77)
        XCTAssertEqual(long.ids.first, 49406)
        XCTAssertEqual(long.ids.last, 49407)
        XCTAssertEqual(long.mask.filter { $0 == 1 }.count, 77)

        let custom = tok.encode("abc", length: 4)
        XCTAssertEqual(custom.ids, [49406, Int32(UInt8(ascii: "a")), Int32(UInt8(ascii: "b")), 49407])
    }

    func testEngineHelpersWithoutModels() {
        XCTAssertEqual(TasteEngine.cosine([1, 0], [1, 0]), 1, accuracy: 1e-6)
        XCTAssertEqual(TasteEngine.cosine([1, 0], [0, 1]), 0, accuracy: 1e-6)
        XCTAssertEqual(TasteEngine.cosine([], []), 0)
        let ctx = Gfx.context(300, 180)
        ctx?.setFillColor(RGBA(hex: "AA3344").cgColor)
        ctx?.fill(CGRect(x: 0, y: 0, width: 300, height: 180))
        if let img = ctx?.makeImage(), let pb = TasteEngine.pixelBuffer(img, side: 224) {
            XCTAssertEqual(CVPixelBufferGetWidth(pb), 224)
            XCTAssertEqual(CVPixelBufferGetHeight(pb), 224)
        } else {
            XCTFail("pixel buffer")
        }
        for g in Genre.allCases { XCTAssertFalse(TasteEngine.promptLabel(g).isEmpty) }
        XCTAssertEqual(TasteEngine.moodVocabulary.count, 48)
        XCTAssertEqual(Set(TasteEngine.moodVocabulary).count, 48)
    }

    // MARK: Integration (COLOPHON_TASTE=1; downloads ~280 MB once)

    private static let reference = "https://github.com/haloback/pictionary/releases/download/models-v1/tokenizer-reference.json"

    func testInstalledEngineMatchesReferenceAndJudgesCovers() async throws {
        guard ProcessInfo.processInfo.environment["COLOPHON_TASTE"] != nil else {
            throw XCTSkip("Set COLOPHON_TASTE=1 to run the CLIP integration test.")
        }
        let engine = TasteEngine.shared
        try await engine.install()
        XCTAssertTrue(engine.isReady)

        // Tokenizer against the Hugging Face reference (which pads with EOS, so compare up to the first EOS).
        let tokenizer = try ClipTokenizer(directory: engine.modelsDirectory.appendingPathComponent("clip-tokenizer"))
        let (data, _) = try await URLSession.shared.data(from: try XCTUnwrap(URL(string: TasteEngineTests.reference)))
        let probes = try XCTUnwrap(try JSONSerialization.jsonObject(with: data, options: []) as? [String: [Int]])
        XCTAssertFalse(probes.isEmpty)
        for (text, expected) in probes {
            let eos = expected.firstIndex(of: 49407) ?? (expected.count - 1)
            let want: [Int32] = expected[...eos].map { Int32($0) }
            let got: [Int32] = Array(tokenizer.encode(text).ids.prefix(want.count))
            XCTAssertEqual(got, want, text)
        }
        XCTAssertEqual(Array(tokenizer.encode("a photo of a cat").ids.prefix(8)), [49406, 320, 1125, 539, 320, 2368, 49407, 0])

        // A horror Signature design should read as horror or thriller.
        let horror = try XCTUnwrap(SignatureLibrary.all.first { $0.genre == .horror })
        let doc = SignatureLibrary.build(horror, palette: 0, base: SignatureLibrary.sampleDocument(horror))
        let image = try XCTUnwrap(TasteEngine.thumbnail(doc))
        let fit = try XCTUnwrap(engine.genreFit(image, key: "test-horror"))
        XCTAssertEqual(fit.count, Genre.allCases.count)
        XCTAssertEqual(fit.reduce(0) { $0 + $1.score }, 1, accuracy: 1e-3)
        let top3 = Set(fit.prefix(3).map(\.genre))
        XCTAssertTrue(top3.contains(.horror) || top3.contains(.thriller), "\(fit.prefix(3))")

        let img = try XCTUnwrap(engine.imageEmbedding(image, key: "test-horror"))
        XCTAssertEqual(img.count, 512)
        let cover = try XCTUnwrap(engine.textEmbedding("a book cover"))
        let dog = try XCTUnwrap(engine.textEmbedding("a photo of a dog"))
        XCTAssertGreaterThan(TasteEngine.cosine(img, cover), TasteEngine.cosine(img, dog))

        let pro = try XCTUnwrap(engine.professionalism(image, key: "test-horror"))
        XCTAssertTrue((0...1).contains(pro))
        let tags = try XCTUnwrap(engine.moodTags(image, key: "test-horror"))
        XCTAssertLessThanOrEqual(tags.count, 5)
        if let a = engine.aestheticScore(img) { XCTAssertTrue((0...1).contains(a)) }

        let report = try XCTUnwrap(engine.taste(of: doc))
        XCTAssertEqual(report.fitForBook, fit.first { $0.genre == .horror }?.score ?? -1, accuracy: 1e-6)
        let results = engine.search("dark horror", in: Array(SignatureLibrary.all.prefix(6)), limit: 3)
        XCTAssertEqual(results.count, 3)
        XCTAssertNotNil(engine.designEmbedding(horror))
    }
}
