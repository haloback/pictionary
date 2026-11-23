import Foundation
import Observation

/// Errors raised while talking to a ComfyUI server.
enum ComfyError: LocalizedError {
    case noWorkflow
    case badWorkflow
    case noLoadImageNode
    case http(Int)
    case timeout
    case noOutput
    case server(String)

    var errorDescription: String? {
        switch self {
        case .noWorkflow: return "Choose a workflow file first (export it from ComfyUI with \"Save (API format)\")."
        case .badWorkflow: return "That workflow file isn't in ComfyUI's API format. Use \"Save (API format)\" in ComfyUI."
        case .noLoadImageNode: return "The workflow has no LoadImage node. Add one, or set the input node id and field by hand."
        case .http(let code): return "\(code): the ComfyUI server answered with an error."
        case .timeout: return "ComfyUI didn't finish within 10 minutes."
        case .noOutput: return "The workflow finished but produced no image. Make sure it ends in a Save Image or Preview Image node."
        case .server(let message): return "ComfyUI: \(message)"
        }
    }
}

/// Sends a picture to a ComfyUI server the author runs (SeedVR2, any upscaler or restorer, any workflow)
/// and brings the first output image back. Settings live in UserDefaults.
@Observable
final class ComfyBridge {
    static let shared = ComfyBridge()

    static let defaultServerURL = "http://127.0.0.1:8188"
    static let pollInterval: TimeInterval = 1
    static let maxWait: TimeInterval = 600

    enum Keys {
        static let serverURL = "comfy.serverURL"
        static let workflowPath = "comfy.workflowPath"
        static let inputNodeID = "comfy.inputNodeID"
        static let inputFieldName = "comfy.inputFieldName"
        static let outputNodeID = "comfy.outputNodeID"
    }

    private let defaults: UserDefaults

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 900
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: Settings

    var serverURL: String {
        get {
            let s = (defaults.string(forKey: Keys.serverURL) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return s.isEmpty ? ComfyBridge.defaultServerURL : s
        }
        set { store(newValue, Keys.serverURL) }
    }

    /// Path of a workflow JSON exported from ComfyUI with "Save (API format)".
    var workflowPath: String {
        get { defaults.string(forKey: Keys.workflowPath) ?? "" }
        set { store(newValue, Keys.workflowPath) }
    }

    /// The LoadImage node id; empty means auto-detect the first `class_type == "LoadImage"`.
    var inputNodeID: String {
        get { defaults.string(forKey: Keys.inputNodeID) ?? "" }
        set { store(newValue, Keys.inputNodeID) }
    }

    /// The input field that takes the uploaded file name; empty means "image".
    var inputFieldName: String {
        get { defaults.string(forKey: Keys.inputFieldName) ?? "" }
        set { store(newValue, Keys.inputFieldName) }
    }

    /// The node whose images are fetched; empty means the first output with images.
    var outputNodeID: String {
        get { defaults.string(forKey: Keys.outputNodeID) ?? "" }
        set { store(newValue, Keys.outputNodeID) }
    }

    private func store(_ value: String, _ key: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(trimmed, forKey: key)
        }
    }

    var hasWorkflow: Bool { !workflowPath.isEmpty }

    // MARK: URLs

    /// `serverURL` as a URL with no trailing slash; nil when it can't be parsed.
    static func baseURL(_ server: String) -> URL? {
        var s = server.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { s = defaultServerURL }
        if !s.contains("://") { s = "http://" + s }
        while s.hasSuffix("/") { s.removeLast() }
        return URL(string: s)
    }

    /// The `/view` address for one output image, with the file name and subfolder percent-encoded.
    static func viewURL(server: String, filename: String, subfolder: String, type: String) -> URL? {
        guard let base = baseURL(server) else { return nil }
        var comps = URLComponents(url: base.appendingPathComponent("view"), resolvingAgainstBaseURL: false)
        comps?.queryItems = [
            URLQueryItem(name: "filename", value: filename),
            URLQueryItem(name: "subfolder", value: subfolder),
            URLQueryItem(name: "type", value: type.isEmpty ? "output" : type)
        ]
        return comps?.url
    }

