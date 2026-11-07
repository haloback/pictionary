import CoreGraphics
import Foundation
import XCTest
@testable import Colophon

final class ShelfAndImproveTests: XCTestCase {
    private func cover(ground: RGBA, title: RGBA, titleFrame: NRect = NRect(0.08, 0.12, 0.84, 0.4)) -> CoverDocument {
        var d = CoverDocument()
        d.book = BookInfo(title: "The Salt Orchard", subtitle: "A Novel", author: "Ines Valcourt", tagline: "Some debts are paid in water.", genre: .literary)
        d.palette = [RGBA(hex: "121212"), RGBA(hex: "E8562A"), RGBA(hex: "F1EBDD")]
        d.background = ground
        d.layers = [Layer.fill(.solid, colors: [ground], frame: .full),
                    Layer.text("The Salt\nOrchard", role: .title, frame: titleFrame, font: "PlayfairDisplay-Black", color: title),
                    Layer.text("Ines Valcourt", role: .author, frame: NRect(0.15, 0.85, 0.7, 0.04), font: "Montserrat-Black", color: title)]
        return d
    }

    private var clean: CoverDocument { cover(ground: RGBA(hex: "F1EBDD"), title: RGBA(hex: "121212")) }
    /// Pale type on a pale ground and a title too small to read.
    private var weak: CoverDocument { cover(ground: RGBA(hex: "D9D4C7"), title: RGBA(hex: "E6E0D2"), titleFrame: NRect(0.3, 0.45, 0.4, 0.04)) }

    // MARK: Shelf test

    func testShelfTestBuildsAGridAndScores() throws {
        let r = try XCTUnwrap(ShelfTest.run(clean, columns: 3, rows: 2, seed: 4))
        let cell = ShelfTest.defaultCell
        XCTAssertEqual(r.grid.width, Int(3 * cell.width + 4 * ShelfTest.gap))
        XCTAssertEqual(r.grid.height, Int(2 * (cell.height + ShelfTest.captionHeight) + 3 * ShelfTest.gap))
        XCTAssertTrue((0...100).contains(r.standout), "\(r.standout)")
        XCTAssertGreaterThanOrEqual(r.notes.count, 1)
        XCTAssertEqual(r.neighbors.count, 5)
        XCTAssertTrue((0..<6).contains(r.position))
    }

    func testShelfTestIsSeededAndNotesTinyTitles() throws {
        let a = try XCTUnwrap(ShelfTest.run(weak, columns: 2, rows: 2, seed: 9))
        let b = try XCTUnwrap(ShelfTest.run(weak, columns: 2, rows: 2, seed: 9))
        XCTAssertEqual(a.position, b.position)
        XCTAssertEqual(a.neighbors, b.neighbors)
        XCTAssertEqual(a.standout, b.standout, accuracy: 0.001)
        XCTAssertTrue(a.notes.contains { $0.contains("will not be read") }, a.notes.joined(separator: " | "))
    }

    func testNeighborSlotsAreTheCellsAround() {
        XCTAssertEqual(ShelfTest.neighborSlots(of: 0, columns: 4, rows: 3).sorted(), [1, 4, 5])
        XCTAssertEqual(ShelfTest.neighborSlots(of: 5, columns: 4, rows: 3).sorted(), [0, 1, 2, 4, 6, 8, 9, 10])
    }

    // MARK: Make it a 90

    func testImproverRaisesAWeakCoverAndStopsWithinMaxSteps() {
        let start = Critic.review(weak)
        var calls: [(Int, Double)] = []
        let o = AutoImprover.run(weak, target: 90, maxSteps: 3) { step, score in calls.append((step, score)) }
        XCTAssertEqual(o.start.score, start.score, accuracy: 0.01)
        XCTAssertGreaterThan(o.report.score, start.score, o.report.issues.map(\.message).joined(separator: "; "))
        XCTAssertLessThanOrEqual(o.steps, 3)
        XCTAssertEqual(calls.count, o.steps)
        XCTAssertEqual(calls.map(\.0), (0..<o.steps).map { $0 + 1 })
        // Every accepted step scored higher than the last.
        if calls.count > 1 { for i in 1..<calls.count { XCTAssertGreaterThan(calls[i].1, calls[i - 1].1) } }
        // The same seed takes the same path.
        let again = AutoImprover.run(weak, target: 90, maxSteps: 3)
        XCTAssertEqual(again.report.score, o.report.score, accuracy: 0.01)
        XCTAssertEqual(again.document.layers.count, o.document.layers.count)
    }

    func testImproverNeverLowersTheScore() {
        for doc in [clean, weak] {
            let before = Critic.review(doc).score
            let (_, after) = AutoImprover.improve(doc, target: 100, maxSteps: 1)
            XCTAssertGreaterThanOrEqual(after.score, before - 0.01)
        }
    }

    func testCoverAlreadyAtTargetReturnsUnchanged() {
        let doc = clean
        let start = Critic.review(doc)
        let (out, report) = AutoImprover.improve(doc, target: start.score, maxSteps: 12)
        XCTAssertEqual(out.layers, doc.layers)
        XCTAssertEqual(out.palette, doc.palette)
        XCTAssertEqual(report.score, start.score, accuracy: 0.01)
        if start.score >= 100 {
            let (o2, r2) = AutoImprover.improve(doc)
            XCTAssertEqual(o2.layers, doc.layers)
            XCTAssertEqual(r2.score, 100, accuracy: 0.01)
        }
    }

    func testCandidateEditsStayInsideTheMargins() {
        let d = clean
        var grown: CoverDocument? = d
        for _ in 0..<8 { grown = grown.flatMap { AutoImprover.scaledTitle($0, factor: 1.4) } ?? grown }
        let f = grown!.textLayer(role: .title)!.frame
        XCTAssertGreaterThanOrEqual(f.x, Critic.textMargin - 0.001)
        XCTAssertLessThanOrEqual(f.maxX, 1 - Critic.textMargin + 0.001)
        XCTAssertGreaterThanOrEqual(f.y, Critic.textMargin - 0.001)
        XCTAssertLessThanOrEqual(f.maxY, 1 - Critic.textMargin + 0.001)
        let tracked = AutoImprover.trackedAuthor(d)!
        let a = tracked.textLayer(role: .author)!.textContent!
        XCTAssertEqual(a.letterCase, .upper)
        XCTAssertEqual(a.tracking, 0.25, accuracy: 0.001)
        XCTAssertNil(AutoImprover.trackedAuthor(tracked), "already tracked: no candidate")
        XCTAssertNotNil(AutoImprover.toggledTitleShadow(d)!.textLayer(role: .title)!.shadow)
    }
}
