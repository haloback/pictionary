import AVFoundation
import AudioToolbox
import CadenceCore

/// On-device sound: one sampler per layer, loaded from the General MIDI bank
/// that ships with macOS, through a shared room reverb.
final class AudioEngine: @unchecked Sendable {
    static let bankURL = URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls")

    private final class Voice {
        let sampler = AVAudioUnitSampler()
        var instrument: InstrumentID?
        /// Reference count per pitch so overlapping notes don't cut each other off.
        var held: [UInt8: Int] = [:]
    }

    private let engine = AVAudioEngine()
    private let bus = AVAudioMixerNode()
    private let reverb = AVAudioUnitReverb()
    private var voices: [UUID: Voice] = [:]
    private let lock = NSLock()
    private let loadQueue = DispatchQueue(label: "cadence.audio.load", qos: .userInitiated)
    private(set) var isRunning = false

    init() {
        engine.attach(bus)
        engine.attach(reverb)
        reverb.loadFactoryPreset(.mediumHall)
        reverb.wetDryMix = 16
        engine.connect(bus, to: reverb, format: nil)
        engine.connect(reverb, to: engine.mainMixerNode, format: nil)
        engine.mainMixerNode.outputVolume = 0.9
        start()
    }

    func start() {
        guard !engine.isRunning else { return }
        do {
            engine.prepare()
            try engine.start()
            isRunning = true
        } catch {
            NSLog("Cadence: audio engine failed to start: \(error)")
            isRunning = false
        }
    }

    /// Creates or updates the sampler for a layer.
    func configure(id: UUID, instrument: InstrumentProfile, volume: Double) {
        lock.lock()
        let voice: Voice
        var isNew = false
        if let v = voices[id] {
            voice = v
        } else {
            voice = Voice()
            voices[id] = voice
            isNew = true
        }
        let needsLoad = voice.instrument != instrument.id
        voice.instrument = instrument.id
        lock.unlock()

        if isNew {
            engine.attach(voice.sampler)
            engine.connect(voice.sampler, to: bus, format: nil)
        }
        voice.sampler.volume = Float(min(max(volume, 0), 1))
        if needsLoad {
            loadQueue.async { [weak self] in
                self?.load(instrument, into: voice.sampler)
            }
        }
    }

    private func load(_ instrument: InstrumentProfile, into sampler: AVAudioUnitSampler) {
        let msb = instrument.isDrums ? kAUSampler_DefaultPercussionBankMSB : kAUSampler_DefaultMelodicBankMSB
        do {
            try sampler.loadSoundBankInstrument(at: Self.bankURL, program: UInt8(instrument.program),
                                                bankMSB: UInt8(msb), bankLSB: UInt8(kAUSampler_DefaultBankLSB))
        } catch {
            // Some kits are missing from older banks; fall back to the standard kit / piano.
            try? sampler.loadSoundBankInstrument(at: Self.bankURL, program: 0, bankMSB: UInt8(msb),
                                                 bankLSB: UInt8(kAUSampler_DefaultBankLSB))
        }
    }

    func remove(id: UUID) {
        lock.lock()
        let voice = voices.removeValue(forKey: id)
        lock.unlock()
        guard let voice else { return }
        voice.sampler.sendController(123, withValue: 0, onChannel: 0)
        engine.disconnectNodeOutput(voice.sampler)
        engine.detach(voice.sampler)
    }

    var configuredIDs: Set<UUID> {
        lock.lock(); defer { lock.unlock() }
        return Set(voices.keys)
    }

    func noteOn(_ id: UUID, pitch: Int, velocity: Int) {
        guard (0...127).contains(pitch) else { return }
        lock.lock()
        guard let v = voices[id] else { lock.unlock(); return }
        let p = UInt8(pitch)
        let count = v.held[p, default: 0]
        v.held[p] = count + 1
        lock.unlock()
        if count > 0 { v.sampler.stopNote(p, onChannel: 0) }   // re-strike
        v.sampler.startNote(p, withVelocity: UInt8(min(max(velocity, 1), 127)), onChannel: 0)
    }

    func noteOff(_ id: UUID, pitch: Int) {
        guard (0...127).contains(pitch) else { return }
        lock.lock()
        guard let v = voices[id] else { lock.unlock(); return }
        let p = UInt8(pitch)
        let count = v.held[p, default: 0]
        if count <= 1 { v.held[p] = nil } else { v.held[p] = count - 1 }
        lock.unlock()
        if count <= 1 { v.sampler.stopNote(p, onChannel: 0) }
    }

    func allNotesOff(_ id: UUID) {
        lock.lock()
        guard let v = voices[id] else { lock.unlock(); return }
        let pitches = Array(v.held.keys)
        v.held = [:]
        lock.unlock()
        for p in pitches { v.sampler.stopNote(p, onChannel: 0) }
        v.sampler.sendController(64, withValue: 0, onChannel: 0)
    }

    func allNotesOff(except keep: UUID? = nil) {
        for id in configuredIDs where id != keep { allNotesOff(id) }
    }
}
