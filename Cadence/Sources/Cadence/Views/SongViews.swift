import CadenceCore
import SwiftUI

/// The song's sections in order. Click one to edit its chords; right-click for
/// length, energy and arrangement options.
@MainActor
struct SectionsBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 8) {
            if model.session.sections.isEmpty {
                Text("Looping \(model.session.songBars) bars")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
                Button { model.buildSong() } label: { Label("Build a song", systemImage: "rectangle.stack") }
                    .buttonStyle(PillButtonStyle(selected: true, tint: Theme.accent))
                    .help("Intro, verses, choruses, a bridge and an outro, with their own chords and energy")
            } else {
                TimelineView(.periodic(from: .now, by: 0.2)) { _ in
                    let playing = model.isPlaying ? model.playhead().section : nil
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(model.session.sections.enumerated()), id: \.element.id) { i, s in
                                SectionChip(section: s, index: i, isPlaying: playing == i)
                            }
                        }
                    }
                }
                Button { model.editingSectionID = nil } label: { Text("Main chords") }
                    .buttonStyle(PillButtonStyle(selected: model.editingSectionID == nil, tint: Theme.ink))
                    .help("Edit the chords every section without its own chords plays")
            }
            AddSectionMenu()
            if !model.session.sections.isEmpty {
                Menu {
                    Button("Rebuild a full song") { model.buildSong() }
                    Button("Back to a simple loop", role: .destructive) { model.clearSections() }
                } label: { Image(systemName: "ellipsis.circle").font(.system(size: 16)) }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    .accessibilityLabel("Song options")
            }
            Spacer(minLength: 0)
        }
    }
}

@MainActor
struct SectionChip: View {
    @Environment(AppModel.self) private var model
    let section: SongSection
    let index: Int
    let isPlaying: Bool

    var body: some View {
        let editing = model.editingSectionID == section.id
        Button { model.editingSectionID = editing ? nil : section.id } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(section.name).font(.system(size: 12, weight: .bold)).lineLimit(1)
                    if section.chordsKey != nil {
                        Image(systemName: "music.note").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.accent)
                    }
                }
                HStack(spacing: 6) {
                    Text("\(section.bars) bars").font(.system(size: 10)).foregroundStyle(.secondary).monospacedDigit()
                    // Energy meter.
                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Double(i) < section.intensity * 5 - 0.01 ? Theme.accent : Color.primary.opacity(0.12))
                                .frame(width: 4, height: CGFloat(4 + i * 2))
                        }
                    }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .frame(minWidth: 92, alignment: .leading)
            .background(editing ? Theme.raised : Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isPlaying ? Theme.record : (editing ? Theme.accent : Theme.stroke), lineWidth: isPlaying || editing ? 2 : 1))
        }
        .buttonStyle(.plain)
        .help("\(section.name): click to edit its chords\(section.chordsKey == nil ? " (plays the main chords)" : ""). Right-click for more.")
        .contextMenu {
            Section("Length") {
                ForEach([2, 4, 8, 12, 16], id: \.self) { b in
                    Button("\(b) bars") { model.updateSection(section.id) { $0.bars = b } }
                }
            }
            Section("Energy") {
                ForEach([("Whisper", 0.2), ("Low", 0.4), ("Medium", 0.6), ("High", 0.8), ("Full", 1.0)], id: \.0) { name, v in
                    Button(name) { model.updateSection(section.id) { $0.intensity = v } }
                }
            }
            Divider()
            if section.chordsKey == nil {
                Button("Give this section its own chords") { model.giveOwnChords(section.id) }
            } else {
                Button("Play the main chords instead") { model.useMainChords(section.id) }
            }
            Button("Duplicate") { model.duplicateSection(section.id) }
            Button("Move earlier") { model.moveSection(section.id, by: -1) }.disabled(index == 0)
            Button("Move later") { model.moveSection(section.id, by: 1) }.disabled(index == model.session.sections.count - 1)
            Divider()
            Button("Delete section", role: .destructive) { model.removeSection(section.id) }
        }
    }
}

