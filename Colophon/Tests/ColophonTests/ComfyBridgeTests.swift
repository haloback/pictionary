import Foundation
import XCTest
@testable import Colophon

final class ComfyBridgeTests: XCTestCase {
    private static let workflowJSON = """
    {
      "3": { "class_type": "SeedVR2Upscaler", "inputs": { "image": ["10", 0], "scale": 2 } },
      "10": { "class_type": "LoadImage", "inputs": { "image": "example.png", "upload": "image" } },
      "12": { "class_type": "SaveImage", "inputs": { "images": ["3", 0], "filename_prefix": "ComfyUI" } }
    }
    """

    private static let finishedHistoryJSON = """
    {
      "abc-123": {
        "prompt": [0, "abc-123", {}, {}, []],
        "outputs": {
          "12": { "images": [ { "filename": "ComfyUI_00001_.png", "subfolder": "", "type": "output" } ] }
        },
        "status": { "status_str": "success", "completed": true, "messages": [] }
      }
    }
    """

    private func workflow() throws -> [String: Any] {
        try ComfyBridge.parseWorkflow(Self.workflowJSON.data(using: .utf8)!)
    }

    private func history(_ json: String) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: json.data(using: .utf8)!) as? [String: Any])
    }

    func testPatchSetsExplicitNodeAndField() throws {
        let patched = try ComfyBridge.patch(workflow: try workflow(), inputNode: "10", field: "image", imageName: "colophon-1.jpg")
        let node = try XCTUnwrap(patched["10"] as? [String: Any])
        let inputs = try XCTUnwrap(node["inputs"] as? [String: Any])
        XCTAssertEqual(inputs["image"] as? String, "colophon-1.jpg")
        XCTAssertEqual(inputs["upload"] as? String, "image", "other inputs are kept")
        XCTAssertNotNil(patched["3"])
        XCTAssertNotNil(patched["12"])
    }

    func testPatchAutoDetectsLoadImageNode() throws {
        let patched = try ComfyBridge.patch(workflow: try workflow(), inputNode: nil, field: nil, imageName: "up.jpg")
        let node = try XCTUnwrap(patched["10"] as? [String: Any])
        let inputs = try XCTUnwrap(node["inputs"] as? [String: Any])
        XCTAssertEqual(inputs["image"] as? String, "up.jpg")
        // Empty strings mean "auto" too.
        let patched2 = try ComfyBridge.patch(workflow: try workflow(), inputNode: "", field: "", imageName: "up2.jpg")
        let inputs2 = try XCTUnwrap((patched2["10"] as? [String: Any])?["inputs"] as? [String: Any])
        XCTAssertEqual(inputs2["image"] as? String, "up2.jpg")
        XCTAssertEqual(ComfyBridge.firstLoadImageNode(in: try workflow()), "10")
    }

    func testPatchThrowsWithoutLoadImageNode() throws {
        var wf = try workflow()
        wf["10"] = nil
        XCTAssertThrowsError(try ComfyBridge.patch(workflow: wf, inputNode: nil, field: nil, imageName: "x.jpg")) { error in
            guard case ComfyError.noLoadImageNode = error else { return XCTFail("wrong error: \(error)") }
        }
        // An explicit id that doesn't exist is the same failure.
        XCTAssertThrowsError(try ComfyBridge.patch(workflow: wf, inputNode: "99", field: nil, imageName: "x.jpg")) { error in
            guard case ComfyError.noLoadImageNode = error else { return XCTFail("wrong error: \(error)") }
        }
    }

    func testParseRejectsUIFormatAndGarbage() {
        let ui = """
        { "nodes": [ { "id": 1, "type": "LoadImage" } ], "links": [], "version": 0.4 }
        """
        XCTAssertThrowsError(try ComfyBridge.parseWorkflow(ui.data(using: .utf8)!)) { error in
            guard case ComfyError.badWorkflow = error else { return XCTFail("wrong error: \(error)") }
        }
        XCTAssertThrowsError(try ComfyBridge.parseWorkflow("not json".data(using: .utf8)!))
        XCTAssertThrowsError(try ComfyBridge.loadWorkflow(at: "")) { error in
            guard case ComfyError.noWorkflow = error else { return XCTFail("wrong error: \(error)") }
        }
    }

    func testFirstOutputFindsImageInFinishedHistory() throws {
        let h = try history(Self.finishedHistoryJSON)
        let out = try XCTUnwrap(ComfyBridge.firstOutput(in: h, promptID: "abc-123", node: nil))
        XCTAssertEqual(out.filename, "ComfyUI_00001_.png")
        XCTAssertEqual(out.subfolder, "")
        XCTAssertEqual(out.type, "output")
        let explicit = try XCTUnwrap(ComfyBridge.firstOutput(in: h, promptID: "abc-123", node: "12"))
        XCTAssertEqual(explicit.filename, "ComfyUI_00001_.png")
        XCTAssertNil(ComfyBridge.firstOutput(in: h, promptID: "abc-123", node: "3"), "a node without images yields nothing")
        XCTAssertNil(ComfyBridge.firstOutput(in: h, promptID: "other", node: nil))
        XCTAssertNil(ComfyBridge.errorMessage(in: h, promptID: "abc-123"))
    }

    func testFirstOutputIsNilWhileRunning() throws {
        let h = try history("{}")
        XCTAssertNil(ComfyBridge.firstOutput(in: h, promptID: "abc-123", node: nil))
        let running = try history("""
        { "abc-123": { "outputs": {}, "status": { "status_str": "running", "completed": false, "messages": [] } } }
        """)
        XCTAssertNil(ComfyBridge.firstOutput(in: running, promptID: "abc-123", node: nil))
    }

    func testErrorMessageFromHistory() throws {
        let failed = try history("""
        { "abc-123": { "outputs": {}, "status": { "status_str": "error", "completed": false,
          "messages": [ ["execution_start", {}], ["execution_error", { "node_type": "SeedVR2Upscaler", "exception_message": "CUDA out of memory" }] ] } } }
        """)
        XCTAssertEqual(ComfyBridge.errorMessage(in: failed, promptID: "abc-123"), "SeedVR2Upscaler: CUDA out of memory")
    }

    func testViewURLEncodesFilename() throws {
        let url = try XCTUnwrap(ComfyBridge.viewURL(server: "http://127.0.0.1:8188/", filename: "my photo & more.png", subfolder: "sub dir", type: "output"))
        let s = url.absoluteString
        XCTAssertTrue(s.hasPrefix("http://127.0.0.1:8188/view?"), s)
        XCTAssertTrue(s.contains("filename=my%20photo%20%26%20more.png"), s)
        XCTAssertTrue(s.contains("subfolder=sub%20dir"), s)
        XCTAssertTrue(s.contains("type=output"), s)
        XCTAssertFalse(s.contains("8188//view"), "trailing slash on the server is stripped")
        // A bare host:port gets a scheme.
        let bare = try XCTUnwrap(ComfyBridge.baseURL("localhost:8188"))
        XCTAssertEqual(bare.absoluteString, "http://localhost:8188")
        XCTAssertEqual(ComfyBridge.baseURL("")?.absoluteString, ComfyBridge.defaultServerURL)
    }

    func testMultipartBodyContainsFileAndOverwrite() {
        let body = ComfyBridge.multipartBody(data: Data([1, 2, 3]), filename: "a.jpg", boundary: "B")
        let text = String(decoding: body, as: UTF8.self)
        XCTAssertTrue(text.contains("name=\"image\"; filename=\"a.jpg\""))
        XCTAssertTrue(text.contains("name=\"overwrite\"\r\n\r\ntrue"))
        XCTAssertTrue(text.hasSuffix("--B--\r\n"))
    }

    func testSettingsRoundTrip() {
        let suite = "colophon.tests.comfy.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let bridge = ComfyBridge(defaults: defaults)
        XCTAssertEqual(bridge.serverURL, ComfyBridge.defaultServerURL)
        XCTAssertEqual(bridge.workflowPath, "")
        XCTAssertFalse(bridge.hasWorkflow)

        bridge.serverURL = " http://10.0.0.5:8188 "
        bridge.workflowPath = "/Users/me/seedvr2-api.json"
        bridge.inputNodeID = "10"
        bridge.inputFieldName = "image"
        bridge.outputNodeID = "12"

        let again = ComfyBridge(defaults: defaults)
        XCTAssertEqual(again.serverURL, "http://10.0.0.5:8188")
        XCTAssertEqual(again.workflowPath, "/Users/me/seedvr2-api.json")
        XCTAssertTrue(again.hasWorkflow)
        XCTAssertEqual(again.inputNodeID, "10")
        XCTAssertEqual(again.inputFieldName, "image")
        XCTAssertEqual(again.outputNodeID, "12")

        again.serverURL = ""
        again.inputNodeID = "   "
        XCTAssertEqual(again.serverURL, ComfyBridge.defaultServerURL, "empty falls back to the default")
        XCTAssertEqual(again.inputNodeID, "")
        XCTAssertNil(defaults.string(forKey: ComfyBridge.Keys.inputNodeID))
    }
}
