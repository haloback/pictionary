import CoreMIDI
import Foundation

/// Listens to every connected MIDI keyboard (and reconnects when you plug one in).
final class MIDIInput: @unchecked Sendable {
    enum Event {
        case noteOn(Int, Int)
        case noteOff(Int)
        case sustain(Bool)
    }

    /// Called on CoreMIDI's thread.
    var onEvent: (@Sendable (Event) -> Void)?
    /// Called on the main thread.
    var onSourcesChanged: (@MainActor ([String]) -> Void)?

    private var client = MIDIClientRef()
    private var port = MIDIPortRef()
    private var connected: Set<MIDIEndpointRef> = []

    func start() {
        let status = MIDIClientCreateWithBlock("Cadence" as CFString, &client) { [weak self] notification in
            if notification.pointee.messageID == .msgSetupChanged {
                DispatchQueue.main.async { self?.connectAll() }
            }
        }
        guard status == noErr else {
            NSLog("Cadence: MIDI client failed (\(status))")
            return
        }
        MIDIInputPortCreateWithProtocol(client, "Cadence Input" as CFString, ._1_0, &port) { [weak self] list, _ in
            self?.handle(list)
        }
        connectAll()
    }

    private func connectAll() {
        var names: [String] = []
        for i in 0..<MIDIGetNumberOfSources() {
            let src = MIDIGetSource(i)
            if !connected.contains(src) {
                MIDIPortConnectSource(port, src, nil)
                connected.insert(src)
            }
            var name: Unmanaged<CFString>?
            if MIDIObjectGetStringProperty(src, kMIDIPropertyDisplayName, &name) == noErr, let n = name?.takeRetainedValue() {
                names.append(n as String)
            }
        }
        MainActor.assumeIsolated { onSourcesChanged?(names) }
    }

    private func handle(_ list: UnsafePointer<MIDIEventList>) {
        for packet in list.unsafeSequence() {
            let count = Int(packet.pointee.wordCount)
            withUnsafeBytes(of: packet.pointee.words) { raw in
                let words = raw.bindMemory(to: UInt32.self)
                for i in 0..<min(count, words.count) {
                    let w = words[i]
                    guard w >> 28 == 0x2 else { continue }          // MIDI 1.0 channel voice
                    let status = (w >> 16) & 0xF0
                    let d1 = Int((w >> 8) & 0x7F)
                    let d2 = Int(w & 0x7F)
                    switch status {
                    case 0x90 where d2 > 0: onEvent?(.noteOn(d1, d2))
                    case 0x90, 0x80: onEvent?(.noteOff(d1))
                    case 0xB0 where d1 == 64: onEvent?(.sustain(d2 >= 64))
                    default: break
                    }
                }
            }
        }
    }
}
