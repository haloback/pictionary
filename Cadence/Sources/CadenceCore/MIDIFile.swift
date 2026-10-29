import Foundation

/// Standard MIDI File (format 1) writing and reading.
public enum MIDIFile {
    public struct TrackData: Sendable {
        public var name: String
        public var channel: Int
        public var program: Int
        public var volume: Double
        public var events: [NoteEvent]

        public init(name: String, channel: Int, program: Int, volume: Double, events: [NoteEvent]) {
            self.name = name
            self.channel = channel
            self.program = program
            self.volume = volume
            self.events = events
        }
    }

    public struct Marker: Sendable {
        public var beat: Double
        public var text: String
        public init(beat: Double, text: String) {
            self.beat = beat
            self.text = text
        }
    }

    public struct Note: Hashable, Sendable {
        public var pitch: Int
        public var velocity: Int
        public var start: Double
        public var duration: Double
        public var channel: Int
        public var track: Int
    }

    public struct Contents: Sendable {
        public var notes: [Note]
        public var tempo: Double?
        public var beatsPerBar: Int?
        public var trackNames: [String]
    }

    public enum ReadError: Error {
        case notMIDI, truncated
    }

    // MARK: Writing

    public static func write(tracks: [TrackData], tempo: Double, beatsPerBar: Int, markers: [Marker] = [], title: String = "Cadence", ppq: Int = 480) -> Data {
        var file = Data()
        file.append(contentsOf: Array("MThd".utf8))
        file.append(be32(6))
        file.append(be16(1))
        file.append(be16(UInt16(tracks.count + 1)))
        file.append(be16(UInt16(ppq)))

        // Conductor track: title, tempo, meter, chord markers.
        var conductor: [(Int, [UInt8])] = []
        conductor.append((0, meta(0x03, Array(title.utf8))))
        let usPerQuarter = Int((60_000_000 / max(tempo, 1)).rounded())
        conductor.append((0, meta(0x51, [UInt8((usPerQuarter >> 16) & 0xFF), UInt8((usPerQuarter >> 8) & 0xFF), UInt8(usPerQuarter & 0xFF)])))
        conductor.append((0, meta(0x58, [UInt8(beatsPerBar), 2, 24, 8])))
        for m in markers {
            conductor.append((tick(m.beat, ppq), meta(0x06, Array(m.text.utf8))))
        }
        file.append(chunk(conductor))

        for t in tracks {
            let ch = UInt8(t.channel & 0x0F)
            var evs: [(Int, [UInt8])] = []
            evs.append((0, meta(0x03, Array(t.name.utf8))))
            evs.append((0, [0xB0 | ch, 7, UInt8(min(max(t.volume, 0), 1) * 127)]))
            evs.append((0, [0xC0 | ch, UInt8(min(max(t.program, 0), 127))]))
            var notes: [(Int, Int, [UInt8])] = []        // tick, order (offs first), bytes
            for e in t.events {
                let p = UInt8(min(max(e.pitch, 0), 127))
                let v = UInt8(min(max(e.velocity, 1), 127))
                let on = tick(max(e.start, 0), ppq)
                let off = max(on + 1, tick(max(e.end, 0), ppq))
                notes.append((on, 1, [0x90 | ch, p, v]))
                notes.append((off, 0, [0x80 | ch, p, 0]))
            }
            notes.sort { $0.0 != $1.0 ? $0.0 < $1.0 : $0.1 < $1.1 }
            evs.append(contentsOf: notes.map { ($0.0, $0.2) })
            file.append(chunk(evs))
        }
        return file
    }

    static func tick(_ beat: Double, _ ppq: Int) -> Int { Int((beat * Double(ppq)).rounded()) }

    static func meta(_ type: UInt8, _ data: [UInt8]) -> [UInt8] { [0xFF, type] + vlq(data.count) + data }

    static func chunk(_ events: [(Int, [UInt8])]) -> Data {
        var body = [UInt8]()
        var last = 0
        for (t, bytes) in events.sorted(by: { $0.0 < $1.0 }) {
            body += vlq(t - last)
            body += bytes
            last = t
        }
        body += [0x00, 0xFF, 0x2F, 0x00]
        var d = Data(Array("MTrk".utf8))
        d.append(be32(UInt32(body.count)))
        d.append(contentsOf: body)
        return d
    }

    static func vlq(_ value: Int) -> [UInt8] {
        var v = max(value, 0)
        var bytes = [UInt8(v & 0x7F)]
        v >>= 7
        while v > 0 {
            bytes.insert(UInt8(v & 0x7F) | 0x80, at: 0)
            v >>= 7
        }
        return bytes
    }

