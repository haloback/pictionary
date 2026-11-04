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

final class SongSectionTests: XCTestCase {
    func testSectionsDriveChordsLengthAndEnergy() {
        var s = Session(style: StyleLibrary.style(id: "modern-pop"), seed: 4)
        s.buildSong()
        XCTAssertEqual(s.sections.map(\.kind), [.intro, .verse, .preChorus, .chorus, .verse, .preChorus, .chorus, .bridge, .chorus, .outro])
        XCTAssertEqual(s.songBars, s.sections.reduce(0) { $0 + $1.bars })
        // Every chorus shares one set of chords, different from the verse.
        let choruses = s.sections.filter { $0.kind == .chorus }
        XCTAssertEqual(Set(choruses.compactMap(\.chordsKey)).count, 1)
        let chorusChords = s.progression(forKey: choruses[0].chordsKey).slots.map(\.chord)
        XCTAssertNotEqual(chorusChords, s.progression.slots.map(\.chord))

        let chorusStart = s.startBar(ofSection: 3)
        let h = s.harmony(atBar: chorusStart)
        XCTAssertEqual(h.sectionIndex, 3)
        XCTAssertTrue(h.isSectionStart)
        XCTAssertEqual(s.chord(atSongBeat: Double(chorusStart * s.beatsPerBar)), chorusChords[0])
        XCTAssertTrue(s.harmony(atBar: chorusStart - 1).isSectionEnd)

        // A breakdown plays far less than a chorus.
        s.addSection(.breakdown)
        let a = Arranger(session: s)
        let breakdownBar = s.startBar(ofSection: s.sections.count - 1)
        func notes(_ bar: Int) -> Int { s.tracks.filter { $0.part != nil }.map { a.render(track: $0, bar: bar).count }.reduce(0, +) }
        let chorusNotes = (0..<4).map { notes(chorusStart + $0) }.reduce(0, +)
        let quietNotes = (0..<4).map { notes(breakdownBar + $0) }.reduce(0, +)
        XCTAssertLessThan(quietNotes, chorusNotes)
    }

    func testEditingOneSectionOnlyChangesItsChords() {
        var s = Session(style: StyleLibrary.defaultStyle)
        s.addSection(.verse)
        s.addSection(.verse)
        s.giveOwnChords(sectionID: s.sections[1].id)
        let key = s.sections[1].chordsKey!
        s.sectionProgressions[key]!.slots[0].chord = Chord(root: 1, quality: .dominant7)
        XCTAssertNotEqual(s.chord(atSongBeat: 0), Chord(root: 1, quality: .dominant7))
        XCTAssertEqual(s.chord(atSongBeat: Double(s.sections[0].bars * s.beatsPerBar)), Chord(root: 1, quality: .dominant7))
    }

    func testOldSavedSessionsStillLoad() throws {
        var old = try JSONSerialization.jsonObject(with: JSONEncoder().encode(Session(style: StyleLibrary.defaultStyle))) as! [String: Any]
        for k in ["sections", "sectionProgressions", "bandFollowsMe", "countInBars", "clickEnabled", "takeQuantize", "quantizeGrid", "keyMap"] {
            old.removeValue(forKey: k)
        }
        var tracks = old["tracks"] as! [[String: Any]]
        for i in tracks.indices { tracks[i].removeValue(forKey: "quantize"); tracks[i].removeValue(forKey: "quantizeGrid") }
        old["tracks"] = tracks
        let s = try JSONDecoder().decode(Session.self, from: JSONSerialization.data(withJSONObject: old))
        XCTAssertTrue(s.sections.isEmpty)
        XCTAssertEqual(s.countInBars, 1)
        XCTAssertEqual(s.tracks.first?.quantizeGrid, 4)
    }
}

