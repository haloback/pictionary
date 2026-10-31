import CadenceCore
import SwiftUI

/// Timeline view: every layer as a lane you can mute, solo, extend and tweak.
@MainActor
struct StudioView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                VStack(spacing: 0) {
                    ChordLane()
                    Divider()
                    Timeline()
                }
                .frame(maxWidth: .infinity)
                Divider()
                Inspector()
                    .frame(width: 290)
            }
            Divider()
            KeyboardView()
                .frame(height: 130)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
        .background(Theme.card)
    }
}

@MainActor
struct ChordLane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                SectionLabel("Progression")
                Text(model.session.progression.slots.map { $0.chord.roman(in: model.session.key) }.joined(separator: " – "))
                    .font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                Button("Regenerate") { model.regenerateProgression() }.buttonStyle(PillButtonStyle())
                Button("Vary band") { model.varyBand() }.buttonStyle(PillButtonStyle())
                Button("Drop or import .mid") { model.openImportPanel() }.buttonStyle(PillButtonStyle())
            }
            ChordStrip()
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
    }
}

@MainActor
struct Timeline: View {
    @Environment(AppModel.self) private var model
    static let headerWidth: CGFloat = 230
    static let laneHeight: CGFloat = 72
    @State private var barWidth: CGFloat = 64

    var body: some View {
        let bars = max(model.session.songBars + 4, 8)
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                Ruler(bars: bars, barWidth: barWidth)
                ForEach(model.session.tracks) { t in
                    TrackLane(track: t, bars: bars, barWidth: barWidth)
                }
                AddLayerMenu().padding(16)
            }
            .overlay(alignment: .topLeading) { Playhead(barWidth: barWidth) }
        }
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: 4) {
                Button { barWidth = max(28, barWidth - 12) } label: { Image(systemName: "minus.magnifyingglass") }
                Button { barWidth = min(160, barWidth + 12) } label: { Image(systemName: "plus.magnifyingglass") }
            }
            .buttonStyle(.borderless).padding(10)
            .background(.regularMaterial, in: Capsule()).padding(12)
        }
    }
}

@MainActor
struct Ruler: View {
    @Environment(AppModel.self) private var model
    let bars: Int
    let barWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: Timeline.headerWidth)
            ForEach(0..<bars, id: \.self) { b in
                Text("\(b + 1)").font(.system(size: 11, design: .monospaced)).foregroundStyle(b < model.session.songBars ? HierarchicalShapeStyle.primary : HierarchicalShapeStyle.tertiary)
                    .padding(.leading, 4)
                    .frame(width: barWidth, height: 26, alignment: .leading)
                    .overlay(alignment: .leading) { Rectangle().fill(Theme.stroke).frame(width: 1) }
            }
        }
        .background(Theme.canvas)
    }
}

@MainActor
struct Playhead: View {
    @Environment(AppModel.self) private var model
    let barWidth: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !model.isPlaying)) { _ in
            let beat = model.conductor.currentSongBeat()
            let x = Timeline.headerWidth + CGFloat(beat / Double(model.session.beatsPerBar)) * barWidth
            Rectangle().fill(Theme.record).frame(width: 2)
                .frame(maxHeight: .infinity)
                .offset(x: x)
                .opacity(model.isPlaying ? 1 : 0)
                .allowsHitTesting(false)
        }
    }
}

@MainActor
struct TrackLane: View {
    @Environment(AppModel.self) private var model
    let track: Track
    let bars: Int
    let barWidth: CGFloat
    @State private var dragBars: Int?

