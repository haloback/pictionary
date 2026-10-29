import CoreGraphics
import Foundation

/// A rectangle in normalized cover space: (0,0) is the top-left corner, (1,1) the bottom-right.
/// Layouts are authored in this space so one design re-flows to any store's pixel size.
struct NRect: Codable, Hashable {
    var x: Double
    var y: Double
    var w: Double
    var h: Double

    init(x: Double, y: Double, w: Double, h: Double) {
        self.x = x; self.y = y; self.w = w; self.h = h
    }

    init(_ x: Double, _ y: Double, _ w: Double, _ h: Double) {
        self.init(x: x, y: y, w: w, h: h)
    }

    static let full = NRect(0, 0, 1, 1)

    var midX: Double { x + w / 2 }
    var midY: Double { y + h / 2 }
    var maxX: Double { x + w }
    var maxY: Double { y + h }

    /// Pixel rect in a top-left-origin space of the given size.
    func pixels(in size: CGSize) -> CGRect {
        CGRect(x: x * size.width, y: y * size.height, width: w * size.width, height: h * size.height)
    }

    func insetBy(dx: Double, dy: Double) -> NRect {
        NRect(x + dx, y + dy, max(0.001, w - 2 * dx), max(0.001, h - 2 * dy))
    }

    func intersectionArea(_ o: NRect) -> Double {
        let ix = max(0, min(maxX, o.maxX) - max(x, o.x))
        let iy = max(0, min(maxY, o.maxY) - max(y, o.y))
        return ix * iy
    }

    var area: Double { w * h }

    func contains(_ px: Double, _ py: Double) -> Bool {
        px >= x && px <= maxX && py >= y && py <= maxY
    }
}

/// Golden-ratio constants used throughout layout, guides and snapping.
enum Golden {
    static let phi = (1 + sqrt(5.0)) / 2
    /// 0.382: the smaller golden section.
    static let minor = 1 - 1 / phi
    /// 0.618: the larger golden section.
    static let major = 1 / phi
    /// Lines a designer would snap to, horizontally or vertically.
    static let snapLines: [Double] = [0.05, minor / 2, 1.0 / 3.0, minor, 0.5, major, 2.0 / 3.0, 1 - minor / 2, 0.95]
}

extension Double {
    var clamped01: Double { Swift.min(1, Swift.max(0, self)) }
    func clamped(_ lo: Double, _ hi: Double) -> Double { Swift.min(hi, Swift.max(lo, self)) }
}

extension CGFloat {
    func clamped(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat { Swift.min(hi, Swift.max(lo, self)) }
}

/// Deterministic random numbers so a design seed always reproduces the same cover.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed)) &+ 0x9E37_79B9_7F4A_7C15
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> Double {
        Double(next() >> 11) / Double(UInt64(1) << 53)
    }

    mutating func range(_ a: Double, _ b: Double) -> Double {
        a + (b - a) * unit()
    }

    mutating func int(_ upper: Int) -> Int {
        upper <= 0 ? 0 : Int(next() % UInt64(upper))
    }

    mutating func pick<T>(_ items: [T]) -> T {
        items[int(items.count)]
    }
}
