import CadenceCore
import SwiftUI

/// The default, performance-first screen: the chord loop, what your hands are
/// doing, your instrument, and the band's layers.
@MainActor
struct StageView: View {
    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top, spacing: 20) {
                ProgressionCard()
                    .frame(minWidth: 480)
                VStack(spacing: 20) {
                    SnapRailCard()
                    InstrumentCard()
                }
                .frame(minWidth: 380, maxWidth: 560)
            }
            LayerBar()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
}

// MARK: Progression

@MainActor
struct ProgressionCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Card {
            VStack(spacing: 18) {
                HStack {
                    TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                        let slot = currentSlot
                        SectionLabel("\(model.isPlaying ? "Now playing" : "Progression") · chord \(slot + 1) of \(model.session.progression.slots.count) · \(model.session.progressionSource)")
                    }
                    Spacer()
                    FamousProgressionsMenu()
                    Button("Type chords") { model.showChordEditor = true }.buttonStyle(PillButtonStyle())
                    Button("Import .mid") { model.openImportPanel() }.buttonStyle(PillButtonStyle())
                    Button { model.regenerateProgression() } label: { Label("Reharmonize", systemImage: "sparkles") }
                        .buttonStyle(PillButtonStyle(selected: true, tint: Theme.accent))
                        .help("Write a new progression for this style (⌘G)")
                }
                ProgressionRing()
                    .frame(width: 360, height: 360)
                ChordStrip()
            }
        }
    }

    var currentSlot: Int {
        model.session.progression.slotIndex(atBeat: model.conductor.currentSongBeat())
    }
}

@MainActor
struct ProgressionRing: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !model.isPlaying)) { _ in
            let prog = model.session.progression
            let beat = model.conductor.currentSongBeat()
            let loopPos = beat.truncatingRemainder(dividingBy: prog.totalBeats) / prog.totalBeats
            let current = prog.slotIndex(atBeat: beat)
            let chord = prog.slots[safe: current]?.chord ?? Chord(root: 0, quality: .major)
            ZStack {
                Circle().stroke(Theme.raised, lineWidth: 26)
                ForEach(Array(segments(prog).enumerated()), id: \.offset) { i, seg in
                    Circle()
                        .trim(from: seg.0 + 0.006, to: seg.1 - 0.006)
                        .stroke(i == current ? Theme.accent : (i < current ? Theme.accent.opacity(0.28) : Color.primary.opacity(0.08)),
                                style: StrokeStyle(lineWidth: 26, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                }
                GeometryReader { geo in
                    let r = min(geo.size.width, geo.size.height) / 2 - 13
                    let angle = loopPos * 2 * .pi - .pi / 2
                    Circle().fill(Theme.card).overlay(Circle().strokeBorder(Theme.ink, lineWidth: 4))
                        .frame(width: 22, height: 22)
                        .position(x: geo.size.width / 2 + r * cos(angle), y: geo.size.height / 2 + r * sin(angle))
                        .opacity(model.isPlaying ? 1 : 0)
                }
                VStack(spacing: 6) {
                    Text(chord.roman(in: model.session.key)).font(.system(size: 14, weight: .bold)).foregroundStyle(.secondary)
                    Text(model.chordName(chord)).font(.system(size: 64, weight: .heavy)).tracking(-2)
                        .minimumScaleFactor(0.5).lineLimit(1)
                    Text(model.voicingText(chord)).font(.system(size: 12)).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).frame(maxWidth: 210)
                }
                .padding(60)
            }
        }
    }

    func segments(_ prog: Progression) -> [(Double, Double)] {
        var acc = 0.0
        return prog.slots.map { s in
            let start = acc / prog.totalBeats
            acc += s.beats
            return (start, acc / prog.totalBeats)
        }
    }
}

@MainActor
struct ChordStrip: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { _ in
            let current = model.session.progression.slotIndex(atBeat: model.conductor.currentSongBeat())
            HStack(spacing: 10) {
                ForEach(Array(model.session.progression.slots.enumerated()), id: \.element.id) { i, slot in
                    ChordCardView(index: i, slot: slot, isCurrent: model.isPlaying && i == current)
                }
            }
        }
    }
}

@MainActor
struct ChordCardView: View {
    @Environment(AppModel.self) private var model
    let index: Int
    let slot: ChordSlot
    let isCurrent: Bool