@MainActor
struct AddSectionMenu: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Menu {
            ForEach(SectionKind.allCases, id: \.self) { k in
                Button("\(k.displayName) · \(k.defaultBars) bars") { model.addSection(k) }
            }
        } label: {
            Text("+ Section").font(.system(size: 13, weight: .bold)).padding(.horizontal, 14).frame(height: 34)
                .overlay(Capsule().strokeBorder(Color.secondary.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

/// Count-in, click, how tight takes are, the band following you, and grooves.
@MainActor
struct RecordOptionsButton: View {
    @Environment(AppModel.self) private var model
    @State private var open = false

    var body: some View {
        Button { open.toggle() } label: {
            Image(systemName: "slider.horizontal.3").font(.system(size: 15, weight: .semibold))
                .frame(width: 44, height: 44).background(Theme.raised, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Recording and feel options")
        .help("Count-in, click, timing and feel")
        .popover(isPresented: $open, arrowEdge: .top) { RecordOptions().frame(width: 320).padding(18) }
    }
}

@MainActor
struct RecordOptions: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let s = model.session
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("Recording")
                Picker("Count-in", selection: Binding(get: { s.countInBars }, set: { model.setCountIn($0) })) {
                    Text("Off").tag(0)
                    Text("1 bar").tag(1)
                    Text("2 bars").tag(2)
                }
                .pickerStyle(.segmented)
                Toggle("Click while playing", isOn: Binding(get: { s.clickEnabled }, set: { model.setClick($0) }))
                LabeledSlider(label: "New takes: as played → on the grid", value: s.takeQuantize, range: 0...1) { model.setTakeQuantize($0) }
                GridPicker(grid: s.quantizeGrid) { model.setQuantizeGrid($0) }
                Text("Takes keep exactly what you played; you can change their timing later in Studio.")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("Band")
                Toggle("Band follows me", isOn: Binding(get: { s.bandFollowsMe }, set: { model.setBandFollowsMe($0) }))
                Text("Plays louder when you dig in, leaves space when you're busy, and answers with a fill when you pause.")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("Groove")
                if let g = s.groove {
                    HStack {
                        Text(g.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        Spacer()
                        Button("Remove") { model.clearGroove() }.buttonStyle(.borderless)
                    }
                    LabeledSlider(label: "Groove amount", value: g.amount, range: 0...1) { model.setGrooveAmount($0) }
                } else {
                    Text("Using the style's own feel.").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Button("Learn a groove from a MIDI file…") { model.openGroovePanel() }
                Text("Drop a drum loop on the window, or use one of your takes from Studio.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }
}

@MainActor
struct GridPicker: View {
    let grid: Int
    let set: (Int) -> Void

    var body: some View {
        Picker("Grid", selection: Binding(get: { grid }, set: set)) {
            Text("8ths").tag(2)
            Text("Triplets").tag(3)
            Text("16ths").tag(4)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

/// Section names above the Studio ruler.
@MainActor
struct SectionRuler: View {
    @Environment(AppModel.self) private var model
    let barWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: Timeline.headerWidth)
            ForEach(model.session.sections) { s in
                let editing = model.editingSectionID == s.id
                Text(s.name).font(.system(size: 11, weight: .bold)).lineLimit(1)
                    .padding(.horizontal, 6)
                    .frame(width: CGFloat(s.bars) * barWidth - 2, height: 22, alignment: .leading)
                    .background(Theme.accent.opacity(0.08 + s.intensity * 0.22), in: RoundedRectangle(cornerRadius: 5))
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(editing ? Theme.accent : Color.clear, lineWidth: 1.5))
                    .padding(.trailing, 2)
                    .onTapGesture { model.editingSectionID = editing ? nil : s.id }
            }
        }
        .padding(.vertical, 4)
        .background(Theme.canvas)
    }
}