    static func be16(_ v: UInt16) -> Data { Data([UInt8(v >> 8), UInt8(v & 0xFF)]) }
    static func be32(_ v: UInt32) -> Data { Data([UInt8(v >> 24), UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)]) }

    // MARK: Reading

    public static func read(_ data: Data) throws -> Contents {
        let b = [UInt8](data)
        var i = 0
        func u32() throws -> Int {
            guard i + 4 <= b.count else { throw ReadError.truncated }
            defer { i += 4 }
            return Int(b[i]) << 24 | Int(b[i + 1]) << 16 | Int(b[i + 2]) << 8 | Int(b[i + 3])
        }
        func u16() throws -> Int {
            guard i + 2 <= b.count else { throw ReadError.truncated }
            defer { i += 2 }
            return Int(b[i]) << 8 | Int(b[i + 1])
        }
        guard b.count >= 14, String(bytes: b[0..<4], encoding: .ascii) == "MThd" else { throw ReadError.notMIDI }
        i = 4
        let headerLen = try u32()
        _ = try u16()
        let trackCount = try u16()
        var division = try u16()
        if division & 0x8000 != 0 || division == 0 { division = 480 }
        i = 8 + headerLen

        var notes: [Note] = []
        var tempo: Double?
        var bpb: Int?
        var names: [String] = []

        for trackIndex in 0..<trackCount {
            guard i + 8 <= b.count else { break }
            let tag = String(bytes: b[i..<(i + 4)], encoding: .ascii)
            i += 4
            let len = try u32()
            let end = min(i + len, b.count)
            if tag != "MTrk" { i = end; continue }
            var t = 0
            var status: UInt8 = 0
            var open: [Int: (Int, Int)] = [:]   // (channel<<8|pitch) -> (tick, vel)
            var name = ""
            func readVLQ() -> Int {
                var v = 0
                while i < end {
                    let c = b[i]; i += 1
                    v = (v << 7) | Int(c & 0x7F)
                    if c & 0x80 == 0 { break }
                }
                return v
            }
            func close(_ k: Int, at tickNow: Int) {
                if let (st, vel) = open.removeValue(forKey: k) {
                    notes.append(Note(pitch: k & 0xFF, velocity: vel, start: Double(st) / Double(division),
                                      duration: Double(max(tickNow - st, 1)) / Double(division), channel: k >> 8, track: trackIndex))
                }
            }
            while i < end {
                t += readVLQ()
                guard i < end else { break }
                var s = b[i]
                if s & 0x80 != 0 {
                    i += 1
                    if s < 0xF0 { status = s }
                } else {
                    s = status   // running status
                }
                if s == 0xFF {
                    guard i < end else { break }
                    let type = b[i]; i += 1
                    let l = readVLQ()
                    let payload = Array(b[i..<min(i + l, end)])
                    i += l
                    if type == 0x51, payload.count == 3, tempo == nil {
                        let us = Int(payload[0]) << 16 | Int(payload[1]) << 8 | Int(payload[2])
                        if us > 0 { tempo = 60_000_000 / Double(us) }
                    } else if type == 0x58, payload.count >= 2, bpb == nil {
                        let denom = 1 << Int(payload[1])
                        bpb = denom == 8 && payload[0] % 3 == 0 ? Int(payload[0]) / 3 : Int(payload[0])
                    } else if type == 0x03 {
                        name = String(decoding: payload, as: UTF8.self)
                    } else if type == 0x2F {
                        break
                    }
                } else if s == 0xF0 || s == 0xF7 {
                    i += readVLQ()
                } else {
                    let kind = s & 0xF0
                    let ch = Int(s & 0x0F)
                    let needs = (kind == 0xC0 || kind == 0xD0) ? 1 : 2
                    guard i + needs <= end else { break }
                    let d1 = Int(b[i]), d2 = needs == 2 ? Int(b[i + 1]) : 0
                    i += needs
                    let k = ch << 8 | d1
                    if kind == 0x90 && d2 > 0 {
                        close(k, at: t)
                        open[k] = (t, d2)
                    } else if kind == 0x80 || (kind == 0x90 && d2 == 0) {
                        close(k, at: t)
                    }
                }
            }
            for k in Array(open.keys) { close(k, at: t) }
            names.append(name)
            i = end
        }
        return Contents(notes: notes.sorted { $0.start < $1.start }, tempo: tempo, beatsPerBar: bpb, trackNames: names)
    }
}

/// Builds the multi-track export: one MIDI track per layer.
public enum Exporter {
    public static func midi(session: Session, title: String = "Cadence Session") -> Data {
        let arranger = Arranger(session: session)
        let bars = session.songBars
        var tracks: [MIDIFile.TrackData] = []
        var nextChannel = 0
        for (track, events) in arranger.render(bars: 0..<bars) where !events.isEmpty {
            let prof = track.profile
            let channel: Int
            if prof.isDrums {
                channel = 9
            } else {
                channel = nextChannel
                nextChannel += 1
                if nextChannel == 9 { nextChannel = 10 }
                if nextChannel > 15 { nextChannel = 0 }
            }
            tracks.append(MIDIFile.TrackData(name: track.name, channel: channel, program: prof.program,
                                             volume: track.volume, events: events))
        }
        // Chord names as markers so a DAW shows the progression.
        var markers: [MIDIFile.Marker] = []
        let prog = session.progression
        var beat = 0.0
        let total = Double(bars * session.beatsPerBar)
        while beat < total && !prog.slots.isEmpty {
            let idx = prog.slotIndex(atBeat: beat)
            markers.append(MIDIFile.Marker(beat: beat, text: prog.slots[idx].chord.symbol(in: session.key)))
            beat += prog.slots[idx].beats
        }
        return MIDIFile.write(tracks: tracks, tempo: session.tempo, beatsPerBar: session.beatsPerBar,
                              markers: markers, title: title)
    }

    /// A single layer as its own file (for dragging one track out).
    public static func midi(track: Track, session: Session) -> Data {
        var s = session
        s.tracks = s.tracks.map { var t = $0; t.solo = $0.id == track.id; t.muted = false; return t }
        return midi(session: s, title: track.name)
    }
}