    var body: some View {
        Menu {
            let ideas = model.reharmonizations(for: index)
            ForEach([Reharmonizer.Kind.color, .substitute, .borrowed], id: \.self) { kind in
                Section(kind.rawValue) {
                    ForEach(ideas.filter { $0.kind == kind }, id: \.self) { s in
                        Button("\(model.chordName(s.chord))   ·  \(s.reason)") { model.replaceChord(at: index, with: s.chord) }
                    }
                }
            }
            Section("Lead into the next chord (splits this one)") {
                ForEach(ideas.filter { $0.kind == .leading }, id: \.self) { s in
                    Button("\(model.chordName(s.chord))   ·  \(s.reason)") { model.insertLeadIn(at: index, chord: s.chord) }
                }
            }
            Menu("Any chord in the key") {
                ForEach(model.chordSuggestions(for: index), id: \.self) { c in
                    Button("\(model.chordName(c))   \(c.roman(in: model.session.key))") { model.replaceChord(at: index, with: c) }
                }
            }
            Section("Length") {
                ForEach([1.0, 2, 4, 8], id: \.self) { b in
                    Button("\(Int(b)) beat\(b == 1 ? "" : "s")") { model.setChordLength(at: index, beats: b) }
                }
            }
            Button("Insert chord after") { model.insertChord(after: index) }
            Button("Remove chord", role: .destructive) { model.deleteChord(at: index) }
        } label: {
            VStack(spacing: 2) {
                Text(model.chordName(slot.chord)).font(.system(size: 20, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.6)
                Text("\(slot.chord.roman(in: model.session.key)) · \(Int(slot.beats)) beats").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(isCurrent ? Theme.raised : Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isCurrent ? Theme.accent : Theme.stroke, lineWidth: isCurrent ? 2 : 1))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
    }
}

@MainActor
struct ChordTextEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Type a progression").font(.title2.weight(.bold))
            Text("Separate chords with spaces. Use | to split bars, e.g. “Dm9 G13 | Cmaj9 | A7b13”. Without bars, each chord gets one bar.")
                .font(.callout).foregroundStyle(.secondary)
            TextField("Fm9 B♭13 A♭maj9 Cm11", text: $text)
                .textFieldStyle(.roundedBorder).font(.system(size: 16, design: .monospaced))
                .onSubmit(apply)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Use these chords", action: apply).keyboardShortcut(.defaultAction).disabled(text.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 520)
        .onAppear {
            text = model.session.progression.slots.map { model.chordName($0.chord) }.joined(separator: " ")
        }
    }

    func apply() {
        if model.importText(text) { dismiss() }
    }
}

// MARK: Snap rail

@MainActor
struct SnapRailCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Card(dark: true) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionLabel("What you played → what we heard")
                    Spacer()
                    Text(model.correctedCount == 0 ? "No wrong notes yet" : "\(model.correctedCount) notes fixed")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                SnapRail(hits: model.recentHits, key: model.session.key)
                    .frame(height: 170)
                HStack(spacing: 18) {
                    Label { Text("Key you hit") } icon: { Circle().strokeBorder(Color.secondary, lineWidth: 2).frame(width: 10, height: 10) }
                    Label { Text("Note that sounded") } icon: { Circle().fill(Color(red: 0.55, green: 0.52, blue: 1)).frame(width: 10, height: 10) }
                }
                .font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
    }
}

@MainActor
struct SnapRail: View {
    let hits: [SnapHit]
    let key: Key

    var body: some View {
        Canvas { ctx, size in
            let shown = Array(hits.suffix(16))
            let all = shown.flatMap { [$0.input] + $0.outputs }
            let center = all.isEmpty ? 64 : (all.min()! + all.max()!) / 2
            let lo = min(all.min() ?? 58, center - 6), hi = max(all.max() ?? 70, center + 6)
            let rows = max(hi - lo + 1, 13)
            let rowH = size.height / CGFloat(rows)
            func y(_ p: Int) -> CGFloat { size.height - (CGFloat(p - lo) + 0.5) * rowH }

            // Scale rows.
            for p in lo...(lo + rows - 1) where key.contains(p) {
                let r = CGRect(x: 0, y: y(p) - rowH / 2, width: size.width, height: rowH)
                ctx.fill(Path(r), with: .color(.white.opacity(mod12(p - key.tonic) == 0 ? 0.08 : 0.035)))
                if mod12(p - key.tonic) == 0 || rowH > 9 {
                    ctx.draw(Text(key.name(of: p)).font(.system(size: 9)).foregroundStyle(.white.opacity(0.5)),
                             at: CGPoint(x: 14, y: y(p)))
                }
            }
            let step = (size.width - 40) / 16
            let accent = Color(red: 0.55, green: 0.52, blue: 1)
            for (i, h) in shown.enumerated() {
                let x = 34 + CGFloat(i) * step + step / 2
                let fade = 0.35 + 0.65 * Double(i + 1) / Double(shown.count)
                for o in h.outputs where o != h.input {
                    var line = Path()
                    line.move(to: CGPoint(x: x, y: y(h.input)))
                    line.addLine(to: CGPoint(x: x, y: y(o)))
                    ctx.stroke(line, with: .color(accent.opacity(0.5 * fade)), lineWidth: 2)
                }
                if h.corrected {
                    ctx.stroke(Path(ellipseIn: CGRect(x: x - 6, y: y(h.input) - 6, width: 12, height: 12)),
                               with: .color(.white.opacity(0.6 * fade)), lineWidth: 2)
                }
                for o in h.outputs {
                    ctx.fill(Path(ellipseIn: CGRect(x: x - 6, y: y(o) - 6, width: 12, height: 12)), with: .color(accent.opacity(fade)))
                }
            }
            if shown.isEmpty {
                ctx.draw(Text("Play anything. Every note lands in \(key.displayName).").font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7)), at: CGPoint(x: size.width / 2, y: size.height / 2))
            }
        }
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: Instrument

