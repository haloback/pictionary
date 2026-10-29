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
            }
            CommandGroup(after: .newItem) {
                Button("Import Chord Progression…") { model.openImportPanel() }.keyboardShortcut("o")
                Button("Export Multi-Track MIDI…") { model.exportWithPanel() }.keyboardShortcut("e")
            }
            CommandMenu("Play") {
                Button(model.isPlaying ? "Stop" : "Play") { model.togglePlay() }.keyboardShortcut(.return, modifiers: [.command])
                Button(model.isRecording ? "Stop Recording" : "Record") { model.toggleRecord() }.keyboardShortcut("r", modifiers: [.command])
                Divider()
                Button("Choose Style…") { model.showStyleBrowser = true }.keyboardShortcut("l")
                Button("New Progression") { model.regenerateProgression() }.keyboardShortcut("g")
                Button("Vary the Band") { model.varyBand() }.keyboardShortcut("g", modifiers: [.command, .shift])
                Divider()
                Picker("View", selection: $model.mode) {
                    ForEach(AppMode.allCases) { Text($0.rawValue).tag($0) }
                }
            }
        }
    }
}
