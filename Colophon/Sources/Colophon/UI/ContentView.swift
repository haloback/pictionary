import SwiftUI

struct ContentView: View {
    @Environment(EditorModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ZStack(alignment: .bottom) {
            switch model.screen {
            case .start: StartView()
            case .variations: VariationsView()
            case .editor: EditorView()
            }
            if let t = model.toast {
                Toast(text: t)
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: t) {
                        try? await Task.sleep(nanoseconds: 2_200_000_000)
                        withAnimation { self.model.toast = nil }
                    }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: model.toast)
        .tint(Theme.accent)
        .sheet(isPresented: $model.showExport) { ExportSheet().environment(model) }
        .sheet(isPresented: $model.showSeries) { SeriesSheet().environment(model) }
        .sheet(isPresented: $model.showPaperback) { PaperbackSheet().environment(model) }
    }
}
