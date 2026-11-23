import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Settings for the ComfyUI bridge plus a button that sends the selected photo through the chosen workflow.
struct ComfySheet: View {
    @Environment(EditorModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var serverURL: String = ""
    @State private var workflowPath: String = ""
    @State private var inputNodeID: String = ""
    @State private var inputFieldName: String = ""
    @State private var outputNodeID: String = ""
    @State private var connectionText: String?
    @State private var connectionOK = false
    @State private var isChecking = false

    private var bridge: ComfyBridge { .shared }

    private var selectedImageLayer: Layer? {
        guard let l = model.selectedLayer, l.imageContent != nil else { return nil }
        return l
    }

    private var workflowName: String {
        workflowPath.isEmpty ? "No workflow chosen" : (workflowPath as NSString).lastPathComponent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    serverSection
                    workflowSection
                    nodesSection
                    sendSection
                }
                .padding(16)
            }
        }
        .frame(minWidth: 560, idealWidth: 600, minHeight: 500, idealHeight: 560)
        .onAppear(perform: load)
    }

    // MARK: Pieces

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("ComfyUI").font(.headline)
                Text("Send a photo through a ComfyUI workflow you run yourself (SeedVR2 or any upscaler, restorer or other image-to-image graph) and get the result back as the layer's picture.")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
        }
        .padding(14)
    }

    private var serverSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Server").font(.system(size: 12, weight: .semibold))
            HStack(spacing: 8) {
                TextField(ComfyBridge.defaultServerURL, text: $serverURL)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: serverURL) { _, v in bridge.serverURL = v }
                    .onSubmit { testConnection() }
                Button("Test connection") { testConnection() }
                    .disabled(isChecking)
                if isChecking { ProgressView().controlSize(.small) }
            }
            if let connectionText {
                HStack(spacing: 5) {
                    Image(systemName: connectionOK ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(connectionOK ? Color.green : Color.orange)
                    Text(connectionText).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("The address ComfyUI prints when it starts, usually \(ComfyBridge.defaultServerURL). Nothing leaves this Mac unless you point it at another machine.")
                .font(.system(size: 10.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var workflowSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Workflow").font(.system(size: 12, weight: .semibold))
            HStack(spacing: 8) {
                Image(systemName: workflowPath.isEmpty ? "doc.badge.plus" : "doc.text")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(workflowName).font(.system(size: 12))
                    if !workflowPath.isEmpty {
                        Text(workflowPath).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    }
                }
                Spacer()
                Button("Choose…") { chooseWorkflow() }
                if !workflowPath.isEmpty {
                    Button("Clear") {
                        workflowPath = ""
                        bridge.workflowPath = ""
                    }
                }
            }
            .controlSize(.small)
            Text("In ComfyUI, build the graph you want (for example SeedVR2, or any upscaler or restorer), make sure it starts with a Load Image node and ends with a Save Image node, then use the workflow menu's \"Export (API)\" / \"Save (API format)\" command. That JSON is the file to choose here. Colophon uploads the photo, points the Load Image node at it, runs the graph and downloads the first image the graph saves.")
                .font(.system(size: 10.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var nodesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Node overrides (optional)").font(.system(size: 12, weight: .semibold))
            HStack(spacing: 8) {
                field("Input node id", "auto (first LoadImage)", $inputNodeID) { bridge.inputNodeID = $0 }
                field("Input field", "image", $inputFieldName) { bridge.inputFieldName = $0 }
                field("Output node id", "auto (first with images)", $outputNodeID) { bridge.outputNodeID = $0 }
            }
            Text("Leave these empty unless the workflow has several Load Image or Save Image nodes. Node ids are the numbers in the exported JSON.")
                .font(.system(size: 10.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func field(_ label: String, _ placeholder: String, _ text: Binding<String>, onChange: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 10.5)).foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .onChange(of: text.wrappedValue) { _, v in onChange(v) }
        }
    }

    private var sendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            HStack(spacing: 10) {
                Button {
                    if let l = selectedImageLayer { model.sendToComfy(l.id) }
                } label: {
                    Label("Send selected photo", systemImage: "paperplane")
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedImageLayer == nil || workflowPath.isEmpty || model.comfyStatus != nil)
                if let status = model.comfyStatus {
                    ProgressView().controlSize(.small)
                    Text(status).font(.system(size: 11)).foregroundStyle(.secondary)
                } else if let l = selectedImageLayer {
                    Text("Sends \"\(l.name)\". The result replaces its picture; Undo brings the original back.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                } else {
                    Text("Select a photo layer on the cover first.").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Actions

    private func load() {
        serverURL = bridge.serverURL
        workflowPath = bridge.workflowPath
        inputNodeID = bridge.inputNodeID
        inputFieldName = bridge.inputFieldName
        outputNodeID = bridge.outputNodeID
    }

    private func testConnection() {
        bridge.serverURL = serverURL
        isChecking = true
        connectionText = nil
        Task { @MainActor in
            let result = await bridge.check()
            isChecking = false
            switch result {
            case .success(let text):
                connectionOK = true
                connectionText = text
            case .failure(let error):
                connectionOK = false
                connectionText = "Couldn't reach \(bridge.serverURL): \(error.localizedDescription)"
            }
        }
    }

    private func chooseWorkflow() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.message = "Choose a workflow exported from ComfyUI with \"Save (API format)\""
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            _ = try ComfyBridge.loadWorkflow(at: url.path)
            workflowPath = url.path
            bridge.workflowPath = url.path
            connectionText = nil
        } catch {
            connectionOK = false
            connectionText = error.localizedDescription
        }
    }
}
