import SwiftUI

/// Search Unsplash or Pexels with your own free API key and drop a photo onto the cover.
struct StockPhotoBrowserSheet: View {
    @Environment(EditorModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var provider: StockPhotoService.Provider = .unsplash
    @State private var apiKey: String = ""
    @State private var query: String = ""
    @State private var results: [StockPhoto] = []
    @State private var page: Int = 1
    @State private var isSearching = false
    @State private var isImporting: String?
    @State private var errorText: String?
    @State private var searchTask: Task<Void, Never>?

    private var service: StockPhotoService { .shared }

    private let columns: [GridItem] = [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 10)]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            keyRow
            Divider()
            content
        }
        .frame(minWidth: 760, idealWidth: 860, minHeight: 540, idealHeight: 640)
        .onAppear { apiKey = service.apiKey(for: provider) }
        .onChange(of: provider) { _, p in
            apiKey = service.apiKey(for: p)
            results = []
            errorText = nil
            if !query.isEmpty { runSearch(reset: true) }
        }
        .onDisappear { searchTask?.cancel() }
    }

    // MARK: Pieces

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Stock Photos").font(.headline)
                Text("Free photos from Unsplash and Pexels, searched with your own key. Credits are written to Credits.txt on export.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Picker("", selection: $provider) {
                ForEach(StockPhotoService.Provider.allCases) { p in Text(p.label).tag(p) }
            }
            .pickerStyle(.segmented).labelsHidden().frame(width: 180)
            Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
        }
        .padding(14)
    }

    private var keyRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("\(provider.label) API key").font(.system(size: 12)).frame(width: 120, alignment: .leading)
                SecureField("Paste your key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: apiKey) { _, k in service.setAPIKey(k, for: provider) }
                TextField("Search forest, lighthouse, city at night…", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)
                    .onSubmit { runSearch(reset: true) }
                Button("Search") { runSearch(reset: true) }
                    .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || isSearching)
                Button("Search for my book") {
                    query = StockPhotoService.suggestedQuery(for: model.document.book)
                    runSearch(reset: true)
                }
                .help("Builds a search from the title, tagline and genre")
            }
            Text("Get a free key at \(StockPhotoService.Provider.unsplash.keySite) or \(StockPhotoService.Provider.pexels.keySite). Keys stay on this Mac.")
                .font(.system(size: 10.5)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    @ViewBuilder private var content: some View {
        if let errorText {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle").font(.system(size: 28)).foregroundStyle(.secondary)
                Text(errorText).font(.system(size: 12)).multilineTextAlignment(.center).frame(maxWidth: 420)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if results.isEmpty {
            VStack(spacing: 8) {
                if isSearching {
                    ProgressView()
                } else {
                    Image(systemName: "photo.on.rectangle.angled").font(.system(size: 28)).foregroundStyle(.secondary)
                    Text(service.hasKey(for: provider)
                         ? "Type what the cover needs and press Return."
                         : "Paste a \(provider.label) key above to start searching.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(results) { photo in cell(photo) }
                }
                .padding(14)
                HStack {
                    if isSearching { ProgressView().controlSize(.small) }
                    Button("More results") { runSearch(reset: false) }.disabled(isSearching)
                }
                .padding(.bottom, 14)
            }
        }
    }

    private func cell(_ photo: StockPhoto) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            AsyncImage(url: photo.thumbURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    Image(systemName: "photo").foregroundStyle(.secondary)
                default:
                    ProgressView().controlSize(.small)
                }
            }
            .frame(height: 210)
            .frame(maxWidth: .infinity)
            .clipped()
            .background(Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            HStack(spacing: 6) {
                Text(photo.photographer.isEmpty ? photo.provider.label : photo.photographer)
                    .font(.system(size: 10.5)).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                if isImporting == photo.id {
                    ProgressView().controlSize(.mini)
                } else {
                    Button("Use") { use(photo) }.controlSize(.small).disabled(isImporting != nil)
                }
            }
        }
        .help("\(photo.attribution) — \(photo.width) x \(photo.height)")
    }

    // MARK: Actions

    private func runSearch(reset: Bool) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        searchTask?.cancel()
        if reset {
            page = 1
            results = []
        } else {
            page += 1
        }
        errorText = nil
        isSearching = true
        let provider = provider
        let page = page
        searchTask = Task { @MainActor in
            do {
                let found = try await service.search(q, provider: provider, page: page)
                guard !Task.isCancelled else { return }
                if reset { results = found } else { results.append(contentsOf: found) }
                if results.isEmpty { errorText = "Nothing found for “\(q)”. Try a broader word." }
            } catch {
                guard !Task.isCancelled else { return }
                errorText = error.localizedDescription
            }
            isSearching = false
        }
    }

    private func use(_ photo: StockPhoto) {
        isImporting = photo.id
        Task { @MainActor in
            do {
                try await model.importStockPhoto(photo)
                isImporting = nil
                dismiss()
            } catch {
                isImporting = nil
                errorText = error.localizedDescription
            }
        }
    }
}