final class GrooveTests: XCTestCase {
    func testGrooveIsLearnedAndApplied() throws {
        // A drummer who plays every off-beat 16th late and soft.
        var notes: [NoteEvent] = []
        for bar in 0..<2 {
            for step in 0..<16 {
                let late = step % 2 == 1 ? 0.06 : 0
                notes.append(NoteEvent(pitch: 42, velocity: step % 2 == 1 ? 60 : 100, start: Double(bar * 4) + Double(step) * 0.25 + late, duration: 0.1))
            }
        }
        let g = try XCTUnwrap(GrooveTemplate.learn(from: notes, beatsPerBar: 4, name: "Late 16ths"))
        XCTAssertEqual(g.offset(atPos: 0.25), 0.06, accuracy: 0.005)
        XCTAssertEqual(g.offset(atPos: 0.5), 0, accuracy: 0.005)
        XCTAssertLessThan(g.velocityScale(atPos: 0.25), g.velocityScale(atPos: 0.5))

        // Applied by the humanizer: an off-beat 16th moves late and gets softer.
        let h = Humanizer(feel: .straight, tempo: 100, amount: 0, beatsPerBar: 4, stepsPerBeat: 4, groove: g)
        var rng = SeededRandom(seed: 1)
        let out = h.apply([NoteEvent(pitch: 60, velocity: 100, start: 0.25, duration: 0.2),
                           NoteEvent(pitch: 60, velocity: 100, start: 0.5, duration: 0.2)], bar: 0, instrument: .of(.grandPiano), rng: &rng)
        XCTAssertEqual(out[0].start, 0.31, accuracy: 0.005)
        XCTAssertEqual(out[1].start, 0.5, accuracy: 0.005)
        XCTAssertLessThan(out[0].velocity, out[1].velocity)
    }

    func testBandReactsToYou() {
        var r = ResponseTracker()
        var t = 10.0
        for _ in 0..<20 { r.noteOn(velocity: 120, at: t); t += 0.1 }      // loud and busy
        var resp = r.response(at: t, beatSeconds: 0.5)
        resp = r.response(at: t, beatSeconds: 0.5)
        XCTAssertGreaterThan(resp.loudness, 1.1)
        XCTAssertLessThan(resp.busyness, 1)
        // Then you stop: the band answers with a fill, once.
        XCTAssertTrue(r.response(at: t + 1.5, beatSeconds: 0.5).fill)
        XCTAssertFalse(r.response(at: t + 3, beatSeconds: 0.5).fill)
        // Soft playing brings the band down.
        var soft = ResponseTracker()
        for i in 0..<6 { soft.noteOn(velocity: 40, at: Double(i)) }
        _ = soft.response(at: 6, beatSeconds: 0.5)
        XCTAssertLessThan(soft.response(at: 6.1, beatSeconds: 0.5).loudness, 0.9)

        let s = Session(style: StyleLibrary.style(id: "modern-pop"))
        let a = Arranger(session: s)
        let comp = s.tracks[0]
        let quiet = a.render(track: comp, bar: 1, response: BandResponse(loudness: 0.75, busyness: 0.6))
        let loud = a.render(track: comp, bar: 1, response: BandResponse(loudness: 1.2))
        XCTAssertLessThan(quiet.map(\.velocity).max() ?? 0, loud.map(\.velocity).max() ?? 0)
    }

    func testPhrasesVaryAndTurnAround() {
        let s = Session(style: StyleLibrary.style(id: "modern-pop"), seed: 2)
        var noFills = s
        noFills.tracks = noFills.tracks.map { var t = $0; t.humanize = 0; return t }
        let a = Arranger(session: noFills)
        let bass = noFills.tracks.first { if case .bass = $0.part?.kind { return true } else { return false } }!
        let bar0 = a.render(track: bass, bar: 0).map { $0.start - 0 }
        let bar3 = a.render(track: bass, bar: 3).map { $0.start - 12 }
        XCTAssertNotEqual(bar0.map { ($0 * 4).rounded() }, bar3.map { ($0 * 4).rounded() })
    }

    func testQuantizePullsTakesTowardTheGrid() {
        XCTAssertEqual(Quantizer.pull(1.1, grid: 4, amount: 1), 1.0, accuracy: 1e-9)
        XCTAssertEqual(Quantizer.pull(1.1, grid: 4, amount: 0.5), 1.05, accuracy: 1e-9)
        XCTAssertEqual(Quantizer.pull(0.36, grid: 3, amount: 1), 1.0 / 3, accuracy: 1e-9)
        var t = Track(name: "take", source: .recorded, instrument: .grandPiano, volume: 1, colorIndex: 0)
        t.take = [NoteEvent(pitch: 60, velocity: 90, start: 0.11, duration: 1)]
        t.takeBars = 1
        t.quantize = 1
        var s = Session(style: StyleLibrary.defaultStyle)
        s.tracks = [t]
        XCTAssertEqual(Arranger(session: s).render(track: t, bar: 0).first?.start ?? -1, 0, accuracy: 1e-9)
    }
}
