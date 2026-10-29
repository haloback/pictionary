import AppKit
import SwiftUI

@main
struct ColophonApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = EditorModel()

    var body: some Scene {
        Window("Colophon", id: "main") {
            ContentView()
                .environment(model)
                .frame(minWidth: 1120, minHeight: 740)
                .onAppear { appDelegate.model = model }
        }
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands { AppCommands(model: model) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: EditorModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when launched as a bare executable (swift run) rather than an .app bundle.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        Task { @MainActor in
            if url.pathExtension.lowercased() == "colophon" {
                self.model?.load(url)
            } else {
                self.model?.importImages(urls)
            }
        }
    }
}

struct AppCommands: Commands {
    let model: EditorModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Cover") { model.newProject() }.keyboardShortcut("n")
            Button("Open…") { model.open() }.keyboardShortcut("o")
        }
        CommandGroup(replacing: .saveItem) {
            Button("Save") { model.save() }.keyboardShortcut("s")
            Button("Save As…") { model.saveAs() }.keyboardShortcut("s", modifiers: [.command, .shift])
            Divider()
            Button("Export for Stores…") { model.showExport = true }.keyboardShortcut("e")
        }
        CommandGroup(replacing: .undoRedo) {
            Button("Undo") { model.undo() }.keyboardShortcut("z")
            Button("Redo") { model.redo() }.keyboardShortcut("z", modifiers: [.command, .shift])
        }
        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Duplicate Layer") { model.duplicateSelected() }.keyboardShortcut("d")
            Button("Delete Layer") { model.deleteSelected() }.keyboardShortcut(.delete, modifiers: .command)
            Button("Bring Forward") { model.moveSelected(by: 1) }.keyboardShortcut("]")
            Button("Send Backward") { model.moveSelected(by: -1) }.keyboardShortcut("[")
            Divider()
            Button("Copy Text Style") { model.copyTextStyle() }.keyboardShortcut("c", modifiers: [.command, .option])
            Button("Paste Text Style") { model.pasteTextStyle() }.keyboardShortcut("v", modifiers: [.command, .option])
        }
        CommandMenu("Design") {
            Button("Generate Cover Ideas") { model.generateVariations() }.keyboardShortcut("g", modifiers: [.command, .shift])
            Button("More Like This Cover") { model.remixCurrent() }.keyboardShortcut("m", modifiers: [.command, .shift])
            Button("Paperback Wraparound…") { model.showPaperback = true }.keyboardShortcut("b", modifiers: [.command, .shift])
            Button("Auto-Polish Legibility") { model.autoPolish() }.keyboardShortcut("p", modifiers: [.command, .shift])
            Divider()
            Button("Add Text") { model.addText() }.keyboardShortcut("t", modifiers: [.command, .shift])
            Button("Add Photo…") { model.chooseImages() }.keyboardShortcut("i", modifiers: [.command, .shift])
            Button("Import Font…") { model.importFont() }
            Button("Pick Color from Screen") { model.pickColorFromScreen() }.keyboardShortcut("k", modifiers: [.command, .shift])
            Divider()
            Button("Make Series Covers…") { model.showSeries = true }
            Button("Lift Subject from Photo") {
                if let id = model.selectedLayer?.imageContent != nil ? model.selection : model.document.photoLayers.first?.id { model.liftSubject(id) }
            }.keyboardShortcut("l", modifiers: [.command, .shift])
        }
        CommandGroup(after: .toolbar) {
            Button(model.showGuides ? "Hide Guides" : "Show Guides") { model.showGuides.toggle() }.keyboardShortcut(";")
            Picker("Guide Style", selection: Binding(get: { model.guideStyle }, set: { model.guideStyle = $0 })) {
                ForEach(GuideStyle.allCases) { Text($0.rawValue).tag($0) }
            }
            Button(model.showThumbnailPreview ? "Hide Thumbnail Preview" : "Show Thumbnail Preview") { model.showThumbnailPreview.toggle() }
        }
    }
}