    var body: some View {
        let color = Theme.track(track.colorIndex)
        let selected = model.selectedTrackID == track.id
        let songBars = model.session.songBars
        let end = dragBars.map { track.startBar + $0 } ?? track.endBar(songBars: songBars)
        HStack(spacing: 0) {
            HStack(spacing: 10) {
                Button { model.selectedTrackID = track.id } label: {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 4)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                            Text(track.isRecorded ? "Your take · loops every \(track.takeBars) bar\(track.takeBars == 1 ? "" : "s")" : track.roleName + " · auto")
                                .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                ToggleChip(label: "M", on: track.muted, tint: Color(red: 0.95, green: 0.70, blue: 0.24)) { model.toggleMute(track.id) }
                    .accessibilityLabel("Mute \(track.name)")
                ToggleChip(label: "S", on: track.solo, tint: Theme.accent) { model.toggleSolo(track.id) }
                    .accessibilityLabel("Solo \(track.name)")
            }
            .padding(.horizontal, 12)
            .frame(width: Timeline.headerWidth, height: Timeline.laneHeight)
            .background(selected ? Theme.raised : Theme.canvas)
            .overlay(alignment: .trailing) { Rectangle().fill(Theme.stroke).frame(width: 1) }

            ZStack(alignment: .topLeading) {
                // Bar lines.
                HStack(spacing: 0) {
                    ForEach(0..<bars, id: \.self) { _ in
                        Rectangle().fill(Color.clear).frame(width: barWidth)
                            .overlay(alignment: .leading) { Rectangle().fill(Theme.stroke.opacity(0.6)).frame(width: 1) }
                    }
                }
                // Region with its notes.
                let x = CGFloat(track.startBar) * barWidth
                let w = CGFloat(max(end - track.startBar, 1)) * barWidth
                RegionView(notes: model.previews[track.id] ?? [], color: color, startBeat: Double(track.startBar * model.session.beatsPerBar),
                           beats: Double((end - track.startBar) * model.session.beatsPerBar), isDrums: track.profile.isDrums)
                    .frame(width: w, height: Timeline.laneHeight - 16)
                    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(color.opacity(selected ? 1 : 0.4), lineWidth: selected ? 1.5 : 1))
                    .overlay(alignment: .trailing) {
                        // Drag the right edge to make this layer longer or shorter.
                        RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.7)).frame(width: 8)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle().inset(by: -6))
                            .onHover { inside in if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() } }
                            .gesture(DragGesture(minimumDistance: 2)
                                .onChanged { v in
                                    let base = track.endBar(songBars: songBars) - track.startBar
                                    dragBars = max(1, base + Int((v.translation.width / barWidth).rounded()))
                                }
                                .onEnded { _ in
                                    if let b = dragBars { model.setTrackLength(track.id, bars: b) }
                                    dragBars = nil
                                })
                    }
                    .opacity(model.session.isAudible(track) ? 1 : 0.35)
                    .offset(x: x, y: 8)
                    .onTapGesture { model.selectedTrackID = track.id }
                    .onDrag { model.dragProvider(track: track) }
                    .contextMenu {
                        Button("Follow song length") { model.setTrackLength(track.id, bars: nil) }
                        Button("Make 4 bars") { model.setTrackLength(track.id, bars: 4) }
                        Button("Make 8 bars") { model.setTrackLength(track.id, bars: 8) }
                        Button("Make 16 bars") { model.setTrackLength(track.id, bars: 16) }
                        Divider()
                        Button("Delete layer", role: .destructive) { model.deleteTrack(track.id) }
                    }
                if let dragBars {
                    Text("\(dragBars) bars").font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.regularMaterial, in: Capsule())
                        .offset(x: x + CGFloat(dragBars) * barWidth + 8, y: Timeline.laneHeight / 2 - 12)
                }
            }
            .frame(width: CGFloat(bars) * barWidth, height: Timeline.laneHeight, alignment: .topLeading)
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.stroke).frame(height: 1) }
    }
}

@MainActor
struct ToggleChip: View {
    let label: String
    let on: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label).font(.system(size: 11, weight: .heavy))
                .frame(width: 28, height: 28)
                .foregroundStyle(on ? Color.black : Color.secondary)
                .background(on ? tint : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(on ? tint : Theme.stroke))
        }
        .buttonStyle(.plain)
    }
}

/// Piano-roll miniature of a layer.
@MainActor
struct RegionView: View {
    let notes: [NoteEvent]
    let color: Color
    let startBeat: Double
    let beats: Double
    let isDrums: Bool

    var body: some View {
        Canvas { ctx, size in
            let visible = notes.filter { $0.start >= startBeat - 0.01 && $0.start < startBeat + beats }
            guard !visible.isEmpty, beats > 0 else { return }
            let lo = visible.map(\.pitch).min()!, hi = visible.map(\.pitch).max()!
            let span = max(hi - lo, 6)
            for n in visible {
                let x = CGFloat((n.start - startBeat) / beats) * size.width
                let w = isDrums ? 2.5 : max(CGFloat(n.duration / beats) * size.width - 1, 2)
                let y = size.height - 6 - CGFloat(n.pitch - lo) / CGFloat(span) * (size.height - 12)
                let r = CGRect(x: x, y: y - 2, width: w, height: 4)
                ctx.fill(Path(roundedRect: r, cornerRadius: 1.5), with: .color(color.opacity(0.45 + Double(n.velocity) / 127 * 0.55)))
            }
        }
    }
}

@MainActor
struct Inspector: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let track = model.session.tracks.first(where: { $0.id == model.selectedTrackID }) {
                    TrackInspector(track: track)
                } else {
                    Text("Select a layer to shape how it plays.").foregroundStyle(.secondary)
                }
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Snap strength")
                    Picker("Snap", selection: Binding(get: { model.session.snap }, set: { model.setSnap($0) })) {
                        ForEach(SnapStrength.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden()
                    Text(model.session.snap.explanation).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Keys")
                    KeyMapPicker()
                }
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Your hands")
                    HStack {
                        Text(InstrumentProfile.of(model.session.liveInstrument).name).font(.system(size: 14, weight: .semibold))
                        Spacer()
                        InstrumentMenu(selection: model.session.liveInstrument) { model.setLiveInstrument($0) }
                    }
                }
            }
            .padding(18)
        }
        .background(Theme.canvas)
    }
}