    private func endpoint(_ path: String) throws -> URL {
        guard let base = ComfyBridge.baseURL(serverURL) else { throw ComfyError.server("Bad server address: \(serverURL)") }
        return base.appendingPathComponent(path)
    }

    // MARK: Pure helpers (no network; used by tests)

    /// Loads the workflow JSON from `path` as a dictionary (API format: node id → {class_type, inputs}).
    static func loadWorkflow(at path: String) throws -> [String: Any] {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ComfyError.noWorkflow }
        guard let data = FileManager.default.contents(atPath: trimmed) else { throw ComfyError.noWorkflow }
        return try parseWorkflow(data)
    }

    static func parseWorkflow(_ data: Data) throws -> [String: Any] {
        guard let obj = try? JSONSerialization.jsonObject(with: data), let dict = obj as? [String: Any] else {
            throw ComfyError.badWorkflow
        }
        // The UI-format export has "nodes" and "links" arrays; API format maps ids to node dictionaries.
        if dict["nodes"] is [Any], dict["links"] is [Any] { throw ComfyError.badWorkflow }
        let hasNode = dict.values.contains { ($0 as? [String: Any])?["class_type"] != nil }
        guard hasNode else { throw ComfyError.badWorkflow }
        return dict
    }

    /// The id of the first node whose class is `LoadImage` (ids sorted numerically where possible).
    static func firstLoadImageNode(in workflow: [String: Any]) -> String? {
        let ids = workflow.keys.sorted { a, b in
            if let x = Int(a), let y = Int(b) { return x < y }
            return a < b
        }
        for id in ids {
            if let node = workflow[id] as? [String: Any], (node["class_type"] as? String) == "LoadImage" { return id }
        }
        return nil
    }

    /// Returns the workflow with `inputs[field]` of the input node set to the uploaded file name.
    /// `inputNode` and `field` may be nil or empty: the first LoadImage node and "image" are used.
    static func patch(workflow: [String: Any], inputNode: String?, field: String?, imageName: String) throws -> [String: Any] {
        let nodeID: String
        if let inputNode, !inputNode.trimmingCharacters(in: .whitespaces).isEmpty {
            nodeID = inputNode.trimmingCharacters(in: .whitespaces)
        } else if let found = firstLoadImageNode(in: workflow) {
            nodeID = found
        } else {
            throw ComfyError.noLoadImageNode
        }
        guard var node = workflow[nodeID] as? [String: Any] else { throw ComfyError.noLoadImageNode }
        let fieldName: String
        if let field, !field.trimmingCharacters(in: .whitespaces).isEmpty {
            fieldName = field.trimmingCharacters(in: .whitespaces)
        } else {
            fieldName = "image"
        }
        var inputs = node["inputs"] as? [String: Any] ?? [:]
        inputs[fieldName] = imageName
        node["inputs"] = inputs
        var out = workflow
        out[nodeID] = node
        return out
    }

    /// The first output image of a finished prompt in a `/history/<id>` answer, or nil while it's still running.
    /// `node` limits the search to one node id; nil or empty takes the first node with images.
    static func firstOutput(in history: [String: Any], promptID: String, node: String?) -> (filename: String, subfolder: String, type: String)? {
        guard let entry = history[promptID] as? [String: Any],
              let outputs = entry["outputs"] as? [String: Any] else { return nil }
        var candidates: [String]
        if let node, !node.trimmingCharacters(in: .whitespaces).isEmpty {
            candidates = [node.trimmingCharacters(in: .whitespaces)]
        } else {
            candidates = outputs.keys.sorted { a, b in
                if let x = Int(a), let y = Int(b) { return x < y }
                return a < b
            }
        }
        for id in candidates {
            guard let out = outputs[id] as? [String: Any], let images = out["images"] as? [[String: Any]] else { continue }
            for img in images {
                guard let filename = img["filename"] as? String, !filename.isEmpty else { continue }
                let subfolder = img["subfolder"] as? String ?? ""
                let type = img["type"] as? String ?? "output"
                return (filename, subfolder, type)
            }
        }
        return nil
    }

    /// Whether the history says the prompt stopped with an error (ComfyUI reports `status.status_str == "error"`).
    static func errorMessage(in history: [String: Any], promptID: String) -> String? {
        guard let entry = history[promptID] as? [String: Any],
              let status = entry["status"] as? [String: Any] else { return nil }
        guard (status["status_str"] as? String) == "error" else { return nil }
        if let messages = status["messages"] as? [[Any]] {
            for m in messages {
                guard m.count >= 2, (m[0] as? String) == "execution_error",
                      let info = m[1] as? [String: Any] else { continue }
                let node = info["node_type"] as? String ?? ""
                let msg = info["exception_message"] as? String ?? "execution error"
                return node.isEmpty ? msg : "\(node): \(msg)"
            }
        }
        return "the workflow stopped with an error"
    }

    /// Builds the multipart body for `POST /upload/image`.
    static func multipartBody(data: Data, filename: String, boundary: String) -> Data {
        var body = Data()
        func line(_ s: String) { body.append(s.data(using: .utf8)!) }
        line("--\(boundary)\r\n")
        line("Content-Disposition: form-data; name=\"image\"; filename=\"\(filename)\"\r\n")
        line("Content-Type: image/jpeg\r\n\r\n")
        body.append(data)
        line("\r\n--\(boundary)\r\n")
        line("Content-Disposition: form-data; name=\"overwrite\"\r\n\r\ntrue\r\n")
        line("--\(boundary)--\r\n")
        return body
    }

    // MARK: Network

    private static func check(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard http.statusCode < 200 || http.statusCode >= 300 else { return }
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let err = obj["error"] as? [String: Any], let msg = err["message"] as? String {
                var text = msg
                if let nodeErrors = obj["node_errors"] as? [String: Any], !nodeErrors.isEmpty {
                    text += " (nodes: \(nodeErrors.keys.sorted().joined(separator: ", ")))"
                }
                throw ComfyError.server(text)
            }
            if let msg = obj["error"] as? String { throw ComfyError.server(msg) }
        }
        throw ComfyError.http(http.statusCode)
    }

    private func json(_ data: Data) throws -> [String: Any] {
        guard let obj = try? JSONSerialization.jsonObject(with: data), let dict = obj as? [String: Any] else {
            throw ComfyError.server("unreadable answer")
        }
        return dict
    }

    /// GET `/system_stats`; on success a short description of the server.
    func check() async -> Result<String, Error> {
        do {
            let url = try endpoint("system_stats")
            var req = URLRequest(url: url)
            req.timeoutInterval = 10
            let (data, response) = try await ComfyBridge.session.data(for: req)
            try ComfyBridge.check(response, data)
            let stats = try json(data)
            var parts: [String] = []
            if let system = stats["system"] as? [String: Any] {
                if let v = system["comfyui_version"] as? String, !v.isEmpty { parts.append("ComfyUI \(v)") }
                else if let os = system["os"] as? String, !os.isEmpty { parts.append("ComfyUI on \(os)") }
                if let torch = system["pytorch_version"] as? String, !torch.isEmpty { parts.append("torch \(torch)") }
            }
            if let devices = stats["devices"] as? [[String: Any]], let first = devices.first {
                if let name = first["name"] as? String, !name.isEmpty { parts.append(name) }
                if let total = first["vram_total"] as? Double, total > 0 {
                    parts.append(String(format: "%.0f GB VRAM", total / 1_073_741_824))
                }
            }
            if parts.isEmpty { parts.append("ComfyUI is running") }
            return .success("Connected: " + parts.joined(separator: " · "))
        } catch {
            return .failure(error)
        }
    }

    /// Uploads `data`, runs the configured workflow on it and returns the first output image's bytes.
    /// `progress` receives short status lines on the way.
    func process(_ data: Data, progress: @escaping (String) -> Void) async throws -> Data {
        let workflow = try ComfyBridge.loadWorkflow(at: workflowPath)
        let server = serverURL

        // 1. Upload.
        progress("Uploading the picture…")
        let boundary = "ColophonBoundary-\(UUID().uuidString)"
        let uploadURL = try endpoint("upload/image")
        var upload = URLRequest(url: uploadURL)
        upload.httpMethod = "POST"
        upload.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        upload.httpBody = ComfyBridge.multipartBody(data: data, filename: "colophon-\(UUID().uuidString.prefix(8)).jpg", boundary: boundary)
        let (upData, upResponse) = try await ComfyBridge.session.data(for: upload)
        try ComfyBridge.check(upResponse, upData)
        let uploaded = try json(upData)
        guard let name = uploaded["name"] as? String, !name.isEmpty else { throw ComfyError.server("upload returned no file name") }
        var imageName = name
        if let sub = uploaded["subfolder"] as? String, !sub.isEmpty { imageName = sub + "/" + name }

        // 2. Queue the patched workflow.
        progress("Queuing the workflow…")
        let prompt = try ComfyBridge.patch(workflow: workflow, inputNode: inputNodeID, field: inputFieldName, imageName: imageName)
        let clientID = UUID().uuidString
        let payload: [String: Any] = ["prompt": prompt, "client_id": clientID]
        let promptURL = try endpoint("prompt")
        var queue = URLRequest(url: promptURL)
        queue.httpMethod = "POST"
        queue.setValue("application/json", forHTTPHeaderField: "Content-Type")
        queue.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (qData, qResponse) = try await ComfyBridge.session.data(for: queue)
        try ComfyBridge.check(qResponse, qData)
        let queued = try json(qData)
        guard let promptID = queued["prompt_id"] as? String, !promptID.isEmpty else {
            throw ComfyError.server("the server didn't accept the workflow")
        }

        // 3. Poll history.
        let start = Date()
        var output: (filename: String, subfolder: String, type: String)?
        var ticks = 0
        while output == nil {
            try Task.checkCancellation()
            let elapsed = Date().timeIntervalSince(start)
            if elapsed > ComfyBridge.maxWait { throw ComfyError.timeout }
            try await Task.sleep(nanoseconds: UInt64(ComfyBridge.pollInterval * 1_000_000_000))
            ticks += 1
            let historyURL = try endpoint("history/\(promptID)")
            var histReq = URLRequest(url: historyURL)
            histReq.timeoutInterval = 15
            let (hData, hResponse) = try await ComfyBridge.session.data(for: histReq)
            try ComfyBridge.check(hResponse, hData)
            let history = try json(hData)
            if let message = ComfyBridge.errorMessage(in: history, promptID: promptID) { throw ComfyError.server(message) }
            if let found = ComfyBridge.firstOutput(in: history, promptID: promptID, node: outputNodeID) {
                output = found
            } else if let entry = history[promptID] as? [String: Any],
                      let status = entry["status"] as? [String: Any],
                      (status["completed"] as? Bool) == true {
                throw ComfyError.noOutput
            } else {
                let secs = Int(elapsed.rounded())
                progress(ticks < 3 ? "Running the workflow…" : "Running the workflow… \(secs) s")
            }
        }

        // 4. Download.
        guard let output, let viewURL = ComfyBridge.viewURL(server: server, filename: output.filename, subfolder: output.subfolder, type: output.type) else {
            throw ComfyError.noOutput
        }
        progress("Downloading the result…")
        var view = URLRequest(url: viewURL)
        view.timeoutInterval = 120
        let (imgData, imgResponse) = try await ComfyBridge.session.data(for: view)
        try ComfyBridge.check(imgResponse, imgData)
        guard !imgData.isEmpty else { throw ComfyError.noOutput }
        return imgData
    }
}
