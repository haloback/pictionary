import AppKit
import SwiftUI

/// The printed book: printer, binding, trim, pages, paper, ISBN and barcode, back-cover copy and layout,
/// pre-upload checks, live preview with guides, and print-ready PDF / PNG export.
struct PaperbackSheet: View {
    @Environment(EditorModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var preview: CGImage?
    @State private var showGuides = true
    @State private var exporting = false
    @State private var exported: URL?
    @State private var checks: [String] = []

    private var settings: Binding<PrintSettings> {
        Binding(get: { model.document.paperback },
                set: { v in model.mutate(undoKey: "paperback") { d in d.paperback = v } })
    }

    var body: some View {
        let s = settings.wrappedValue
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    bookSection(s)
                    isbnSection(s)
                    backSection(s)
                    authorSection(s)
                    checksSection
                }
            }
            .frame(width: 350)
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
                    Toggle("Show guides", isOn: $showGuides).controlSize(.small)
                    HStack(spacing: 6) {
                        Rectangle().fill(Theme.accent).frame(width: 14, height: 2)
                        Text(s.binding == .hardcover ? "Board edge" : "Trim").font(.system(size: 11)).foregroundStyle(.secondary)
                        Rectangle().strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 2])).frame(width: 14, height: 8)
                        Text("Safe area").font(.system(size: 11)).foregroundStyle(.secondary)
                        if s.binding == .hardcover {
                            Rectangle().fill(Color(red: 0.5, green: 0.82, blue: 1)).frame(width: 14, height: 2)
                            Text("Hinge").font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if let exported {
                        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([exported]) }
                    }
                    Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
                    Button(exporting ? "Exporting…" : "Export PNG…") { export(pdf: false) }
                        .disabled(exporting)
                    Button(exporting ? "Exporting…" : "Export Print PDF…") { export(pdf: true) }
                        .buttonStyle(.borderedProminent)
                        .disabled(exporting)
                }
                .padding(14)
            }
        }
        .frame(width: 1220, height: 800)
        .task(id: "\(model.revision)-\(showGuides)") {
            let doc = model.document
            let guides = showGuides
            try? await Task.sleep(nanoseconds: 150_000_000)
            if Task.isCancelled { return }
            let result = await Task.detached(priority: .userInitiated) { () -> (CGImage?, [String]) in
                (PrintWrap.render(doc, dpi: 72, guides: guides), PrintWrap.printChecks(doc))
            }.value
            if !Task.isCancelled {
                preview = result.0
                checks = result.1
            }
        }
    }

    // MARK: Sections

    @ViewBuilder
    private func bookSection(_ s: PrintSettings) -> some View {
        PanelSection("Book") {
            FieldRow("Printer") {
                Picker("", selection: settings.printer) { ForEach(PrintSettings.Printer.allCases) { Text($0.label).tag($0) } }.labelsHidden()
            }
            FieldRow("Binding") {
                Picker("", selection: settings.binding) { ForEach(PrintSettings.Binding.allCases) { Text($0.label).tag($0) } }.labelsHidden()
            }
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
            let edge = s.binding == .hardcover ? String(format: "%.2f in wrap", s.wrapMargin) : "0.125 in bleed"
            Text(String(format: "Spine %.3f in. Full sheet %.3f x %.3f in with %@.", s.spineWidth, s.fullWidth, s.fullHeight, edge))
                .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            if s.binding == .hardcover {
                Label("Hardcover spine width is approximate (pages x paper + 0.125 in). Check it against \(s.printer.label)'s hardcover calculator before uploading.", systemImage: "exclamationmark.triangle")
                    .font(.system(size: 11)).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
            if !s.spineHasText {
                Label("Under 80 pages the spine is too thin for text, so it stays blank.", systemImage: "info.circle")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Toggle("Convert to CMYK on PDF export", isOn: settings.cmykExport).controlSize(.small)
        }
    }

    @ViewBuilder
    private func isbnSection(_ s: PrintSettings) -> some View {
        PanelSection("ISBN & Barcode") {
            FieldRow("ISBN") {
                TextField("978-0-306-40615-7", text: settings.isbn).textFieldStyle(.roundedBorder)
            }
            if !s.isbn.trimmingCharacters(in: .whitespaces).isEmpty {
                if let isbn = Barcode.isbn13(from: s.isbn) {
                    Label("ISBN \(Barcode.formatted(isbn, hint: s.isbn)) ✓", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(.green)
                } else {
                    Label("Not a valid ISBN", systemImage: "xmark.circle.fill")
                        .font(.system(size: 11)).foregroundStyle(.red)
                }
            } else {
                Text("Empty: the barcode box stays white for the printer to fill.").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            FieldRow("Price code") {
                TextField("51499 for $14.99, 90000 for none", text: settings.priceCode).textFieldStyle(.roundedBorder)
            }
            if !s.priceCode.isEmpty && !Barcode.isValidAddOn(s.priceCode) {
                Label("Five digits: 5 + the price in cents (51499), or 90000 for no price.", systemImage: "xmark.circle.fill")
                    .font(.system(size: 11)).foregroundStyle(.red)
            }
            FieldRow("Category") {
                TextField("FICTION / THRILLER", text: settings.category).textFieldStyle(.roundedBorder)
            }
            FieldRow("Publisher") {
                TextField("Imprint name", text: settings.publisher).textFieldStyle(.roundedBorder)
            }
            Toggle("Keep barcode area clear when there's no ISBN", isOn: settings.keepBarcodeArea).controlSize(.small)
        }
    }

    @ViewBuilder
    private func backSection(_ s: PrintSettings) -> some View {
        PanelSection("Back Cover") {
            FieldRow("Layout") {
                Picker("", selection: settings.backLayout) { ForEach(PrintSettings.BackLayout.allCases) { Text($0.label).tag($0) } }
                    .pickerStyle(.segmented).labelsHidden()
            }
            if s.backLayout != .minimal {
                Text("Pull quote or review").font(.system(size: 11)).foregroundStyle(.secondary)
                TextField("\"Luminous and unsettling.\" A reviewer", text: settings.quote, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...3)
            }
            Text("Blurb").font(.system(size: 11)).foregroundStyle(.secondary)
            TextEditor(text: settings.blurb)
                .font(.system(size: 12))
                .frame(height: 150)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
            if s.blurb.isEmpty && !model.document.book.blurb.isEmpty {
                Text("Empty: the blurb from the Book panel is used.").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if !PrintWrap.backBlurb(model.document).isEmpty && !PrintWrap.blurbFits(model.document) {
                Label("The blurb doesn't fit this layout. Trim it a little or pick another layout.", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11)).foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    private func authorSection(_ s: PrintSettings) -> some View {
        PanelSection("Author") {
            if s.backLayout == .minimal {
                Text("The minimal layout shows the blurb only; the bio and photo are left off.").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Text("Bio").font(.system(size: 11)).foregroundStyle(.secondary)
            TextField("A line or two about the author", text: settings.authorBio, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
            Text("Photo").font(.system(size: 11)).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    photoChoice(nil, selected: s.authorPhotoAssetID == nil)
                    ForEach(model.document.assetOrder, id: \.self) { id in
                        photoChoice(id, selected: s.authorPhotoAssetID == id)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func photoChoice(_ id: UUID?, selected: Bool) -> some View {
        Button {
            settings.wrappedValue.authorPhotoAssetID = id
        } label: {
            ZStack {
                if let id, let img = AssetStore.shared.image(id, data: model.document.assetData(id), resolution: .thumbnail) {
                    Image(decorative: img, scale: 1).resizable().aspectRatio(contentMode: .fill)
                } else {
                    Circle().fill(Color.primary.opacity(0.08))
                    Image(systemName: "person.crop.circle.badge.xmark").foregroundStyle(.secondary)
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(selected ? Theme.accent : Color.primary.opacity(0.15), lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .help(id == nil ? "No author photo" : "Use this photo")
    }

    private var checksSection: some View {
        PanelSection("Print Checks") {
            if checks.isEmpty {
                Label("Ready for upload.", systemImage: "checkmark.seal.fill").font(.system(size: 11)).foregroundStyle(.green)
            } else {
                ForEach(checks, id: \.self) { line in
                    Label(line, systemImage: symbol(for: line))
                        .font(.system(size: 11))
                        .foregroundStyle(isWarning(line) ? Color.orange : Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func isWarning(_ line: String) -> Bool {
        line.contains("isn't valid") || line.contains("doesn't fit") || line.contains("must be") || line.contains("ppi") || line.contains("approximation")
    }

    private func symbol(for line: String) -> String {
        isWarning(line) ? "exclamationmark.triangle.fill" : "info.circle"
    }

    // MARK: Export

    private func export(pdf: Bool) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [pdf ? .pdf : .png]
        let base = Exporter.safeFileName(model.document.book.title.isEmpty ? "Cover" : model.document.book.title)
        let kind = model.document.paperback.binding == .hardcover ? "Hardcover" : "Paperback"
        panel.nameFieldStringValue = "\(base) - \(kind).\(pdf ? "pdf" : "png")"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let doc = model.document
        exporting = true
        Task.detached(priority: .userInitiated) {
            let ok = pdf ? PrintWrap.exportPDF(doc, to: url) : PrintWrap.exportPNG(doc, to: url)
            await MainActor.run {
                exporting = false
                exported = ok ? url : nil
                model.toast = ok ? (pdf ? "Saved print-ready PDF" : "Saved 300 dpi PNG") : "Couldn't write the file"
            }
        }
    }
}
