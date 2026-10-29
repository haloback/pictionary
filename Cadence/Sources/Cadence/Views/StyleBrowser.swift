import CadenceCore
import SwiftUI

/// Pick from the whole catalogue: search, filter by family, or wander the map
/// (calm → driving, electronic → acoustic).
@MainActor
struct StyleBrowser: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var family: String?
    @State private var selection: String?
    @State private var keepProgression = false

    var results: [Style] { StyleLibrary.search(query, family: family) }

    var body: some View {
        let results = self.results
        let selected = StyleLibrary.byID[selection ?? model.style.id] ?? model.style
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Choose a style").font(.system(size: 22, weight: .heavy))
                Text("\(results.count) of \(StyleLibrary.all.count)").foregroundStyle(.secondary)
                Spacer()
                TextField("Try “rainy bossa”, “90s gospel”, “late night trio”", text: $query)
                    .textFieldStyle(.roundedBorder).frame(width: 340)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Button("All") { family = nil }.buttonStyle(PillButtonStyle(selected: family == nil, tint: Theme.accent))
                    ForEach(StyleLibrary.families, id: \.self) { f in
                        Button(f) { family = f }.buttonStyle(PillButtonStyle(selected: family == f, tint: Theme.accent))
                    }
                }
            }
            HStack(alignment: .top, spacing: 16) {
                StyleMap(styles: results, selected: selected.id) { selection = $0 }
                    .frame(width: 400, height: 400)
                List(results, selection: $selection) { s in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.name).font(.system(size: 13, weight: .semibold))
                            Text(s.summary).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Text("\(Int(s.tempoRange.lowerBound))–\(Int(s.tempoRange.upperBound))").font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .tag(s.id)
                    .onTapGesture(count: 2) { choose(s) }
                }
                .frame(minWidth: 380)
            }
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(selected.name).font(.system(size: 16, weight: .bold))
                    Text("\(selected.summary)  \(selected.meterLabel) · \(Int(selected.defaultTempo)) BPM · \(selected.parts.map { InstrumentProfile.of($0.instrument).name }.joined(separator: ", "))")
                        .font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer()
                Toggle("Keep my chords", isOn: $keepProgression)
                    .help("Keep the current (or imported) progression instead of writing a new one for this style")
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Play this style") { choose(selected) }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 880, height: 640)
        .onAppear {
            selection = model.style.id
            keepProgression = model.session.progressionSource != "Generated"
        }
    }

    func choose(_ s: Style) {
        model.select(style: s, keepProgression: keepProgression)
        dismiss()
    }
}

@MainActor
struct StyleMap: View {
    let styles: [Style]
    let selected: String
    let pick: (String) -> Void

    nonisolated static let familyColors: [String: Color] = {
        var map: [String: Color] = [:]
        for (i, f) in StyleLibrary.families.enumerated() { map[f] = Theme.track(i + 1) }
        return map
    }()

    /// Spread styles that share coordinates so each dot can be clicked.
    nonisolated static func point(_ s: Style, in size: CGSize) -> CGPoint {
        let h = stableHash(s.id)
        let jx = Double((h & 0xFF)) / 255 - 0.5
        let jy = Double((h >> 8) & 0xFF) / 255 - 0.5
        let x = 0.06 + 0.88 * min(max(s.energy + jx * 0.07, 0), 1)
        let y = 0.06 + 0.88 * (1 - min(max(s.acousticness + jy * 0.07, 0), 1))
        return CGPoint(x: x * size.width, y: y * size.height)
    }

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                for s in styles {
                    let p = Self.point(s, in: size)
                    let isSel = s.id == selected
                    let r: CGFloat = isSel ? 7 : 3.5
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                             with: .color((Self.familyColors[s.family] ?? .gray).opacity(isSel ? 1 : 0.6)))
                    if isSel {
                        ctx.stroke(Path(ellipseIn: CGRect(x: p.x - 13, y: p.y - 13, width: 26, height: 26)), with: .color(.white), lineWidth: 2)
                    }
                }
                func label(_ text: String, _ at: CGPoint) {
                    ctx.draw(Text(text).font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.6)), at: at)
                }
                label("calm", CGPoint(x: 26, y: size.height - 10))
                label("driving", CGPoint(x: size.width - 30, y: size.height - 10))
                label("acoustic", CGPoint(x: 32, y: 12))
                label("electronic", CGPoint(x: 38, y: size.height - 26))
            }
            .background(Color(red: 0.06, green: 0.08, blue: 0.15), in: RoundedRectangle(cornerRadius: 16))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                // Click or drag across the map to audition-select the nearest style.
                let nearest = styles.min { a, b in
                    let pa = Self.point(a, in: geo.size), pb = Self.point(b, in: geo.size)
                    return hypot(pa.x - v.location.x, pa.y - v.location.y) < hypot(pb.x - v.location.x, pb.y - v.location.y)
                }
                if let n = nearest { pick(n.id) }
            })
        }
    }
}
