import SwiftUI

/// A wall of finished cover ideas. Pick one to refine, or ask for more like it.
struct VariationsView: View {
    @Environment(EditorModel.self) private var model
    @State private var columns: CGFloat = 200

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: columns, maximum: columns * 1.4), spacing: 22)], spacing: 28) {
                ForEach(model.variations.filter { !model.showFavoritesOnly || $0.favorite }) { v in
                    VariationCard(variation: v)
                }
                if model.isGenerating && model.variations.isEmpty {
                    ForEach(0..<8, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary.opacity(0.06))
                            .aspectRatio(1 / model.document.canvas.aspect, contentMode: .fit)
                    }
                }
            }
            .padding(28)
        }
        .background(Theme.canvasBackdrop)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { model.screen = model.document.layers.isEmpty ? .start : .editor } label: {
                    Label(model.document.layers.isEmpty ? "Brief" : "Editor", systemImage: "chevron.left")
                }
                .help(model.document.layers.isEmpty ? "Back to the brief" : "Back to the cover you were editing")
            }
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(model.document.book.title.isEmpty ? "Cover Ideas" : model.document.book.title).font(.headline)
                    Text(model.isGenerating ? "Designing…" : (model.isRemix ? "\(model.variations.count) takes on your cover" : "\(model.variations.count) ideas, \(model.document.book.genre.label)"))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Slider(value: $columns, in: 150...320).frame(width: 110).help("Thumbnail size")
                Toggle(isOn: Binding(get: { model.showFavoritesOnly }, set: { model.showFavoritesOnly = $0 })) {
                    Label("Favorites", systemImage: model.showFavoritesOnly ? "heart.fill" : "heart")
                }
                .help("Show only the covers you've hearted")
                .disabled(!model.variations.contains { $0.favorite })
                Button { model.screen = .start } label: { Label("Edit Brief", systemImage: "square.and.pencil") }
                Button { model.generateVariations() } label: { Label("New Batch", systemImage: "arrow.triangle.2.circlepath") }
                    .disabled(model.isGenerating)
                    .help("Design a fresh batch with new seeds")
            }
        }
    }
}

private struct VariationCard: View {
    @Environment(EditorModel.self) private var model
    let variation: Variation
    @State private var hover = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if let t = variation.thumbnail {
                    Image(decorative: t, scale: 1)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Rectangle().fill(Color.primary.opacity(0.06))
                        .aspectRatio(1 / variation.document.canvas.aspect, contentMode: .fit)
                        .overlay(ProgressView().controlSize(.small))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(alignment: .topTrailing) {
                if hover || variation.favorite {
                    Button { model.toggleFavorite(variation.id) } label: {
                        Image(systemName: variation.favorite ? "heart.fill" : "heart")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(variation.favorite ? Theme.accent : Color.white)
                            .padding(7)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .accessibilityLabel(variation.favorite ? "Remove from favorites" : "Add to favorites")
                }
            }
            .shadow(color: .black.opacity(hover ? 0.45 : 0.28), radius: hover ? 18 : 8, y: hover ? 10 : 4)
            .scaleEffect(hover ? 1.02 : 1)
            .overlay(alignment: .bottom) {
                if hover {
                    HStack(spacing: 6) {
                        Button { model.adopt(variation) } label: { Text("Edit This").frame(maxWidth: .infinity) }
                            .buttonStyle(.borderedProminent)
                        Menu {
                            Button("More with this layout") { model.generateVariations(only: Archetype.allCases.first { $0.label == variation.document.archetypeName }) }
                            Button("More like this one") {
                                model.adopt(variation)
                                model.remixCurrent()
                            }
                        } label: { Image(systemName: "ellipsis") }
                            .menuStyle(.borderlessButton)
                            .fixedSize()
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .controlSize(.regular)
                    .padding(10)
                    .transition(.opacity)
                }
            }
            HStack(spacing: 6) {
                Text(variation.document.archetypeName).font(.system(size: 11, weight: .medium))
                Spacer(minLength: 4)
                HStack(spacing: 2) {
                    ForEach(Array(variation.document.palette.prefix(5).enumerated()), id: \.offset) { _, c in
                        Circle().fill(c.color).frame(width: 8, height: 8)
                    }
                }
            }
            .foregroundStyle(.secondary)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hover)
        .onHover { hover = $0 }
        .onTapGesture(count: 2) { model.adopt(variation) }
        .contentShape(Rectangle())
    }
}
