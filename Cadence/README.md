# Cadence

A native macOS accompanist. Pick a style, start playing and the band follows. Every note you play lands in key: wrong notes slide into the scale, mashed clusters turn into real chord voicings, and your hands take on the technique of whatever instrument you pick.

Everything runs on your Mac. Sound comes from the General MIDI bank built into macOS, and nothing goes over the network.

## Run it

Requires macOS 14 (Sonoma) or later with Xcode 15.3+ or the Swift 5.10 toolchain.

```sh
cd Cadence
swift run Cadence              # quickest
sh scripts/build-app.sh        # builds build/Cadence.app to drag into Applications
```

You can also open `Cadence/Package.swift` in Xcode and press Run.

Plug in any USB or Bluetooth MIDI keyboard; it is picked up automatically, including the sustain pedal. Without one, the Mac keyboard plays: the `A W S E D F T G Y H U J K O L P ; '` keys are a piano, `Z`/`X` change octave, space plays/stops and `R` records. ⌘Z / ⇧⌘Z undo and redo, ⌘S saves, ⌘O opens a session, ⌘I imports chords and ⌘B builds a song.

## What it does

- **About 1,300 playing styles.** 64 hand-tuned genres (neo-soul, gospel, bossa nova, highlife, amapiano, swing, bebop, lo-fi, house, cinematic, classical and more). Each comes in eight moods (Classic, Late Night, Uptempo, Sparse, Live Band, Lo-fi Tape, Cinematic, Unplugged) and as a full band, trio or duo. Search them ("rainy bossa", "90s gospel") or browse the style map from calm to driving and from electronic to acoustic.
- **Snapping.** *Guided* (the default) keeps every note in the scale and pulls mashed chords and strong beats onto chord tones. *Strict* puts every note on a chord tone. *Free* turns correction off.
- **Key modes.** *Any key* snaps whatever you play. *White = scale* turns the white keys into the current scale starting from the tonic, in any key or mode, and the black keys play the current chord's tones. *One-key chords* makes each white key a full chord in the key (C = I, D = ii, …) and each black key one of the progression's chords; low keys add the bass.
- **Reharmonize.** Click any chord for ideas, each with a reason: richer colors, chords with the same function, chords borrowed from parallel modes, tritone subs, and lead-ins to the next chord (V7, ♭II7, passing diminished, sus dominant).
- **Famous progressions.** 25 well-known progressions (Axis, Royal Road, Andalusian cadence, ii–V–I, rhythm changes, neo-soul descent, gospel walk-up, twelve-bar blues…) that drop into your current key.
- **Progressions.** Each style writes its own four-chord loop with idiomatic voicings (rootless, drop-2, quartal, shell, spread, guitar shapes), voice-led so the hands barely move. Click a chord to swap it, type your own ("Dm9 G13 | Cmaj9 | A7b13"), or drag in a `.mid` file and Cadence detects its chords and key.
- **Song sections.** One click builds a full song form: intro, verse, pre-chorus, chorus, bridge and outro. Choruses, pre-choruses and the bridge get their own chords, and every chorus shares one set. Each section has its own length and energy: quiet sections thin the band out and full ones fill it in. The drums fill at the end of each section and build up into bigger ones, with a crash on the downbeat. Click a section to edit its chords; right-click to change its length or energy, give it its own chords, duplicate, move or delete it.
- **A band that listens.** With *Band follows me* on, the band plays louder when you dig in, leaves space when you play busy, and answers with a fill when you pause.
- **Richer grooves.** Patterns vary over each four-bar phrase: a lighter variation in bar 2 and a turnaround in bar 4 (ghost-note pickups, pushed chords, bass approach notes). Drop a drum loop or other MIDI file, or use one of your takes, and the whole band picks up its push and pull, with an amount slider.
- **Recording tools.** Undo and redo for every edit. Save and open sessions as `.cadence` files. A count-in (off, 1 or 2 bars) and an optional click. Takes keep exactly what you played, and a timing slider pulls each one toward the grid (8ths, triplets or 16ths) and can be changed later.
- **Instruments that play like themselves.** A violin is soft, legato and plays the top note of what you mash. A guitar strums real chord shapes. Horns stab and a choir sustains. There are 43 instruments in all.
- **Human feel.** Swing, sitting behind the beat, timing drift, accents, phrase-level dynamics, drum fills and anticipated chord changes, all tuned per style.
- **Automatic tempo.** The band follows the tempo you play; double-click the tempo to fix it.
- **Layers.** Record a take, stop, and it becomes a new looping layer. Add band layers (chords, bass, drums, pads, a melody line, a flute answering you). Click a layer to mute it, right-click to solo or delete it. In Studio view, drag a region's edge to extend it.
- **Export.** Drag **Drag MIDI out** onto Logic, GarageBand, Ableton or Finder to get a multi-track `.mid` file: one track per layer, with chord names as markers. Drag a single layer to export just that one.

## Code layout

| Path | What's there |
| --- | --- |
| `Sources/CadenceCore` | Platform-independent engine: theory, chords, voicing, the style library, patterns, arranger, humanizer, live performer (snapping, mash detection, tempo detection, take recorder), MIDI file I/O and chord detection. |
| `Sources/Cadence` | The SwiftUI app: `AudioEngine` (AVAudioEngine + samplers), `Conductor` (real-time scheduler and live input), `MIDIInput` (CoreMIDI), and the Stage, Studio and style browser views. |
| `Tests/CadenceCoreTests` | Engine tests (`swift test` works on macOS and Linux). |
