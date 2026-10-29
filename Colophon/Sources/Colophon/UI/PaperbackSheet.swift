import AppKit
import SwiftUI

/// Print paperback wraparound: trim, page count, back copy, live preview and PDF export.
struct PaperbackSheet: View {
    @Environment(EditorModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var preview: CGImage?
    @State private var showGuides = true
    @State private var exporting = false
    @State private var exported: URL?

    private var settings: Binding<PrintSettings> {
        Binding(get: { model.document.paperback },
                set: { v in model.mutate(undoKey: "paperback") { d in d.paperback = v } })
    }

    var body: some View {
        let s = settings.wrappedValue
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    PanelSection("Book") {
                        FieldRow("Trim size") {
                            Picker("", selection: Binding(get: { "\(s.trimWidth)x\(s.trimHeight)" }, set: { v in
                                if let t = PrintSettings.trims.first(where: { "\($0.1)x\($0.2)" == v }) {
                                    settings.wrappedValue.trimWidth = t.1
                                    settings.wrappedValue.trimHeight = t.2
                                }
                            })) {
                                ForEach(PrintSettings.trims.indices, id: \.self) { i in
                                    let t = PrintSettings.trims[i]
                                    Text(t.0).tag("\(t.1)x\(t.2)")
                                }
                            }
                            .labelsHidden()
                        }
                        FieldRow("Pages") {
                            HStack {
                                TextField("", value: settings.pageCount, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 70)
                                Stepper("", value: settings.pageCount, in: 24...828, step: 2).labelsHidden()
                            }
                        }
                        FieldRow("Paper") {
                            Picker("", selection: settings.paper) { ForEach(PaperType.allCases) { Text($0.label).tag($0) } }.labelsHidden()
                        }
                        Text(String(format: "Spine %.3f in. Full sheet %.3f x %.3f in with 0.125 in bleed.", s.spineWidth, s.fullWidth, s.fullHeight))
                            .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                        if !s.spineHasText {
                            Label("Under 80 pages the spine is too thin for text, so it stays blank.", systemImage: "info.circle")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                    PanelSection("Back Cover") {
                        Text("Pull quote or review").font(.system(size: 11)).foregroundStyle(.secondary)
                        TextField("\"Luminous and unsettling.\" A reviewer", text: settings.quote, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...3)
                        Text("Blurb").font(.system(size: 11)).foregroundStyle(.secondary)
                        TextEditor(text: settings.blurb)
                            .font(.system(size: 12))
                            .frame(height: 170)
                            .scrollContentBackground(.hidden)
                            .padding(6)
                            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                        if !s.blurb.isEmpty && !PrintWrap.blurbFits(model.document) {
                            Label("The blurb runs past the barcode area. Trim it a little.", systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 11)).foregroundStyle(.orange)
                        }
                        Toggle("Keep barcode area clear (2 x 1.2 in)", isOn: settings.keepBarcodeArea).controlSize(.small)
                    }
                    PanelSection("Notes") {
                        Text("Spine width uses KDP's per-page paper thickness. IngramSpark's differs slightly, so check its cover template calculator before uploading there.")
                            .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(width: 330)
            .background(Theme.panel)
            Divider()
            VStack(spacing: 0) {
                ZStack {
                    Theme.canvasBackdrop
                    if let preview {
                        Image(decorative: preview, scale: 1)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .shadow(color: .black.opacity(0.4), radius: 14, y: 6)
                            .padding(28)
                    } else {
                        ProgressView()
                    }
                }
                HStack(spacing: 14) {
                    Toggle("Show trim, spine and safe guides", isOn: $showGuides).controlSize(.small)
                    HStack(spacing: 6) {
                        Rectangle().fill(Theme.accent).frame(width: 14, height: 2)
                        Text("Trim").font(.system(size: 11)).foregroundStyle(.secondary)
                        Rectangle().strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 2])).frame(width: 14, height: 8)
                        Text("Safe area").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let exported {
                        Button("Show PDF in Finder") { NSWorkspace.shared.activateFileViewerSelecting([exported]) }
                    }
                    Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
                    Button(exporting ? "Exporting…" : "Export Print PDF…") { exportPDF() }
                        .buttonStyle(.borderedProminent)
                        .disabled(exporting)
                }
                .padding(14)
            }
        }
        .frame(width: 1180, height: 760)
        .task(id: "\(model.revision)-\(showGuides)") {
            let doc = model.document
            let guides = showGuides
            try? await Task.sleep(nanoseconds: 150_000_000)
            if Task.isCancelled { return }
            let img = await Task.detached(priority: .userInitiated) { PrintWrap.render(doc, dpi: 72, guides: guides) }.value
            if !Task.isCancelled { preview = img }
        }
    }

    private func exportPDF() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = Exporter.safeFileName(model.document.book.title.isEmpty ? "Cover" : model.document.book.title) + " - Paperback.pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let doc = model.document
        exporting = true
        Task.detached(priority: .userInitiated) {
            let ok = PrintWrap.exportPDF(doc, to: url)
            await MainActor.run {
                exporting = false
                exported = ok ? url : nil
                model.toast = ok ? "Saved print-ready PDF" : "Couldn't write the PDF"
            }
        }
    }
}