@MainActor
struct InstrumentCard: View {
    @Environment(AppModel.self) private var model

    static let quick: [InstrumentID] = [.grandPiano, .rhodes, .steelGuitar, .violin, .strings, .horns, .choir, .vibraphone]

    var body: some View {
        let current = InstrumentProfile.of(model.session.liveInstrument)
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionLabel("Your hands become")
                    Spacer()
                    InstrumentMenu(selection: current.id) { model.setLiveInstrument($0) }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(Self.quick, id: \.self) { id in
                        let p = InstrumentProfile.of(id)
                        Button { model.setLiveInstrument(id) } label: {
                            Text(p.name).font(.system(size: 13, weight: .bold)).lineLimit(1).minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .foregroundStyle(id == current.id ? Theme.canvas : Theme.ink)
                                .background(id == current.id ? Theme.ink : Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.stroke))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text(current.character).font(.system(size: 14)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                KeyMapPicker()
            }
        }
    }
}

@MainActor
struct InstrumentMenu: View {
    let selection: InstrumentID
    var includeDrums = false
    let pick: (InstrumentID) -> Void

    var body: some View {
        Menu {
            ForEach(InstrumentProfile.Family.allCases, id: \.self) { family in
                if includeDrums || family != .drums {
                    Section(family.rawValue) {
                        ForEach(InstrumentProfile.all.filter { $0.family == family }, id: \.id) { p in
                            Button { pick(p.id) } label: {
                                if p.id == selection { Label(p.name, systemImage: "checkmark") } else { Text(p.name) }
                            }
                        }
                    }
                }
            }
        } label: {
            Text("All instruments").font(.system(size: 12, weight: .semibold))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}

// MARK: Layers

@MainActor
struct LayerBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Card(padding: 16) {
            HStack(spacing: 16) {
                RecordButton()
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.isRecording ? "Recording take \(model.takeCount + 1)" : (model.isPlaying ? "Band is playing" : "Ready. Just start playing"))
                        .font(.system(size: 16, weight: .heavy))
                    TimelineView(.periodic(from: .now, by: 0.2)) { _ in
                        let bar = Int(model.conductor.currentSongBeat() / Double(model.session.beatsPerBar)) + 1
                        Text(model.isPlaying ? "Bar \(bar) of \(model.isRecording ? bar : model.session.songBars) · \(model.style.meterLabel)"
                             : "\(model.session.songBars)-bar loop · ⌘R record · space play")
                            .font(.system(size: 12)).foregroundStyle(.secondary).monospacedDigit()
                    }
                }
                .frame(minWidth: 190, alignment: .leading)
                Button { model.togglePlay() } label: {
                    Image(systemName: model.isPlaying ? "stop.fill" : "play.fill").font(.system(size: 16, weight: .bold))
                        .frame(width: 44, height: 44).background(Theme.raised, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(model.isPlaying ? "Stop" : "Play")
                Divider().frame(height: 44)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(model.session.tracks) { t in LayerPill(track: t) }
                        AddLayerMenu()
                    }
                }
            }
        }
    }
}

@MainActor
struct RecordButton: View {
    @Environment(AppModel.self) private var model
    @State private var pulse = false

