import SwiftUI

/// The cover on a shelf of its genre's Signature designs at search-result size, with a standout score
/// and short notes on what helps and what hurts.
struct ShelfTestSheet: View {
    @Environment(EditorModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var result: ShelfTest.Result?
    @State private var seed = 1
    @State private var running = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Text("Shelf Test").font(.system(size: 16, weight: .semibold))
                Text("Your cover among \(model.document.book.genre.label.lowercased()) books, as a shopper sees it")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Button("Re-roll shelf") { seed += 1 }.disabled(running)
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            Divider()
            HStack(alignment: .top, spacing: 0) {
                ZStack {
                    Color(white: 0.97)
                    if let r = result {
                        Image(decorative: r.grid, scale: 1, orientation: .up)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .padding(16)
                    } else {
                        ProgressView("Building the shelf…")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Standout").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                    if let r = result {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(Int(r.standout.rounded()))")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(r.standout >= 70 ? Color.green : r.standout >= 45 ? Color.orange : Color.red)
                            Text("of 100").font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        Text("Color against the neighbors, a title that still reads at \(Int(ShelfTest.defaultCell.width)) px, type that keeps its contrast, and a picture that is neither flat nor noisy.")
                            .font(.system(size: 10.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        Divider()
                        ForEach(Array(r.notes.enumerated()), id: \.offset) { _, note in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "text.bubble").font(.system(size: 10)).foregroundStyle(.secondary).padding(.top, 2)
                                Text(note).font(.system(size: 11.5)).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer()
                        Text("On the shelf: " + r.neighbors.joined(separator: ", "))
                            .font(.system(size: 10)).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(running ? "Measuring…" : "").font(.system(size: 11)).foregroundStyle(.secondary)
                        Spacer()
                    }
                }
                .padding(16)
                .frame(width: 260, alignment: .topLeading)
            }
        }
        .frame(minWidth: 820, idealWidth: 900, minHeight: 600, idealHeight: 680)
        .task(id: seed) { await run() }
    }

    private func run() async {
        let doc = model.document
        let s = seed
        running = true
        let r = await Task.detached(priority: .userInitiated) { ShelfTest.run(doc, seed: s) }.value
        if Task.isCancelled { return }
        result = r
        running = false
    }
}
