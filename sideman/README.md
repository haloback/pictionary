# Sideman

A macOS app that turns a chord progression into a full band of realistic, expressive MIDI parts: drums, percussion, bass, guitar, keys, trumpet, alto, tenor and bari sax, trombone and flute, in 50 instrument types across 28 genres.

Type chords, pick a style, and Sideman writes each player's part the way a session musician would play it, with velocity, timing feel, articulations, pitch bends and controller curves that any synth or sample library can follow. Drag a part (or the whole band) straight into your DAW.

## What it does

- **Chord chart in, band out.** `Dm9 | G13 | Cmaj9 | A7#9` is all it needs. Slash chords, extensions, alterations, `N.C.`, two or more chords per bar, `.` holds and `%` repeats are understood, and the key is detected.
- **28 genres** in five groups: funk, disco, soul, Motown, gospel, neo-soul, hip-hop, New Orleans second line, fusion, house; pop, rock, punk, country, folk, ballad, slow jam; jazz swing, bebop, jazz ballad, blues shuffle; bossa nova, Latin jazz, salsa, reggae, ska; afrobeat, highlife. Each sets tempo, swing and the recipes it is known for.
- **A recorded drummer.** 2,640 bars of real grooves and 646 real fills, played by session drummers and tagged by style, with their own timing and touch. Sideman picks takes that suit your tempo, swing and busyness, re-fits them to the project's feel and drops fills at phrase ends. (Groove MIDI Dataset, CC BY 4.0.)
- **A phrase bank of 11,320 combinable phrases.** 283 rhythm cells (curated, plus derived pickups, tags, pushes and sparse variants) combined with 24 melodic shapes, 8 bass schemes and 4 comping touches. Every phrase re-fits itself to the chords. Open a phrase-bank part in the inspector to see the phrase in each bar and swap any single bar.
- **Phrases that go together.** A band plan decides bar by bar who leads, who answers, where everyone plays the same phrase and where there is space, so a bank lead and a bank answer trade bars instead of talking over each other. Guitar and keys take turns joining a shared accent figure that the horn section can hit too.
- **117 part recipes** in all, mixing the phrase bank, the recorded drummer and hand-written recipes (walking bass, Travis picking, montuno, section stabs, swells, pads and more).
- **Smart randomize.** One button re-deals the band so the parts complement each other: the bass follows the drummer's kick, only one comping instrument is busy at a time, horns leave room for a soloist, a bank lead gets a bank answer behind it, density follows the Energy setting. Lock the parts you like and re-roll the rest. Each track can also draw a new recipe or a new take.
- **28 band presets** covering most genres (Tight funk band, Motown house band, Jazz quintet, Big band, Salsa orchestra, Roots reggae band, Highlife band, Horn section only and so on), and you can save your own bands.
- **Saved takes.** Star a performance to keep it. A take remembers the recipe, the exact performance and its feel settings, works on any progression, and can be dealt back into Randomize.
- **Drag and drop.** Drag a lane or its grip into Logic, Ableton Live, Finder, anywhere that accepts a file. Drag the toolbar handle for the whole arrangement. Drop a MIDI file onto the window to read its chords, or a text chart or saved session to load it.
- **Live MIDI output.** Send playback to any hardware or virtual port (for example the IAC Driver) so your own instruments play the parts in real time.
- **Sampled preview.** Playback uses a General MIDI sound bank driven by the same messages the exported file contains, so you hear the expression curves, vibrato, bends and pedalling. A lighter built-in synth is the fallback.

## Instrument types

Each instrument comes in several types. A type has its own General MIDI program, range, set of articulations and habits, and only ever plays articulations it has.

| Instrument | Types |
| --- | --- |
| Trumpet | Open; Lead (higher, shakes and doits); Harmon mute (scoops, no falls); Cup mute; Flugelhorn (lower, legato, deep vibrato) |
| Alto sax | Alto; R&B growl; Soprano |
| Tenor sax | Tenor; Breathy ballad (subtone, wide vibrato); Rock and roll (honks, growls, falls) |
| Trombone | Tenor (slides between close notes); Bass trombone; Plunger (talking glissandi, growls) |
| Bari sax, Flute | Baritone; Concert flute, Piccolo |
| Guitar | Clean electric; Hollow-body; Muted; Overdriven; Distorted lead (bends, heavy vibrato); Slide guitar (glides note to note); Steel acoustic; Twelve-string (octave courses); Nylon |
| Bass | Fingered; Picked; Fretless (glides, vibrato); Slap (slap and pop); Upright; Synth (portamento, no ghost notes); Five-string (down to low B) |
| Keys | Grand; Upright; Tine and reed electric pianos; Clavinet; Drawbar and rock organ; Vibraphone; String ensemble; Synth pad |
| Drums | Studio, Room, Power, Jazz, Brush kits; Drum machine |

