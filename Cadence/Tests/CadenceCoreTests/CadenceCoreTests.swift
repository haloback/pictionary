import XCTest
@testable import CadenceCore

final class TheoryTests: XCTestCase {
    func testScaleSnapping() {
        let f = Key(tonic: 5, scale: .dorian)            // F G A♭ B♭ C D E♭
        XCTAssertEqual(f.nearestScaleNote(to: 64), 65)   // E -> F (upward)
        XCTAssertEqual(f.nearestScaleNote(to: 64, direction: -1), 63) // E -> E♭ (downward)
        XCTAssertEqual(f.nearestScaleNote(to: 65), 65)
        XCTAssertTrue(f.prefersFlats)
        XCTAssertEqual(f.name(of: 68), "A♭")
    }

    func testDiatonicChords() {
        let c = Key(tonic: 0, scale: .major)
        XCTAssertEqual(c.diatonicChord(degree: 0, seventh: true).quality, .major7)
        XCTAssertEqual(c.diatonicChord(degree: 1, seventh: true).quality, .minor7)
        XCTAssertEqual(c.diatonicChord(degree: 4, seventh: true).quality, .dominant7)
        XCTAssertEqual(c.diatonicChord(degree: 6, seventh: true).quality, .halfDiminished7)
        XCTAssertEqual(c.diatonicChord(degree: 5, seventh: false), Chord(root: 9, quality: .minor))
    }

    func testChordParsing() {
        XCTAssertEqual(Chord.parse("Fm9"), Chord(root: 5, quality: .minor9))
        XCTAssertEqual(Chord.parse("B♭13"), Chord(root: 10, quality: .dominant13))
        XCTAssertEqual(Chord.parse("Bbmaj7"), Chord(root: 10, quality: .major7))
        XCTAssertEqual(Chord.parse("C/E"), Chord(root: 0, quality: .major, bass: 4))
        XCTAssertEqual(Chord.parse("Ebmaj7#11"), Chord(root: 3, quality: .major7sharp11))
        XCTAssertEqual(Chord.parse("F#m7b5"), Chord(root: 6, quality: .halfDiminished7))
        XCTAssertEqual(Chord.parse("A"), Chord(root: 9, quality: .major))
        XCTAssertEqual(Chord.parse("Am"), Chord(root: 9, quality: .minor))
        XCTAssertNil(Chord.parse("hello"))
    }

    func testRomanNumerals() {
        let f = Key(tonic: 5, scale: .dorian)
        XCTAssertEqual(Chord(root: 5, quality: .minor9).roman(in: f), "i9")
        XCTAssertEqual(Chord(root: 10, quality: .dominant13).roman(in: f), "IV13")
        let c = Key(tonic: 0, scale: .major)
        XCTAssertEqual(Chord(root: 8, quality: .major7).roman(in: c), "♭VImaj7")
        XCTAssertEqual(Chord(root: 2, quality: .minor7).roman(in: c), "ii7")
    }
}

final class VoicingTests: XCTestCase {
    let chords = [Chord(root: 2, quality: .minor9), Chord(root: 7, quality: .dominant13),
                  Chord(root: 0, quality: .major9), Chord(root: 9, quality: .dominant7)]

    func testVoicingsStayInRangeAndSpellTheChord() {
        for style in VoicingStyle.allCases {
            let range = 40...84
            for c in chords {
                let v = VoicingEngine.voice(c, style: style, range: range, previous: nil)
                XCTAssertFalse(v.isEmpty, "\(style)")
                XCTAssertTrue(v.allSatisfy { range.contains($0) }, "\(style) \(v)")
                XCTAssertTrue(v.allSatisfy { c.pitchClasses.contains(mod12($0)) || mod12($0 - c.root) == 2 }, "\(style) \(c) \(v)")
            }
        }
    }

    func testVoiceLeadingMovesLittle() {
        let loop = VoicingEngine.voiceLoop(chords, style: .rootless, range: 50...77)
        for i in 0..<loop.count {
            let a = loop[i], b = loop[(i + 1) % loop.count]
            let movement = zip(a.sorted(), b.sorted()).map { abs($0 - $1) }.reduce(0, +)
            XCTAssertLessThan(movement, 14, "\(a) -> \(b)")
        }
    }
}