@MainActor
struct TrackInspector: View {
    @Environment(AppModel.self) private var model
    let track: Track

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel("Layer · \(track.roleName)")
            Text(track.name).font(.system(size: 18, weight: .bold))
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Instrument").font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer()
                    InstrumentMenu(selection: track.instrument, includeDrums: true) { id in
                        if track.part != nil {
                            model.setPart(track.id) { $0.instrument = id }
                        } else {
                            model.updateTrack(track.id) { $0.instrument = id }
                        }
                        model.updateTrack(track.id) { $0.name = InstrumentProfile.of(id).name + (track.isRecorded ? " take" : "") }
                    }
                }
                Text(track.profile.name).font(.system(size: 14, weight: .semibold))
                Text(track.profile.character).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            LabeledSlider(label: "Volume", value: track.volume, range: 0...1) { v in model.updateTrack(track.id) { $0.volume = v } }
            if let part = track.part {
                LabeledSlider(label: "Humanize", value: track.humanize, range: 0...2) { v in model.updateTrack(track.id) { $0.humanize = v } }
                LabeledSlider(label: "Busyness", value: part.density, range: 0.1...1) { v in model.setPart(track.id) { $0.density = v } }
                PatternPicker(track: track, part: part)
                if case .comp = part.kind { VoicingPicker(track: track, part: part) }
            }
            HStack {
                Button(track.muted ? "Unmute" : "Mute") { model.toggleMute(track.id) }
                Button(track.solo ? "Unsolo" : "Solo") { model.toggleSolo(track.id) }
                Spacer()
                Button("Delete", role: .destructive) { model.deleteTrack(track.id) }
            }
        }
    }
}

@MainActor
struct LabeledSlider: View {
    let label: String
    let value: Double
    let range: ClosedRange<Double>
    let set: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int((value - range.lowerBound) / (range.upperBound - range.lowerBound) * 100))%")
                    .font(.system(size: 12, design: .monospaced))
            }
            Slider(value: Binding(get: { value }, set: set), in: range)
                .controlSize(.small)
        }
    }
}

@MainActor
struct PatternPicker: View {
    @Environment(AppModel.self) private var model
    let track: Track
    let part: PartSpec

    var body: some View {
        HStack {
            Text("Pattern").font(.system(size: 12)).foregroundStyle(.secondary)
            Spacer()
            Menu(currentName) {
                switch part.kind {
                case .comp:
                    ForEach(CompStyle.allCases, id: \.self) { c in Button(Self.title(c.rawValue)) { set(.comp(c)) } }
                case .bass:
                    ForEach(BassStyle.allCases.filter { $0 != .none }, id: \.self) { b in Button(Self.title(b.rawValue)) { set(.bass(b)) } }
                case .drums:
                    ForEach(DrumGroove.allCases.filter { $0 != .none }, id: \.self) { d in Button(Self.title(d.rawValue)) { set(.drums(d)) } }
                case .line:
                    ForEach(LineStyle.allCases, id: \.self) { l in Button(Self.title(l.rawValue)) { set(.line(l)) } }
                }
            }
            .fixedSize()
        }
    }

    var currentName: String {
        switch part.kind {
        case .comp(let c): return Self.title(c.rawValue)
        case .bass(let b): return Self.title(b.rawValue)
        case .drums(let d): return Self.title(d.rawValue)
        case .line(let l): return Self.title(l.rawValue)
        }
    }

    func set(_ kind: PartKind) { model.setPart(track.id) { $0.kind = kind } }

    /// "pushedEighths" -> "Pushed Eighths"
    static func title(_ raw: String) -> String {
        var out = ""
        for c in raw {
            if c.isUppercase || (c.isNumber && !(out.last?.isNumber ?? false)) { out.append(" ") }
            out.append(c)
        }
        return out.prefix(1).uppercased() + out.dropFirst()
    }
}

@MainActor
struct VoicingPicker: View {
    @Environment(AppModel.self) private var model
    let track: Track
    let part: PartSpec

