import SwiftUI

/// The live cover with direct manipulation: select, drag, resize, snap to golden lines.
struct CanvasArea: View {
    @Environment(EditorModel.self) private var model
    @State private var drag: DragState?
    @State private var hoverPoint: CGPoint?
    @State private var painting = false
    @FocusState private var focused: Bool

    struct DragState {
        var layerID: UUID
        var handle: Handle?
        var start: NRect
    }

    enum Handle: CaseIterable {
        case tl, t, tr, r, br, b, bl, l
        func point(_ f: CGRect) -> CGPoint {
            switch self {
            case .tl: return CGPoint(x: f.minX, y: f.minY)
            case .t: return CGPoint(x: f.midX, y: f.minY)
            case .tr: return CGPoint(x: f.maxX, y: f.minY)
            case .r: return CGPoint(x: f.maxX, y: f.midY)
            case .br: return CGPoint(x: f.maxX, y: f.maxY)
            case .b: return CGPoint(x: f.midX, y: f.maxY)
            case .bl: return CGPoint(x: f.minX, y: f.maxY)
            case .l: return CGPoint(x: f.minX, y: f.midY)
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            let rect = fitRect(in: geo.size)
            ZStack(alignment: .topLeading) {
                Theme.canvasBackdrop
                cover
                    .frame(width: rect.width, height: rect.height)
                    .shadow(color: .black.opacity(0.45), radius: 24, y: 10)
                    .offset(x: rect.minX, y: rect.minY)
                Canvas { ctx, _ in drawOverlay(ctx, rect: rect) }
                    .allowsHitTesting(false)
                if model.tool != .select, let p = hoverPoint {
                    let d = CGFloat(model.brushSize) * rect.width
                    Circle()
                        .strokeBorder(model.tool == .erase ? Color.white : Theme.accent, lineWidth: 1.5)
                        .background(Circle().fill((model.tool == .erase ? Color.black : Theme.accent).opacity(0.12)))
                        .frame(width: d, height: d)
                        .position(p)
                        .allowsHitTesting(false)
                }
                if model.tool != .select {
                    brushBanner
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, 12)
                }
                if model.showThumbnailPreview, let p = model.preview {
                    thumbnailPreview(p)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(18)
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let p): hoverPoint = p
                case .ended: hoverPoint = nil
                }
            }
            .gesture(dragGesture(rect: rect))
            .simultaneousGesture(SpatialTapGesture(count: 2).onEnded { v in
                if let id = hit(v.location, rect: rect), model.document.layer(id)?.textContent != nil {
                    model.selection = id
                    model.inspectorTab = .layer
                    model.showInspector = true
                }
            })
            .simultaneousGesture(SpatialTapGesture().onEnded { v in
                if model.tool != .select {
                    if let id = brushTarget {
                        let (x, y) = normalized(v.location, rect)
                        model.beginStroke(layer: id, canvasX: x, canvasY: y)
                    }
                    return
                }
                model.selection = hit(v.location, rect: rect)
            })
            .onChange(of: rect.height, initial: true) { _, h in
                let target = (h * 2).clamped(900, 2200)
                if abs(target - model.previewHeight) / model.previewHeight > 0.15 {
                    model.previewHeight = target
                    model.scheduleRender()
                }
            }
        }
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear { focused = true }
        .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow], phases: [.down, .repeat]) { press in
            let step = press.modifiers.contains(.shift) ? 0.02 : 0.002
            switch press.key {
            case .leftArrow: model.nudge(dx: -step, dy: 0)
            case .rightArrow: model.nudge(dx: step, dy: 0)
            case .upArrow: model.nudge(dx: 0, dy: -step)
            default: model.nudge(dx: 0, dy: step)
            }
            return .handled
        }
        .onKeyPress(.delete) {
            model.deleteSelected()
            return .handled
        }
        .onKeyPress(.escape) {
            if model.tool != .select { model.tool = .select; return .handled }
            model.selection = nil
            return .handled
        }
    }

    @ViewBuilder
    private var cover: some View {
        if let img = model.preview {
            Image(decorative: img, scale: 1)
                .resizable()
                .interpolation(.high)
        } else {
            Rectangle().fill(model.document.background.color)
                .overlay(ProgressView())
        }
    }

    private func thumbnailPreview(_ img: CGImage) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach([60.0, 100.0], id: \.self) { w in
                    Image(decorative: img, scale: 1)
                        .resizable()
                        .interpolation(.medium)
                        .frame(width: w, height: w * model.document.canvas.aspect)
                        .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                }
            }
            .padding(10)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 6))
            Text("At store thumbnail size")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .help("How the cover reads in search results and also-boughts. If the title is readable here, you're in good shape.")
    }

    // MARK: Geometry

    private func fitRect(in size: CGSize) -> CGRect {
        let pad: CGFloat = 44
        let aspect = CGFloat(model.document.canvas.aspect)
        let availW = max(10, size.width - pad * 2), availH = max(10, size.height - pad * 2)
        var h = availH
        var w = h / aspect
        if w > availW { w = availW; h = w * aspect }
        return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
    }

    private func normalized(_ p: CGPoint, _ rect: CGRect) -> (Double, Double) {
        (Double((p.x - rect.minX) / rect.width), Double((p.y - rect.minY) / rect.height))
    }

    /// Topmost unlocked layer under the point, preferring things smaller than the whole cover.
    private func hit(_ p: CGPoint, rect: CGRect) -> UUID? {
        let (x, y) = normalized(p, rect)
        guard x >= 0, x <= 1, y >= 0, y <= 1 else { return nil }
        let hits = model.document.layers.reversed().filter { $0.isVisible && $0.frame.contains(x, y) }
        return (hits.first { $0.frame.area < 0.85 && !$0.isLocked } ?? hits.first { !$0.isLocked } ?? hits.first)?.id
    }

    private func handleHit(_ p: CGPoint, rect: CGRect) -> Handle? {
        guard let l = model.selectedLayer, !l.isLocked else { return nil }
        let f = l.frame.pixels(in: rect.size).offsetBy(dx: rect.minX, dy: rect.minY)
        return Handle.allCases.first { h in
            let hp = h.point(f)
            return abs(hp.x - p.x) < 8 && abs(hp.y - p.y) < 8
        }
    }

    private func dragGesture(rect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { v in
                hoverPoint = v.location
                if model.tool != .select {
                    guard let id = brushTarget else { return }
                    let (x, y) = normalized(v.location, rect)
                    if !painting {
                        painting = true
                        let (sx, sy) = normalized(v.startLocation, rect)
                        model.beginStroke(layer: id, canvasX: sx, canvasY: sy)
                    }
                    model.extendStroke(layer: id, canvasX: x, canvasY: y)
                    return
                }
                if drag == nil {
                    if let h = handleHit(v.startLocation, rect: rect), let l = model.selectedLayer {
                        drag = DragState(layerID: l.id, handle: h, start: l.frame)
                    } else if let id = hit(v.startLocation, rect: rect), let l = model.document.layer(id), !l.isLocked {
                        model.selection = id
                        drag = DragState(layerID: id, handle: nil, start: l.frame)
                    } else {
                        return
                    }
                }
                guard let d = drag else { return }
                let dx = Double(v.translation.width / rect.width), dy = Double(v.translation.height / rect.height)
                var f = d.start
                var snapsX: [Double] = [], snapsY: [Double] = []
                if let h = d.handle {
                    let minS = 0.01
                    switch h {
                    case .tl, .l, .bl: f.x = min(d.start.maxX - minS, d.start.x + dx); f.w = d.start.maxX - f.x
                    case .tr, .r, .br: f.w = max(minS, d.start.w + dx)
                    default: break
                    }
                    switch h {
                    case .tl, .t, .tr: f.y = min(d.start.maxY - minS, d.start.y + dy); f.h = d.start.maxY - f.y
                    case .bl, .b, .br: f.h = max(minS, d.start.h + dy)
                    default: break
                    }
                } else {
                    f.x += dx
                    f.y += dy
                    if model.showGuides {
                        (f.x, snapsX) = snap(f.x, f.w, threshold: 7 / Double(rect.width))
                        (f.y, snapsY) = snap(f.y, f.h, threshold: 7 / Double(rect.height))
                    }
                }
                model.activeSnapLines = (snapsX, snapsY)
                let final = f
                model.mutate(undoKey: "drag-\(d.layerID)") { doc in
                    if let i = doc.index(of: d.layerID) { doc.layers[i].frame = final }
                }
            }
            .onEnded { _ in
                painting = false
                drag = nil
                model.activeSnapLines = ([], [])
            }
    }

    /// The image layer the brush paints on: the selection, else the main photo.
    private var brushTarget: UUID? {
        if let l = model.selectedLayer, l.imageContent != nil { return l.id }
        return model.document.photoLayers.first?.id
    }

    private var brushBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: model.tool == .erase ? "eraser" : "paintbrush.pointed")
            Text(model.tool == .erase ? "Erasing from \(model.document.layer(brushTarget)?.name ?? "photo")" : "Restoring \(model.document.layer(brushTarget)?.name ?? "photo")")
                .font(.system(size: 12, weight: .medium))
            Slider(value: Binding(get: { model.brushSize }, set: { model.brushSize = $0 }), in: 0.01...0.2)
                .frame(width: 110)
                .controlSize(.small)
            Button("Done") { model.tool = .select }
                .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.hairline))
    }

    /// Snaps an edge or center of a span to the golden, thirds, center and margin lines.
    private func snap(_ origin: Double, _ size: Double, threshold: Double) -> (Double, [Double]) {
        var best: (delta: Double, line: Double)?
        for line in Golden.snapLines {
            for (offset, _) in [(0.0, 0), (size / 2, 1), (size, 2)] {
                let delta = line - (origin + offset)
                if abs(delta) < threshold && (best == nil || abs(delta) < abs(best!.delta)) { best = (delta, line) }
            }
        }
        guard let b = best else { return (origin, []) }
        return (origin + b.delta, [b.line])
    }

    // MARK: Overlay

    private func drawOverlay(_ ctx: GraphicsContext, rect: CGRect) {
        let accent = Theme.accent
        if model.showGuides {
            let guide = Color.white.opacity(0.32)
            var p = Path()
            let lines: [Double]
            switch model.guideStyle {
            case .golden: lines = [Golden.minor, Golden.major]
            case .thirds: lines = [1.0 / 3.0, 2.0 / 3.0]
            case .spiral, .safe: lines = []
            }
            for t in lines {
                let x = rect.minX + rect.width * t, y = rect.minY + rect.height * t
                p.move(to: CGPoint(x: x, y: rect.minY)); p.addLine(to: CGPoint(x: x, y: rect.maxY))
                p.move(to: CGPoint(x: rect.minX, y: y)); p.addLine(to: CGPoint(x: rect.maxX, y: y))
            }
            ctx.stroke(p, with: .color(guide), lineWidth: 0.75)
            if model.guideStyle == .spiral {
                ctx.stroke(Self.spiral(in: rect), with: .color(guide), lineWidth: 1)
            }
            let m = Preflight.safeMargin
            let safe = CGRect(x: rect.minX + rect.width * m, y: rect.minY + rect.height * m * 0.6,
                              width: rect.width * (1 - 2 * m), height: rect.height * (1 - 1.2 * m))
            ctx.stroke(Path(safe), with: .color(Color.white.opacity(0.22)), style: StrokeStyle(lineWidth: 0.75, dash: [4, 4]))
        }

        var snapPath = Path()
        for x in model.activeSnapLines.x {
            let px = rect.minX + rect.width * x
            snapPath.move(to: CGPoint(x: px, y: rect.minY)); snapPath.addLine(to: CGPoint(x: px, y: rect.maxY))
        }
        for y in model.activeSnapLines.y {
            let py = rect.minY + rect.height * y
            snapPath.move(to: CGPoint(x: rect.minX, y: py)); snapPath.addLine(to: CGPoint(x: rect.maxX, y: py))
        }
        ctx.stroke(snapPath, with: .color(accent), lineWidth: 1)

        guard let l = model.selectedLayer else { return }
        let f = l.frame.pixels(in: rect.size).offsetBy(dx: rect.minX, dy: rect.minY)
        var c = ctx
        if l.rotation != 0 {
            c.translateBy(x: f.midX, y: f.midY)
            c.rotate(by: .degrees(l.rotation))
            c.translateBy(x: -f.midX, y: -f.midY)
        }
        c.stroke(Path(f), with: .color(accent), style: StrokeStyle(lineWidth: 1.25, dash: l.isLocked ? [4, 3] : []))
        guard !l.isLocked else { return }
        for h in Handle.allCases {
            let pt = h.point(f)
            let r = CGRect(x: pt.x - 4, y: pt.y - 4, width: 8, height: 8)
            c.fill(Path(r), with: .color(.white))
            c.stroke(Path(r), with: .color(accent), lineWidth: 1.25)
        }
    }

    /// Fibonacci arcs through successive golden squares, chained end to end.
    static func spiral(in r: CGRect) -> Path {
        var p = Path()
        var rect = r
        for i in 0..<10 {
            let s = min(rect.width, rect.height)
            guard s > 1 else { break }
            let a: CGPoint, b: CGPoint, c: CGPoint
            switch i % 4 {
            case 0:
                let piece = CGRect(x: rect.minX, y: rect.minY, width: s, height: s)
                a = CGPoint(x: piece.maxX, y: piece.minY); b = CGPoint(x: piece.minX, y: piece.minY); c = CGPoint(x: piece.minX, y: piece.maxY)
                rect = CGRect(x: rect.minX, y: rect.minY + s, width: rect.width, height: rect.height - s)
            case 1:
                let piece = CGRect(x: rect.minX, y: rect.minY, width: s, height: s)
                a = CGPoint(x: piece.minX, y: piece.minY); b = CGPoint(x: piece.minX, y: piece.maxY); c = CGPoint(x: piece.maxX, y: piece.maxY)
                rect = CGRect(x: rect.minX + s, y: rect.minY, width: rect.width - s, height: rect.height)
            case 2:
                let piece = CGRect(x: rect.minX, y: rect.maxY - s, width: s, height: s)
                a = CGPoint(x: piece.minX, y: piece.maxY); b = CGPoint(x: piece.maxX, y: piece.maxY); c = CGPoint(x: piece.maxX, y: piece.minY)
                rect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - s)
            default:
                let piece = CGRect(x: rect.maxX - s, y: rect.minY, width: s, height: s)
                a = CGPoint(x: piece.maxX, y: piece.maxY); b = CGPoint(x: piece.maxX, y: piece.minY); c = CGPoint(x: piece.minX, y: piece.minY)
                rect = CGRect(x: rect.minX, y: rect.minY, width: rect.width - s, height: rect.height)
            }
            if i == 0 { p.move(to: a) }
            p.addArc(tangent1End: b, tangent2End: c, radius: s)
            p.move(to: c)
        }
        return p
    }
}