    var body: some View {
        Button { model.toggleRecord() } label: {
            ZStack {
                Circle().fill(model.isRecording ? Theme.record : Theme.card)
                Circle().strokeBorder(model.isRecording ? Theme.record.opacity(0.3) : Theme.stroke, lineWidth: 4)
                if model.isRecording {
                    RoundedRectangle(cornerRadius: 4).fill(.white).frame(width: 18, height: 18)
                } else {
                    Circle().fill(Theme.record).frame(width: 24, height: 24)
                }
            }
            .frame(width: 64, height: 64)
            .scaleEffect(model.isRecording && pulse ? 1.05 : 1)
            .animation(model.isRecording ? .easeInOut(duration: 0.6).repeatForever() : .default, value: pulse)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(model.isRecording ? "Stop recording" : "Record")
        .help("Record a take (⌘R). Stop to keep it as a new layer.")
        .onChange(of: model.isRecording) { _, rec in pulse = rec }
    }
}

@MainActor
struct LayerPill: View {
    @Environment(AppModel.self) private var model
    let track: Track

    var body: some View {
        let color = Theme.track(track.colorIndex)
        let audible = model.session.isAudible(track)
        Button { model.toggleMute(track.id) } label: {
            HStack(spacing: 8) {
                Circle().strokeBorder(color, lineWidth: 2).background(Circle().fill(audible ? color : .clear)).frame(width: 10, height: 10)
                Text(track.name).lineLimit(1)
                if track.solo { Text("S").font(.system(size: 10, weight: .heavy)).foregroundStyle(Theme.accent) }
            }
            .font(.system(size: 13, weight: .bold))
            .strikethrough(!audible)
            .foregroundStyle(audible ? Theme.ink : Color.secondary)
            .padding(.horizontal, 16).frame(height: 44)
            .background(audible ? Theme.card : Theme.canvas, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.stroke))
            .onDrag { model.dragProvider(track: track) }
        }
        .buttonStyle(.plain)
        .help("\(track.roleName). Click to mute, right-click for more, drag out for this layer's MIDI.")
        .contextMenu {
            Button(track.muted ? "Unmute" : "Mute") { model.toggleMute(track.id) }
            Button(track.solo ? "Unsolo" : "Solo") { model.toggleSolo(track.id) }
            Button("Edit in Studio") { model.selectedTrackID = track.id; model.mode = .studio }
            Divider()
            Button("Delete layer", role: .destructive) { model.deleteTrack(track.id) }
        }
    }
}

@MainActor
struct AddLayerMenu: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Menu {
            Button("Chords · Piano") { model.addLayer(.comp(.halfNotes), instrument: .grandPiano) }
            Button("Chords · Guitar strum") { model.addLayer(.comp(.strum8), instrument: .steelGuitar) }
            Button("Arpeggio · Harp") { model.addLayer(.comp(.arpUp), instrument: .harp) }
            Button("Bass") { model.addLayer(.bass(.pop), instrument: .fingerBass) }
            Button("Drums") { model.addLayer(.drums(.pop), instrument: .drumKit) }
            Button("Percussion") { model.addLayer(.drums(.afrobeats), instrument: .percussion) }
            Button("Strings pad") { model.addLayer(.line(.pad), instrument: .strings) }
            Button("Violin melody") { model.addLayer(.line(.topVoice), instrument: .violin) }
            Button("Flute answers") { model.addLayer(.line(.counterMelody), instrument: .flute) }
            Button("Horn stabs") { model.addLayer(.comp(.hornStabs), instrument: .horns) }
            Button("Choir") { model.addLayer(.line(.pad), instrument: .choir) }
        } label: {
            Text("+ Layer").font(.system(size: 13, weight: .bold)).padding(.horizontal, 16).frame(height: 44)
                .overlay(Capsule().strokeBorder(Color.secondary.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

@MainActor
struct FamousProgressionsMenu: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Menu {
            let moods = NamedProgression.library.reduce(into: [String]()) { if !$0.contains($1.mood) { $0.append($1.mood) } }
            ForEach(moods, id: \.self) { mood in
                Section(mood) {
                    ForEach(NamedProgression.library.filter { $0.mood == mood }) { p in
                        Button("\(p.name)   \(p.romanSummary)") { model.apply(named: p) }
                    }
                }
            }
        } label: {
            Text("Famous progressions").font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 14).frame(minHeight: 34)
                .background(Theme.card, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.stroke))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Start from a well-known progression, in your current key")
    }
}

/// How your keys map to notes: anywhere (snapped), white keys = scale, or one key = one chord.
@MainActor
struct KeyMapPicker: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Keys", selection: Binding(get: { model.session.keyMap }, set: { model.setKeyMap($0) })) {
                ForEach(KeyMap.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            Text(model.session.keyMap.explanation).font(.system(size: 12)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
