import CoreGraphics
import Foundation
import XCTest
@testable import Colophon

@MainActor
final class VersionHistoryTests: XCTestCase {
    /// A small, distinct cover per index: the title and ground change, so no two are the same design.
    private func cover(_ n: Int) -> CoverDocument {
        var d = CoverDocument()
        d.canvas = CanvasSpec(width: 100, height: 160)
        d.book.title = "Cover \(n)"
        let ground = RGBA(hex: n % 2 == 0 ? "1A2B4C" : "F1EBDD")
        d.background = ground
        d.palette = [ground, RGBA(hex: "E8562A")]
        d.layers = [Layer.fill(.solid, colors: [ground], frame: .full)]
        d.layers[0].name = "Ground \(n)"
        return d
    }

    func testAddSkipsDuplicates() {
        let h = VersionHistory()
        XCTAssertTrue(h.add(cover(0), reason: "Opened", score: nil))
        XCTAssertFalse(h.add(cover(0), reason: "Edit", score: 80))
        XCTAssertEqual(h.count, 1)
        XCTAssertEqual(h.last?.reason, "Opened")
        XCTAssertTrue(h.add(cover(1), reason: "Randomize", score: 72))
        XCTAssertEqual(h.count, 2)
        XCTAssertEqual(h.last?.reason, "Randomize")
        XCTAssertEqual(h.last?.score, 72)
    }

    func testExplicitReasonRelabelsFreshEditSnapshot() {
        let h = VersionHistory()
        h.add(cover(0), reason: "Opened", score: nil)
        h.add(cover(1), reason: "Edit", score: nil)
        XCTAssertFalse(h.add(cover(1), reason: "Polish", score: 90))
        XCTAssertEqual(h.count, 2)
        XCTAssertEqual(h.last?.reason, "Polish")
        XCTAssertEqual(h.last?.score, 90)
        // A real "Edit" after an explicit one stays as it was.
        XCTAssertFalse(h.add(cover(1), reason: "Edit", score: nil))
        XCTAssertEqual(h.last?.reason, "Polish")
    }

    func testCapDropsOldestUnpinned() {
        let h = VersionHistory()
        for i in 0..<(VersionHistory.capacity + 5) { h.add(cover(i), reason: "Randomize", score: nil) }
        XCTAssertEqual(h.count, VersionHistory.capacity)
        XCTAssertEqual(h.versions.first?.document.book.title, "Cover 5")
        XCTAssertEqual(h.last?.document.book.title, "Cover \(VersionHistory.capacity + 4)")
    }

    func testPinnedSurvivesCap() {
        let h = VersionHistory()
        h.add(cover(0), reason: "Opened", score: nil)
        let keep = h.last!.id
        h.pin(keep)
        XCTAssertTrue(h.isPinned(keep))
        for i in 1..<(VersionHistory.capacity + 10) { h.add(cover(i), reason: "Randomize", score: nil) }
        XCTAssertEqual(h.count, VersionHistory.capacity)
        XCTAssertEqual(h.versions.first?.id, keep)
        XCTAssertEqual(h.versions[1].document.book.title, "Cover 11")
        h.unpin(keep)
        XCTAssertFalse(h.isPinned(keep))
        h.add(cover(999), reason: "Randomize", score: nil)
        XCTAssertNil(h.version(keep))
    }

    func testRemoveAndClear() {
        let h = VersionHistory()
        h.add(cover(0), reason: "Opened", score: nil)
        h.add(cover(1), reason: "Randomize", score: nil)
        let first = h.versions[0].id
        h.pin(first)
        h.remove(first)
        XCTAssertEqual(h.count, 1)
        XCTAssertFalse(h.isPinned(first))
        h.clear()
        XCTAssertEqual(h.count, 0)
        XCTAssertNil(h.last)
    }

    func testSameDesignIgnoresNothingThatMatters() {
        let a = cover(0)
        var b = a
        XCTAssertTrue(VersionHistory.sameDesign(a, b))
        b.layers[0].frame.x += 0.01
        XCTAssertFalse(VersionHistory.sameDesign(a, b))
        var c = a
        c.palette.append(RGBA(hex: "000000"))
        XCTAssertFalse(VersionHistory.sameDesign(a, c))
    }

    func testRestoreThroughEditorModelIsUndoable() {
        let m = EditorModel()
        m.previewHeight = 64
        m.document = cover(0)
        m.snapshot(reason: "Opened")
        XCTAssertEqual(m.versions.count, 1)
        // An edit right after a snapshot is coalesced: no new version yet.
        m.mutate { d in d.book.title = "Changed" }
        XCTAssertEqual(m.versions.count, 1)
        m.snapshot(reason: "Polish")
        XCTAssertEqual(m.versions.count, 2)
        XCTAssertEqual(m.versions.last?.reason, "Polish")

        let first = m.versions.versions[0].id
        m.restoreVersion(first)
        XCTAssertEqual(m.document.book.title, "Cover 0")
        XCTAssertEqual(m.toast, "Restored Opened")
        XCTAssertEqual(m.versions.count, 2, "restoring doesn't add a version")
        XCTAssertTrue(m.canUndo)
        m.undo()
        XCTAssertEqual(m.document.book.title, "Changed")
    }

    func testThumbnailArrives() async {
        let h = VersionHistory()
        h.add(cover(0), reason: "Opened", score: nil)
        XCTAssertNil(h.last?.thumbnail)
        let exp = expectation(description: "thumbnail rendered")
        Task { @MainActor in
            for _ in 0..<60 {
                if h.last?.thumbnail != nil {
                    exp.fulfill()
                    return
                }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }
        await fulfillment(of: [exp], timeout: 3)
        let t = h.last?.thumbnail
        XCTAssertNotNil(t)
        XCTAssertEqual(t?.height, Int(VersionHistory.thumbnailHeight))
        XCTAssertEqual(t?.width, Int((VersionHistory.thumbnailHeight / 1.6).rounded()))
    }
}
