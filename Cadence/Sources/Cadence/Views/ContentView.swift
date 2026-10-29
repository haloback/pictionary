import CadenceCore
import SwiftUI

@MainActor
struct ContentView: View {
    @Environment(AppModel.self) private var model
    @FocusState private var keysFocused: Bool
    @State private var dropTargeted = false

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            HeaderBar()
            Group {
                switch model.mode {
                case .stage: StageView()
                case .studio: StudioView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.canvas)
        .foregroundStyle(Theme.ink)
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 24).strokeBorder(Theme.accent, style: StrokeStyle(lineWidth: 3, dash: [10, 6]))
                    .overlay(Text("Drop a .mid file to use its chord progression").font(.title3.weight(.semibold))
                        .padding(16).background(.regularMaterial, in: Capsule()))
                    .padding(12)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottom) { MessageBanner() }
        .dropDestination(for: URL.self) { urls, _ in model.importFiles(urls) } isTargeted: { dropTargeted = $0 }
        .sheet(isPresented: $model.showStyleBrowser) { StyleBrowser() }
        .sheet(isPresented: $model.showChordEditor) { ChordTextEditor() }
        // The Mac keyboard plays too (A–' row), z/x shift octaves, space plays, r records.
        .focusable()
        .focusEffectDisabled()
        .focused($keysFocused)
        .onKeyPress(phases: [.down, .up]) { press in
            guard press.modifiers.isEmpty || press.modifiers == .shift else { return .ignored }
            return model.computerKey(press.characters, down: press.phase == .down) ? .handled : .ignored
        }
        .onAppear { keysFocused = true }
        .onChange(of: model.showStyleBrowser) { _, open in if !open { keysFocused = true } }
    }
}

@MainActor
struct MessageBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let message = model.message {
            HStack(spacing: 12) {
                Text(message).font(.system(size: 13, weight: .medium))
                Button("Dismiss") { model.message = nil }.buttonStyle(.borderless)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .padding(.bottom, 20)
            .task(id: message) {
                try? await Task.sleep(for: .seconds(5))
                if model.message == message { model.message = nil }
            }
        }
    }
}

@MainActor
struct HeaderBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        HStack(spacing: 12) {
            Text("Cadence").font(.system(size: 18, weight: .heavy)).tracking(-0.4).padding(.trailing, 6)

            Button { model.showStyleBrowser = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "globe").font(.system(size: 15, weight: .semibold))
                        .frame(width: 36, height: 36).background(Theme.ink, in: Circle()).foregroundStyle(Theme.canvas)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("STYLE · \(model.style.family)".uppercased()).font(.system(size: 10, weight: .bold)).tracking(0.8).foregroundStyle(.secondary)
                        Text(model.style.name).font(.system(size: 15, weight: .bold)).lineLimit(1)
                    }
                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary)
                }
                .padding(.leading, 6).padding(.trailing, 16).frame(height: 50)
                .background(Theme.card, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.stroke))
            }
            .buttonStyle(.plain)
            .help("Choose from \(StyleLibrary.all.count) playing styles (⌘L)")

            KeyMenu()
            TempoControl()

            Picker("Snap", selection: Binding(get: { model.session.snap }, set: { model.setSnap($0) })) {
                ForEach(SnapStrength.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            .help(model.session.snap.explanation)

            Spacer(minLength: 8)

            if !model.midiSources.isEmpty {
                Label(model.midiSources.first!, systemImage: "pianokeys")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary).lineLimit(1)
                    .help("Connected: " + model.midiSources.joined(separator: ", "))
            } else {
                Label("No MIDI keyboard: use A–' keys", systemImage: "keyboard")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary).lineLimit(1)
            }

            Picker("View", selection: $model.mode) {
                ForEach(AppMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 150)

            ExportChip()
        }
        .padding(.horizontal, 24)
        .padding(.top, 30)
        .padding(.bottom, 14)
    }
}

@MainActor
struct KeyMenu: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Menu {
            Section("Key") {
                ForEach(0..<12, id: \.self) { pc in
                    Button(NoteName.name(pc, flats: [1, 3, 5, 8, 10].contains(pc))) { model.setKey(tonic: pc) }
                }
            }
            Section("Scale") {
                ForEach(ScaleType.allCases) { s in
                    Button(s.displayName) { model.setKey(scale: s) }
                }
            }
        } label: {
            Text(model.session.key.displayName).font(.system(size: 13, weight: .bold))
                .padding(.horizontal, 14).frame(height: 36)
                .background(Theme.raised, in: Capsule())
                .foregroundStyle(Theme.accent)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Key and scale. Everything you play snaps into it.")
    }
}

@MainActor
struct TempoControl: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(model.session.autoTempo ? Theme.positive : Color.secondary).frame(width: 8, height: 8)
            Text("\(Int(model.session.tempo)) BPM").font(.system(size: 13, weight: .bold)).monospacedDigit()
            Text(model.session.autoTempo ? "following you" : "fixed").font(.system(size: 12)).foregroundStyle(.secondary)
            Stepper("Tempo", value: Binding(get: { model.session.tempo }, set: { model.setTempo($0) }), in: 40...300, step: 1)
                .labelsHidden()
        }
        .padding(.leading, 14).padding(.trailing, 6).frame(height: 36)
        .background(Theme.card, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.stroke))
        .contextMenu {
            Toggle("Follow my tempo", isOn: Binding(get: { model.session.autoTempo }, set: { model.setAutoTempo($0) }))
            Button("Reset to style tempo (\(Int(model.style.defaultTempo)))") { model.setTempo(model.style.defaultTempo) }
        }
        .onTapGesture(count: 2) { model.setAutoTempo(!model.session.autoTempo) }
        .help("Auto tempo listens to how you play. Double-click to toggle, right-click for options.")
    }
}

@MainActor
struct ExportChip: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.doc").font(.system(size: 14, weight: .semibold))
            Text("Drag MIDI out").font(.system(size: 13, weight: .semibold))
        }
        .padding(.horizontal, 16).frame(height: 44)
        .foregroundStyle(Theme.canvas)
        .background(Theme.ink, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onDrag { model.dragProvider() }
        .onTapGesture { model.exportWithPanel() }
        .help("Drag onto Logic, GarageBand, Ableton or Finder: one MIDI track per layer. Click to save instead.")
    }
}