final class StyleTests: XCTestCase {
    func testLibraryIsLargeAndUnique() {
        let all = StyleLibrary.all
        XCTAssertGreaterThan(all.count, 1000)
        XCTAssertEqual(Set(all.map(\.id)).count, all.count)
        XCTAssertEqual(StyleLibrary.defaultStyle.id, "neo-soul")
        XCTAssertFalse(StyleLibrary.search("rainy bossa").isEmpty)
        XCTAssertFalse(StyleLibrary.search("gospel").isEmpty)
    }

    func testEveryBaseStyleRendersSaneNotes() {
        for style in StyleLibrary.all where style.variation == "Classic" && style.ensemble == "Band" {
            let session = Session(style: style, seed: 3)
            XCTAssertEqual(session.progression.slots.count, 4, style.name)
            let arranger = Arranger(session: session)
            let rendered = arranger.render(bars: 0..<4)
            let total = rendered.reduce(0) { $0 + $1.1.count }
            XCTAssertGreaterThan(total, 8, style.name)
            for (track, events) in rendered {
                for e in events {
                    XCTAssertTrue((0...127).contains(e.pitch), "\(style.name) \(track.name)")
                    XCTAssertTrue((1...127).contains(e.velocity), "\(style.name) \(track.name) vel \(e.velocity)")
                    XCTAssertGreaterThan(e.duration, 0)
                    XCTAssertGreaterThan(e.start, -0.2)
                }
            }
        }
    }

    func testRenderingIsDeterministic() {
        let session = Session(style: StyleLibrary.style(id: "afrobeats"), seed: 9)
        let a = Arranger(session: session).render(bars: 0..<2).flatMap(\.1)
        let b = Arranger(session: session).render(bars: 0..<2).flatMap(\.1)
        XCTAssertEqual(a, b)
    }

    func testGeneratedChordsFitTheKey() {
        let style = StyleLibrary.style(id: "modern-pop")
        let key = Key(tonic: 7, scale: .major)
        let prog = ProgressionGenerator.generate(style: style, key: key, seed: 4)
        for slot in prog.slots {
            XCTAssertTrue(key.contains(slot.chord.root), slot.chord.symbol(in: key))
        }
    }

    func testMuteAndSolo() {
        var session = Session(style: StyleLibrary.defaultStyle)
        session.tracks[0].muted = true
        XCTAssertFalse(session.isAudible(session.tracks[0]))
        session.tracks[1].solo = true
        XCTAssertTrue(session.isAudible(session.tracks[1]))
        XCTAssertFalse(session.isAudible(session.tracks[2]))
    }

    func testDraggedRegionExtendsSong() {
        var session = Session(style: StyleLibrary.defaultStyle)
        XCTAssertEqual(session.songBars, 4)
        session.tracks[0].lengthBars = 12
        XCTAssertEqual(session.songBars, 12)
        let arranger = Arranger(session: session)
        XCTAssertFalse(arranger.render(track: session.tracks[0], bar: 10).isEmpty)
    }
}

final class PerformerTests: XCTestCase {
    let fDorian = Key(tonic: 5, scale: .dorian)
    let fm9 = Chord(root: 5, quality: .minor9)

    func testWrongNotesSnapIntoScale() {
        let p = Performer(key: fDorian, snap: .guided, instrument: .of(.grandPiano))
        for input in 48..<84 {
            let out = p.noteOn(input, velocity: 90, time: Double(input), beatPhase: 0.5, chord: fm9)
            for o in out where o.isOn { XCTAssertTrue(fDorian.contains(o.pitch), "\(input) -> \(o.pitch)") }
            _ = p.noteOff(input)
        }
    }

