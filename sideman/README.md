# Sideman

A macOS app that turns a chord progression into a full band of realistic, expressive MIDI parts: drums, percussion, bass, guitar, keys, trumpet, alto, tenor and bari sax, trombone.

Type chords, pick a style, and Sideman writes each player's part the way a session musician would play it, with velocity, timing feel, articulations, pitch bends and controller curves that any synth or sample library can follow. Drag a part (or the whole band) straight into your DAW.

## What it does

- **Chord chart in, band out.** `Dm9 | G13 | Cmaj9 | A7#9` is all it needs. Slash chords, extensions, alterations, `N.C.`, two or more chords per bar, `.` holds and `%` repeats are understood, and the key is detected.
- **A library of 85+ part recipes** across 11 styles (funk, soul, neo-soul, pop, rock, jazz swing, blues shuffle, bossa, reggae, afrobeat/highlife, ballad). Every recipe re-fits itself to whatever chords you give it.
- **Smart randomize.** One button re-deals the band so the parts complement each other: the bass follows the drummer's kick, only one comping instrument is busy at a time, horns leave room for a soloist, density follows the Energy setting. Lock the parts you like and re-roll the rest. Each track can also draw a new recipe or a new take of the same recipe.
- **Saved takes.** Star a performance to keep it. A take remembers the recipe, the exact performance and its feel settings, works on any progression, and can be dealt back into Randomize.
- **Drag and drop.** Drag a lane or its grip into Logic, Ableton Live, Finder, anywhere that accepts a file. Drag the toolbar handle for the whole arrangement. Drop a MIDI file onto the window to read its chords, or a text chart or saved session to load it.
- **Live MIDI output.** Send playback to any hardware or virtual port (for example the IAC Driver) so your own instruments play the parts in real time.
- **Built-in preview sounds**, so you can audition takes without setting anything up. They are sketches; the realism comes from the MIDI driving your own instruments.

## What makes the parts sound played

| Instrument | Performance detail |
| --- | --- |
| Guitar | Real fretboard shapes found by search; strums roll across the strings in the right order with down/up direction, muted scratches, palm mutes, stabs that slide in from a fret below, strings that ring until re-struck, fingerpicking with alternating thumb |
| Bass | Roots forced on every chord change, chromatic and scale approach notes, anticipations, dead notes, slides, hammer-ons, walking lines, grooves locked to the kick drum |
| Horns | Section voicing (close, drop-2, octaves) under one lead line, a breath curve on every note (forte-piano swells, hairpins, tongued attacks), late vibrato on held notes, scoops, fall-offs, slurs, breathing gaps, instrument ranges |
| Keys | Voice-led chords, rootless jazz voicings, rolled chords, crushed grace notes, left-hand figures, sustain pedal lifted and caught on each change, organ swell pedal |
| Drums | Two-handed hat velocity shapes, ghost notes, laid-back backbeats, fills and crashes at phrase ends, jazz ride with feathered kick and comping |

Everything is humanised in timing and velocity per player and is reproducible from its seed.

## MIDI controller mapping

Each track has its own mapping, so the same performance works on whatever you play it through:

| Preset | Dynamics | Vibrato | Notes |
| --- | --- | --- | --- |
| General MIDI | CC11 | CC1 | Program change and bend range (RPN 0) sent |
| Sample library | CC1 + CC11 | CC21 | The usual orchestral and horn library layout |
| Breath controlled | CC2 + CC11 | CC1 | Physically modelled winds, wind-controller patches |
| Any synth | CC7 | drawn into pitch bend | Works even with no modulation routing |
| Keyswitch library | CC1 + CC11 | CC21 | Keyswitch note before each change of articulation, editable map |
| Notes only | none | none | Humanised notes for shaping by hand |

All of it is editable per track: channel, program, which CCs carry dynamics, vibrato target, bend range, velocity range, sustain pedal and the keyswitch map. Exported files end exactly on the bar line so clips loop cleanly, and carry tempo, chord-symbol markers and track names. Horn parts are written at concert pitch.

## Install

### Download a build

Every push to this branch builds the app on GitHub Actions. Open the latest **Sideman macOS build** run, download the `Sideman-macOS` artifact and open the disk image for your Mac (`arm64` for Apple Silicon, `x64` for Intel).

The build is not notarised by Apple, so the first launch needs one extra step: right-click the app and choose **Open**, or run

```sh
xattr -dr com.apple.quarantine /Applications/Sideman.app
```

### Build it yourself

Requires Node 20 or newer.

```sh
cd sideman
npm install
npm run dist:mac        # writes release/Sideman-<version>-<arch>.dmg
```

A locally built app opens without the quarantine step.

### Develop

```sh
npm run dev             # the interface in a browser at http://localhost:5173
npm run app:dev         # the desktop app with hot reload
npm run app             # the desktop app from a production build
npm test                # engine tests
npm run demo -- funk "E9 | E9 | A13 | A13 B13" 3 out.mid   # print and export an arrangement
```

## Using it

1. Type a progression, or pick one from **Progressions**.
2. Choose a style. Tempo, swing and the band re-deal to suit it.
3. Press **Space** to listen. Press **R** (or **Randomize band**) until you like the direction.
4. Lock what you like. Use the dice on a track for a different recipe, the arrows for another take of the same one.
5. Open the inspector: **Part** to browse the library, **Feel** for complexity, dynamics, humanise and expression, **MIDI** for the controller mapping.
6. Drag lanes into your DAW, or use **File** to save one multi-track file or one file per part.

| Shortcut | Action |
| --- | --- |
| Space | Play / stop |
| R | Randomize band |
| Cmd+Z / Shift+Cmd+Z | Undo / redo |
| Cmd+E | Save MIDI file |
| Cmd+S / Cmd+O | Save / open session |

## Limits

- 4/4 only for now.
- No audio export; Sideman produces MIDI.
- Keyswitch notes default to a generic layout and need matching to your library once.

## Layout

```
src/engine/   chord parsing, theory, recipes per instrument, randomiser, MIDI reader/writer (no UI dependencies)
src/audio/    preview synth and transport, Web MIDI output
src/ui/       React interface
electron/     desktop shell: window, menus, file dialogs, native file drag
tests/        engine tests
```
