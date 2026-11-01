import SwiftUI

/// The dice in the toolbar: re-roll the cover, keeping what's locked.
struct RandomizeButton: View {
    @Environment(EditorModel.self) private var model
    @State private var open = false

    var body: some View {
        HStack(spacing: 0) {
            Button { model.smartRandomize() } label: { Label("Randomize", systemImage: "dice") }
                .keyboardShortcut("r", modifiers: [.command])
                .help("Smart-randomize the unlocked parts of the cover (⌘R)")
            Button { open.toggle() } label: { Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold)) }
                .help("Choose what to keep")
                .popover(isPresented: $open, arrowEdge: .bottom) { RandomizePanel().environment(model) }
        }
    }
}

struct RandomizePanel: View {
    @Environment(EditorModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 12) {
            Text("Smart Randomize").font(.headline)
            Text("Re-rolls everything that isn't locked, choosing layouts, type and colors that suit your genre and photo, and keeping the title legible. Locked layers (the padlock in the layer list) stay exactly as they are.")
                .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text("Keep").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
                ForEach(RandomAspect.allCases) { a in
                    Toggle(isOn: Binding(get: { model.randomLocks.contains(a) }, set: { on in
                        if on { model.randomLocks.insert(a) } else { model.randomLocks.remove(a) }
                    })) {
                        Label(a.label, systemImage: model.randomLocks.contains(a) ? "lock.fill" : a.symbol)
                    }
                    .toggleStyle(.checkbox)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Creativity").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                    Spacer()
                    Text(model.randomCreativity < 0.34 ? "Genre classics" : model.randomCreativity < 0.67 ? "Fresh takes" : "Wild").font(.system(size: 11))
                }
                Slider(value: $model.randomCreativity, in: 0...1)
            }
            HStack {
                Button("Lock All Text Layers") { model.lockTextLayers(true) }
                Button("Unlock Layers") { model.lockTextLayers(false); model.unlockAllLayers() }
                Spacer()
                Button { model.smartRandomize() } label: { Label("Randomize", systemImage: "dice") }
                    .buttonStyle(.borderedProminent)
            }
            .controlSize(.small)
        }
        .padding(16)
        .frame(width: 360)
    }
}

/// Name a saved template.
struct SaveTemplateSheet: View {
    @Environment(EditorModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var includePictures = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Save as Template").font(.headline)
            Text("Keep this design to use on other books. Their title, names and photos drop into it.")
                .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            TextField("Template name", text: $name).textFieldStyle(.roundedBorder)
            Toggle("Include this cover's pictures", isOn: $includePictures)
                .help("Off: the book you apply it to supplies the photos. On: the template keeps these pictures.")
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") {
                    model.saveAsTemplate(name: name, includePictures: includePictures)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 380)
        .onAppear { name = model.document.book.title.isEmpty ? "My Template" : model.document.book.title + " Design" }
    }
}