Articulations written into the MIDI (and available as keyswitches): sustain, staccato, marcato, legato, muted, dead note, slide, fall, doit, shake, glissando, growl, subtone, bend up, slap, pop. The Feel tab shows which ones a type has and which the current take uses.

## What makes the parts sound played

| Instrument | Performance detail |
| --- | --- |
| Guitar | Real fretboard shapes found by search; strums roll across the strings in the right order with down/up direction, muted scratches, palm mutes, stabs that slide in from a fret below, strings that ring until re-struck, fingerpicking with alternating thumb |
| Bass | Roots forced on every chord change, chromatic and scale approach notes, anticipations, dead notes, slides, hammer-ons, walking lines, grooves locked to the kick drum |
| Horns | Section voicing (close, drop-2, octaves) under one lead line, a breath curve on every note (forte-piano swells, hairpins, tongued attacks), late vibrato on held notes, scoops, fall-offs, doits, shakes, trombone glissandi, growl and subtone, slurs, breathing gaps, instrument ranges |
| Keys | Voice-led chords, rootless jazz voicings, rolled chords, crushed grace notes, left-hand figures, sustain pedal lifted and caught on each change, organ swell pedal |
| Drums | Recorded human performances with their real timing and velocities, plus programmed kits with two-handed hat shapes, ghost notes, laid-back backbeats, fills and crashes at phrase ends |

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
3. Pick a band from **Bands**, or keep the players you have. Press **Space** to listen. Press **R** (or **Randomize band**) until you like the direction.
4. Lock what you like. Use the dice on a track for a different recipe, the arrows for another take of the same one.
5. Open the inspector: **Part** to browse the library and swap single phrases, **Feel** for the instrument type's articulations and for complexity, dynamics, humanise and expression, **MIDI** for the controller mapping.
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
- The sampled preview is a General MIDI sound bank: good for judging a part, not a substitute for your own instruments. It has one sound per program, so types that share a program (for example open trumpet and flugelhorn) differ in how they are played, not in timbre.
- Phrase-bank phrases are built by combining rhythm cells with shapes. Only the drums are recordings of real players; no openly licensed bass, guitar or horn performance data could be found that may be bundled.
- Keyswitch notes default to a generic layout and need matching to your library once.

## Built on

Before extending the engine, existing open-source work was surveyed. What was adopted, and what was left out and why:

| Project or data | Licence | Decision |
| --- | --- | --- |
| Groove MIDI Dataset (real drummers, 13.6 hours, 18 styles) | CC BY 4.0 | Adopted: the recorded drummer |
| spessasynth_lib (SoundFont synthesizer) | Apache-2.0 | Adopted: the sampled preview |
| FluidR3Mono_GM.sf3 (General MIDI sound bank, 14.6 MB) | MIT | Adopted: fetched at build time, checksum-pinned |
| MMA (Musical MIDI Accompaniment), Impro-Visor, JJazzLab | GPL-2 / LGPL-2.1 | Not used. They hold large style and lick libraries, but copying them would put Sideman under the same terms. That is a choice for the owner of this repository |
| FiloBass, Filosax (bass and sax transcriptions) | Research only, no redistribution | Cannot be bundled |
| Other JS synths (webaudiofont, js-synthesizer) | GPL-3 / LGPL core | Not used |

Full notices are in [`licenses/`](licenses/). To rebuild the drum bank from the dataset: `python3 -I scripts/build_groove_bank.py groove-v1.0.0-midionly.zip src/engine/data/groove.json`.

## Layout

```
src/engine/   chord parsing, theory, recipes per instrument, phrase bank, recorded drummer, randomiser, presets, MIDI reader/writer (no UI dependencies)
src/audio/    sampled and built-in preview synths, transport, Web MIDI output
src/ui/       React interface
electron/     desktop shell: window, menus, file dialogs, native file drag
scripts/      sound bank fetch, groove bank builder, demo
licenses/     third-party notices
tests/        engine tests
```