    func testStrictLandsOnChordTones() {
        let p = Performer(key: fDorian, snap: .strict, instrument: .of(.grandPiano))
        for input in 48..<84 {
            let out = p.noteOn(input, velocity: 90, time: Double(input), beatPhase: 0.5, chord: fm9)
            for o in out where o.isOn { XCTAssertTrue(fm9.pitchClasses.contains(mod12(o.pitch))) }
            _ = p.noteOff(input)
        }
    }

    func testMashBecomesChordWithoutDuplicates() {
        let p = Performer(key: fDorian, snap: .guided, instrument: .of(.grandPiano))
        var ons: [Int] = []
        for (i, k) in [60, 61, 62, 63, 64].enumerated() {
            ons += p.noteOn(k, velocity: 100, time: 1 + Double(i) * 0.005, beatPhase: 0.4, chord: fm9).filter(\.isOn).map(\.pitch)
        }
        XCTAssertEqual(Set(ons).count, ons.count)
        // Everything after the first key of the mash is a chord tone.
        XCTAssertTrue(ons.dropFirst().allSatisfy { fm9.pitchClasses.contains(mod12($0)) }, "\(ons)")
        var offs: [Int] = []
        for k in [60, 61, 62, 63, 64] { offs += p.noteOff(k).map(\.pitch) }
        XCTAssertEqual(Set(offs), Set(ons))
        XCTAssertTrue(p.soundingPitches.isEmpty)
    }

    func testViolinIsMonophonicAndSoft() {
        let p = Performer(key: fDorian, snap: .guided, instrument: .of(.violin))
        var sounding = Set<Int>()
        for (i, k) in [60, 64, 67, 72].enumerated() {
            for o in p.noteOn(k, velocity: 120, time: 1 + Double(i) * 0.004, beatPhase: 0, chord: fm9) {
                if o.isOn { sounding.insert(o.pitch); XCTAssertLessThanOrEqual(o.velocity, 100) } else { sounding.remove(o.pitch) }
            }
        }
        XCTAssertEqual(sounding.count, 1)
    }

    func testGuitarStrumsAMash() {
        let p = Performer(key: fDorian, snap: .guided, instrument: .of(.steelGuitar))
        var outs: [LiveOutput] = []
        for (i, k) in [52, 55, 59].enumerated() {
            outs += p.noteOn(k, velocity: 100, time: 2 + Double(i) * 0.004, beatPhase: 0, chord: fm9)
        }
        let delays = outs.filter(\.isOn).map(\.delay)
        XCTAssertGreaterThanOrEqual(delays.count, 4)
        XCTAssertGreaterThan(delays.max() ?? 0, 0.02)
    }

    func testTempoDetection() {
        var d = TempoDetector()
        let beat = 60.0 / 96
        for i in 0..<16 { d.add(onset: 10 + Double(i) * beat + (i % 3 == 0 ? 0.01 : -0.008)) }
        let bpm = d.estimate(range: 70...130, prior: 110)
        XCTAssertNotNil(bpm)
        XCTAssertEqual(bpm ?? 0, 96, accuracy: 2)
    }

    func testTakeRecorderLoopsToWholeBars() {
        var r = TakeRecorder(startBeat: 8)
        r.noteOn(60, velocity: 80, beat: 8.02)
        r.noteOff(60, beat: 9)
        r.noteOn(62, velocity: 80, beat: 13.5)
        let take = r.finish(atBeat: 14.5, beatsPerBar: 4)
        XCTAssertEqual(take.bars, 2)
        XCTAssertEqual(take.notes.count, 2)
        XCTAssertLessThan(take.notes[0].start, 0.02)
    }
}

final class MIDITests: XCTestCase {
    func testRoundTrip() throws {
        let events = [NoteEvent(pitch: 60, velocity: 100, start: 0, duration: 1),
                      NoteEvent(pitch: 64, velocity: 90, start: 1.5, duration: 0.5)]
        let data = MIDIFile.write(tracks: [MIDIFile.TrackData(name: "Keys", channel: 0, program: 4, volume: 0.8, events: events)],
                                  tempo: 92, beatsPerBar: 4)
        let read = try MIDIFile.read(data)
        XCTAssertEqual(read.tempo ?? 0, 92, accuracy: 0.1)
        XCTAssertEqual(read.beatsPerBar, 4)
        XCTAssertEqual(read.notes.count, 2)
        XCTAssertEqual(read.notes[1].pitch, 64)
        XCTAssertEqual(read.notes[1].start, 1.5, accuracy: 0.01)
        XCTAssertEqual(read.trackNames.last, "Keys")
    }

