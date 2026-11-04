import AppKit
import SwiftUI

@main
@MainActor
struct CadenceApp: App {
    @State private var model = AppModel()

    init() {
        // Running from `swift run` has no app bundle; make sure we still get a Dock icon and focus.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup("Cadence") {
            ContentView()
                .environment(model)
                .frame(minWidth: 1080, minHeight: 720)
                .onAppear { NSApp.activate(ignoringOtherApps: true) }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Session") { model.newSession() }.keyboardShortcut("n")
                Button("Open Session…") { model.openSessionPanel() }.keyboardShortcut("o")
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save Session") { model.saveSession() }.keyboardShortcut("s")
                Button("Save Session As…") { model.saveSessionAs() }.keyboardShortcut("s", modifiers: [.command, .shift])
            }
            CommandGroup(after: .saveItem) {
                Divider()
                Button("Import Chord Progression…") { model.openImportPanel() }.keyboardShortcut("i")
                Button("Learn Groove from MIDI File…") { model.openGroovePanel() }
                Button("Export Multi-Track MIDI…") { model.exportWithPanel() }.keyboardShortcut("e")
            }
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") { model.undo() }.keyboardShortcut("z").disabled(!model.canUndo)
                Button("Redo") { model.redo() }.keyboardShortcut("z", modifiers: [.command, .shift]).disabled(!model.canRedo)
            }
            CommandMenu("Play") {
                Button(model.isPlaying ? "Stop" : "Play") { model.togglePlay() }.keyboardShortcut(.return, modifiers: [.command])
                Button(model.isRecording ? "Stop Recording" : "Record") { model.toggleRecord() }.keyboardShortcut("r", modifiers: [.command])
                Divider()
                Button("Choose Style…") { model.showStyleBrowser = true }.keyboardShortcut("l")
                Button("New Progression") { model.regenerateProgression() }.keyboardShortcut("g")
                Button("Vary the Band") { model.varyBand() }.keyboardShortcut("g", modifiers: [.command, .shift])
                Button("Build a Song") { model.buildSong() }.keyboardShortcut("b")
                Toggle("Band Follows Me", isOn: Binding(get: { model.session.bandFollowsMe }, set: { model.setBandFollowsMe($0) }))
                Toggle("Click", isOn: Binding(get: { model.session.clickEnabled }, set: { model.setClick($0) }))
                    .keyboardShortcut("k")
                Divider()
                Picker("View", selection: $model.mode) {
                    ForEach(AppMode.allCases) { Text($0.rawValue).tag($0) }
                }
            }
        }
    }
}
