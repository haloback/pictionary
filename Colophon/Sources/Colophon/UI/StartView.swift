import SwiftUI
import UniformTypeIdentifiers

/// The brief: what the book is, what it looks like, what to work from.
struct StartView: View {
    @Environment(EditorModel.self) private var model
    @State private var isTargeted = false

    var body: some View {
        @Bindable var model = model
        HStack(spacing: 0) {
            brief
                .frame(width: 400)
                .background(Theme.panel)
            Divider()
            sources
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Text("New Cover").font(.headline)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    ForEach(model.recentFiles, id: \.self) { url in
                        Button(url.deletingPathExtension().lastPathComponent) { model.openRecent(url) }
                    }
                    if model.recentFiles.isEmpty { Text("No recent covers") }
                } label: {
                    Label("Recent", systemImage: "clock")
                }
                .help("Open a recent cover")
                Button { model.open() } label: { Label("Open", systemImage: "folder") }
                    .help("Open a saved .colophon project")
            }
        }
    }

    // MARK: Left: the brief

    private var brief: some View {
        let book = model.bookBinding
        return VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if model.recoveryAvailable {
                        HStack(spacing: 10) {
                            Image(systemName: "clock.arrow.circlepath").foregroundStyle(Theme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Unsaved cover found").font(.system(size: 12, weight: .semibold))
                                Text("From your last session.").font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Discard") { model.discardRecovery() }.controlSize(.small)
                            Button("Restore") { model.restoreRecovery() }.controlSize(.small).buttonStyle(.borderedProminent)
                        }
                        .padding(10)
                        .background(Theme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.radius))
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tell Colophon about the book")
                            .font(.system(size: 22, weight: .semibold))
                        Text("It designs a spread of finished covers from your words and pictures. Pick one and refine it.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        labeled("Title") { TextField("The Salt Orchard", text: book.title).textFieldStyle(.roundedBorder).font(.system(size: 15)) }
                        labeled("Author") { TextField("Name as it appears on the cover", text: book.author).textFieldStyle(.roundedBorder) }
                        labeled("Subtitle") { TextField("Optional", text: book.subtitle).textFieldStyle(.roundedBorder) }
                        HStack(spacing: 10) {
                            labeled("Series") { TextField("Optional", text: book.series).textFieldStyle(.roundedBorder) }
                            labeled("Tagline") { TextField("Optional", text: book.tagline).textFieldStyle(.roundedBorder) }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Genre").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 6)], spacing: 6) {
                            ForEach(Genre.allCases) { g in
                                let on = book.wrappedValue.genre == g
                                Button { book.wrappedValue.genre = g } label: {
                                    Text(g.label)
                                        .font(.system(size: 11, weight: on ? .semibold : .regular))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.85)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 6)
                                        .background(on ? Theme.accent.opacity(0.16) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(on ? Theme.accent : Theme.hairline))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    paletteChooser

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Canvas").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                        Picker("", selection: Binding(get: { "\(model.document.canvas.width)x\(model.document.canvas.height)" }, set: { v in
                            let parts = v.split(separator: "x").compactMap { Int($0) }
                            if parts.count == 2 { model.document.canvas = CanvasSpec(width: parts[0], height: parts[1]) }
                        })) {
                            Text("1600 x 2560, Kindle 1:1.6 (recommended)").tag("1600x2560")
                            Text("1600 x 2400, 2:3 for Apple, Kobo, D2D").tag("1600x2400")
                            Text("1800 x 2700, 2:3 for Google Play").tag("1800x2700")
                        }
                        .labelsHidden()
                    }
                }
                .padding(24)
            }
            Divider()
            HStack {
                Button("Start Blank") { model.startBlank() }
                    .help("Open the editor with a simple starting layout")
                Spacer()
                Stepper("\(model.variationCount) ideas", value: Binding(get: { model.variationCount }, set: { model.variationCount = $0 }), in: 8...48, step: 8)
                    .font(.system(size: 12))
                    .fixedSize()
                Button { model.generateVariations() } label: {
                    Label("Design Covers", systemImage: "sparkles").padding(.horizontal, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(model.document.book.title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(16)
        }
    }

    private var paletteChooser: some View {
        let moods = GenreStyle.of(model.document.book.genre).moods
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Colors").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                if !model.document.palette.isEmpty {
                    Button("Use photo colors") { model.document.palette = [] }
                        .buttonStyle(.link)
                        .font(.system(size: 11))
                }
            }
            Text(model.document.palette.isEmpty ? "Taken from your photos, plus genre moods and their opposites." : "Every design will use these colors.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            HStack(spacing: 10) {
                ForEach(Array(moods.enumerated()), id: \.offset) { _, mood in
                    let selected = model.document.palette == mood
                    Button { model.document.palette = selected ? [] : mood } label: {
                        HStack(spacing: 0) {
                            ForEach(Array(mood.enumerated()), id: \.offset) { _, c in Rectangle().fill(c.color) }
                        }
                        .frame(width: 92, height: 26)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(selected ? Theme.accent : Theme.hairline, lineWidth: selected ? 2 : 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 6) {
                ForEach(Array(model.document.palette.enumerated()), id: \.offset) { i, c in
                    ColorPicker("", selection: Binding(get: { c.color }, set: { model.document.palette[i] = RGBA(color: $0) }), supportsOpacity: false)
                        .labelsHidden()
                }
                Button {
                    let base = model.document.palette.last ?? RGBA(hex: "E4572E")
                    model.document.palette.append(model.document.palette.isEmpty ? base : ColorAdvisor.opposite(base))
                } label: { Image(systemName: "plus") }
                .help("Add a color. The suggestion is the opposite of your last one.")
                if !model.document.palette.isEmpty {
                    Button { _ = model.document.palette.popLast() } label: { Image(systemName: "minus") }
                }
            }
            .controlSize(.small)
        }
    }

    private func labeled<C: View>(_ label: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            c()
        }
    }

    // MARK: Right: source pictures

    private var sources: some View {
        VStack(spacing: 0) {
            if model.document.assetOrder.isEmpty {
                emptyDrop
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 14)], spacing: 14) {
                        ForEach(model.document.assetOrder, id: \.self) { id in
                            AssetTile(id: id)
                        }
                        Button { model.chooseImages() } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "plus").font(.system(size: 22, weight: .light))
                                Text("Add more").font(.system(size: 12))
                            }
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 220)
                            .background(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4])).foregroundStyle(.tertiary))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(24)
                }
                Divider()
                HStack {
                    Image(systemName: "info.circle").foregroundStyle(.secondary)
                    Text("The first picture leads. Subjects are found automatically, so type can sit behind them.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.canvasBackdrop)
        .overlay {
            if isTargeted {
                RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.accent, lineWidth: 3).padding(10)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            model.importImages(urls)
            return true
        } isTargeted: { isTargeted = $0 }
    }

    private var emptyDrop: some View {
        VStack(spacing: 18) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 54, weight: .ultraLight))
                .foregroundStyle(.secondary)
            VStack(spacing: 6) {
                Text("Drop photos, paintings or sketches")
                    .font(.system(size: 18, weight: .medium))
                Text("Or skip pictures entirely. Colophon can build covers from color, type and geometry alone.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }
            Button("Choose Pictures…") { model.chooseImages() }
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct AssetTile: View {
    @Environment(EditorModel.self) private var model
    let id: UUID
    @State private var image: CGImage?
    @State private var hover = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image {
                    Image(decorative: image, scale: 1).resizable().scaledToFill()
                } else {
                    Rectangle().fill(Color.primary.opacity(0.06)).overlay(ProgressView().controlSize(.small))
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 220, maxHeight: 220)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Theme.hairline))

            if hover {
                Button { model.removeAsset(id) } label: {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).padding(6)
                        .background(.regularMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(8)
            }
            if model.document.assetOrder.first == id {
                Text("Lead")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Theme.accent, in: Capsule())
                    .foregroundStyle(.white)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
        .onHover { hover = $0 }
        .task(id: id) {
            let data = model.document.assetData(id)
            image = await Task.detached(priority: .userInitiated) { AssetStore.shared.image(id, data: data, resolution: .thumbnail) }.value
        }
    }
}