    func testChordDetectionFromMIDI() throws {
        let chords: [[Int]] = [[50, 53, 57, 60], [55, 59, 62, 65], [48, 52, 55, 59], [57, 61, 64, 67]] // Dm7 G7 Cmaj7 A7
        var events: [NoteEvent] = []
        for (i, c) in chords.enumerated() {
            events += c.map { NoteEvent(pitch: $0, velocity: 90, start: Double(i * 4), duration: 3.9) }
        }
        let data = MIDIFile.write(tracks: [MIDIFile.TrackData(name: "Chords", channel: 0, program: 0, volume: 1, events: events)],
                                  tempo: 100, beatsPerBar: 4)
        let contents = try MIDIFile.read(data)
        let (prog, _) = try XCTUnwrap(ChordDetector.progression(from: contents.notes, beatsPerBar: 4))
        XCTAssertEqual(prog.slots.map(\.chord), [Chord(root: 2, quality: .minor7), Chord(root: 7, quality: .dominant7),
                                                 Chord(root: 0, quality: .major7), Chord(root: 9, quality: .dominant7)])
        XCTAssertEqual(prog.slots.map(\.beats), [4, 4, 4, 4])
    }

    func testTextProgression() throws {
        let p = try XCTUnwrap(ChordDetector.progression(fromText: "Dm9 G13 | Cmaj9 | A7b13", beatsPerBar: 4))
        XCTAssertEqual(p.slots.count, 4)
        XCTAssertEqual(p.slots.map(\.beats), [2, 2, 4, 4])
        let simple = try XCTUnwrap(ChordDetector.progression(fromText: "C G Am F", beatsPerBar: 4))
        XCTAssertEqual(ChordDetector.key(for: simple), Key(tonic: 0, scale: .major))
    }

    func testExportHasOneTrackPerLayer() throws {
        let session = Session(style: StyleLibrary.defaultStyle)
        let data = Exporter.midi(session: session)
        let contents = try MIDIFile.read(data)
        XCTAssertEqual(contents.trackNames.count, session.tracks.count + 1)
        XCTAssertTrue(contents.notes.contains { $0.channel == 9 })
    }
}

final class KeyMapTests: XCTestCase {
    let fm9 = Chord(root: 5, quality: .minor9)

    func testWhiteKeysWalkTheScaleInAnyKey() {
        let mapper = KeyMapper(key: Key(tonic: 3, scale: .dorian), progressionChords: [], colorLevel: 1)   // E♭ Dorian
        let whites = (48..<84).filter(KeyMapper.isWhite)
        let pitches = whites.map(mapper.scalePitch(forKey:))
        XCTAssertEqual(pitches, pitches.sorted())
        XCTAssertEqual(Set(pitches).count, pitches.count)
        XCTAssertTrue(pitches.allSatisfy { Key(tonic: 3, scale: .dorian).contains($0) })
        XCTAssertEqual(mod12(mapper.scalePitch(forKey: 60)), 3)          // middle C plays the tonic
        // Pentatonic: still strictly rising, still in key.
        let pent = KeyMapper(key: Key(tonic: 9, scale: .minorPentatonic), progressionChords: [], colorLevel: 0)
        let pp = whites.map(pent.scalePitch(forKey:))
        XCTAssertEqual(pp, pp.sorted())
        XCTAssertEqual(Set(pp).count, pp.count)
    }

    func testBlackKeysPlayChordTones() {
        let mapper = KeyMapper(key: Key(tonic: 5, scale: .dorian), progressionChords: [], colorLevel: 1)
        for k in (48..<84).filter({ !KeyMapper.isWhite($0) }) {
            XCTAssertTrue(fm9.pitchClasses.contains(mod12(mapper.chordTone(forKey: k, chord: fm9))))
        }
    }