    var body: some View {
        HStack {
            Text("Voicing").font(.system(size: 12)).foregroundStyle(.secondary)
            Spacer()
            Picker("Voicing", selection: Binding(get: { part.voicing ?? track.profile.liveVoicing },
                                                 set: { v in model.setPart(track.id) { $0.voicing = v } })) {
                ForEach(VoicingStyle.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .labelsHidden()
            .fixedSize()
        }
    }
}

// MARK: Keyboard

/// Three octaves showing the scale, the current chord, what you pressed and
/// what sounded. Click keys to play.
@MainActor
struct KeyboardView: View {
    @Environment(AppModel.self) private var model
    let low = 48, high = 84

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { _ in
            let chord = model.session.progression.chord(atBeat: model.conductor.currentSongBeat())
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 16) {
                    legend(Text("You pressed"), RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.record, style: StrokeStyle(lineWidth: 2, dash: [3, 2])))
                    legend(Text("Sounded"), RoundedRectangle(cornerRadius: 3).fill(Theme.accent))
                    legend(Text("Chord tones · \(model.chordName(chord))"), RoundedRectangle(cornerRadius: 3).fill(Theme.accent.opacity(0.22)))
                    Spacer()
                    Text("Mac keys: A W S E D F T G Y H U J K · Z/X octave (\(model.computerOctave))")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                GeometryReader { geo in
                    keys(size: geo.size, chord: chord)
                }
            }
        }
    }

    func legend<S: View>(_ text: Text, _ swatch: S) -> some View {
        HStack(spacing: 6) { swatch.frame(width: 12, height: 12); text.font(.system(size: 12)).foregroundStyle(.secondary) }
    }

    func isBlack(_ p: Int) -> Bool { [1, 3, 6, 8, 10].contains(mod12(p)) }

    /// What each key does in the current key-mapping mode.
    func keyLabel(_ p: Int, chord: Chord) -> String? {
        let mapper = model.keyMapper
        switch model.session.keyMap {
        case .anyKey:
            return !isBlack(p) && mod12(p) == 0 ? "C\(p / 12 - 1)" : nil
        case .whiteKeysScale:
            return model.noteName(isBlack(p) ? mapper.chordTone(forKey: p, chord: chord) : mapper.scalePitch(forKey: p))
        case .chordKeys:
            return mapper.chord(forKey: p).map { model.chordName($0) }
        }
    }

    @ViewBuilder
    func keys(size: CGSize, chord: Chord) -> some View {
        let whites = (low..<high).filter { !isBlack($0) }
        let ww = size.width / CGFloat(whites.count)
        ZStack(alignment: .topLeading) {
            ForEach(Array(whites.enumerated()), id: \.element) { i, p in
                key(p, chord: chord, black: false)
                    .frame(width: ww - 2, height: size.height)
                    .offset(x: CGFloat(i) * ww)
            }
            ForEach((low..<high).filter(isBlack), id: \.self) { p in
                let whitesBefore = whites.filter { $0 < p }.count
                key(p, chord: chord, black: true)
                    .frame(width: ww * 0.6, height: size.height * 0.6)
                    .offset(x: CGFloat(whitesBefore) * ww - ww * 0.3 - 1)
            }
        }
    }

    func key(_ p: Int, chord: Chord, black: Bool) -> some View {
        let inScale = model.session.key.contains(p)
        let inChord = chord.pitchClasses.contains(mod12(p))
        let sounding = model.soundingOutputs.contains(p)
        let pressed = model.heldInputs.contains(p)
        let base: Color = black ? (inScale ? Color(white: 0.22) : Color(white: 0.1)) : (inScale ? .white : Color(white: 0.8))
        let fill: Color = sounding ? Theme.accent : (inChord ? (black ? Theme.accent.opacity(0.55) : Theme.accent.opacity(0.22)) : base)
        return UnevenRoundedRectangle(bottomLeadingRadius: 6, bottomTrailingRadius: 6)
            .fill(fill)
            .overlay(UnevenRoundedRectangle(bottomLeadingRadius: 6, bottomTrailingRadius: 6).strokeBorder(Color.black.opacity(0.15)))
            .overlay {
                if pressed {
                    UnevenRoundedRectangle(bottomLeadingRadius: 6, bottomTrailingRadius: 6)
                        .strokeBorder(Theme.record, style: StrokeStyle(lineWidth: 2, dash: [3, 2])).padding(3)
                }
            }
            .overlay(alignment: .bottom) {
                if let label = keyLabel(p, chord: chord) {
                    Text(label).font(.system(size: black ? 8 : 9, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.5)
                        .foregroundStyle(black ? Color.white.opacity(0.8) : Color.black.opacity(0.6)).padding(.bottom, 4).padding(.horizontal, 1)
                }
            }
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in if !model.heldInputs.contains(p) { model.pianoKey(p, down: true) } }
                .onEnded { _ in model.pianoKey(p, down: false) })
            .accessibilityLabel("Key \(NoteName.nameWithOctave(p, flats: model.session.key.prefersFlats))")
    }
}