    func testOneKeyChords() {
        let prog = [Chord(root: 2, quality: .minor7), Chord(root: 7, quality: .dominant7)]
        let mapper = KeyMapper(key: Key(tonic: 0, scale: .major), progressionChords: prog, colorLevel: 1)
        XCTAssertEqual(mapper.chord(forKey: 60)?.root, 0)                 // C = I
        XCTAssertEqual(mapper.chord(forKey: 62)?.quality.isMinor, true)   // D = ii
        XCTAssertEqual(mapper.chord(forKey: 61), prog[0])                 // C♯ = progression chord 1
        XCTAssertEqual(mapper.chord(forKey: 63), prog[1])

        let p = Performer(key: Key(tonic: 0, scale: .major), snap: .guided, instrument: .of(.grandPiano))
        p.keyMap = .chordKeys
        p.mapper = mapper
        let ons = p.noteOn(67, velocity: 100, time: 1, beatPhase: 0, chord: fm9).filter(\.isOn).map(\.pitch)
        XCTAssertGreaterThanOrEqual(ons.count, 3)
        let g = mapper.chord(forKey: 67)!
        XCTAssertTrue(ons.allSatisfy { g.pitchClasses.contains(mod12($0)) }, "\(ons)")
        _ = p.noteOff(67)
        XCTAssertTrue(p.soundingPitches.isEmpty)
        // Low keys add a bass note underneath.
        let low = p.noteOn(43, velocity: 100, time: 2, beatPhase: 0, chord: fm9).filter(\.isOn).map(\.pitch)
        XCTAssertEqual(mod12(low.min()!), 7)
    }
}

final class ReharmonizerTests: XCTestCase {
    let c = Key(tonic: 0, scale: .major)

    func testSuggestionsCoverTheClassics() {
        let g7 = Chord(root: 7, quality: .dominant7)
        let ideas = Reharmonizer.suggestions(for: g7, next: Chord(root: 0, quality: .major7), key: c)
        XCTAssertTrue(ideas.contains { $0.chord == Chord(root: 1, quality: .dominant7) && $0.kind == .substitute }, "tritone sub")
        XCTAssertTrue(ideas.contains { $0.chord.quality == .dominant13 && $0.kind == .color })
        XCTAssertFalse(ideas.contains { $0.chord == g7 })

        let f = Chord(root: 5, quality: .major)
        let fIdeas = Reharmonizer.suggestions(for: f, next: Chord(root: 9, quality: .minor), key: c)
        XCTAssertTrue(fIdeas.contains { $0.chord == Chord(root: 5, quality: .minor) && $0.kind == .borrowed }, "borrowed iv")
        XCTAssertTrue(fIdeas.contains { $0.chord == Chord(root: 4, quality: .dominant7) && $0.kind == .leading }, "V7/vi")
        XCTAssertTrue(fIdeas.contains { $0.chord == Chord(root: 2, quality: .minor) && $0.kind == .substitute }, "ii shares notes with IV")
    }

    func testNamedProgressionsBuildInKey() {
        XCTAssertGreaterThanOrEqual(NamedProgression.library.count, 20)
        let blues = NamedProgression.library.first { $0.name == "Twelve-Bar Blues" }!
        XCTAssertEqual(blues.progression(tonic: 9, beatsPerBar: 4).slots.count, 12)
        let axis = NamedProgression.library.first { $0.name == "Axis" }!
        XCTAssertEqual(axis.romanSummary, "I – V – vi – IV")
        var s = Session(style: StyleLibrary.style(id: "modern-pop"))
        s.key = Key(tonic: 7, scale: .major)
        s.apply(named: axis)
        XCTAssertEqual(s.progression.slots.map(\.chord.root), [7, 2, 4, 0])
        let epic = NamedProgression.library.first { $0.name == "Epic Minor" }!
        s.apply(named: epic)
        XCTAssertTrue(s.key.scale.isMinorish)
        XCTAssertEqual(epic.romanSummary, "i – VI – III – VII")
    }
}
