# Hamfist

Smash keys, get music. Hamfist is a macOS instrument that takes whatever you
mash on a computer keyboard or a MIDI controller and plays it back in key, on
the beat and in the style of one of 597 genres, with a band of layers that
follows your hands. Everything it plays is also MIDI: route it live into a DAW
or save the take as a multi-track `.mid` file.

## What it does

- **Any keys in, music out.** Each key you hit is re-pitched to the nearest
  note that fits the current chord and scale. Fistfuls of neighbouring keys
  are spread into open voicings instead of clusters. Hit timing is pulled
  onto the genre's grid (straight, swung or triplet) by an amount you choose.
- **Polyphonic throughout.** Hold as many keys as you like; every one becomes
  its own note. Every layer and every built-in instrument is polyphonic too.
- **597 genres in 24 groups.** Each one sets the scale, chord progressions,
  tempo, meter, swing, drum groove, bass line style, comping rhythm and
  instruments. Bebop walks in swung 12/8, Balkan folk runs in 7/8, flamenco
  uses Phrygian dominant, trap goes half-time with 808s.
- **Layers that follow along.** Add as many as you want:
  Drums, Bass, Chords, Arpeggio, Harmony (shadows each note you play in
  thirds and sixths), Echo (repeats your phrases, re-pitched to the chord
  they land on), Drone, Counter-melody (answers in the gaps). Each layer has
  its own instrument, volume, octave, MIDI channel and a **Follow** amount:
  at 100 it only plays while you do, at 0 it keeps going regardless.
- **MIDI in.** Any connected controller works, with velocity and sustain pedal.
- **MIDI out.** The app creates a virtual CoreMIDI port named `Hamfist`, so
  Logic, Ableton Live, GarageBand and friends see it as an input with no IAC
  setup. Each layer sends on its own channel with a General MIDI program.
- **Always-on capture.** The last ten minutes are remembered. Press
  **Save MIDI** after a happy accident to get a multi-track file.

## Controls

| Input | Action |
| --- | --- |
| Letter, number and punctuation keys, space | Play |
| MIDI controller keys, sustain pedal | Play |
| Up / Down arrows | Previous / next genre |
| Esc | Stop everything |

## Run it

```bash
cd hamfist
npm install
npm run dev        # Electron app with hot reload
npm run dev:web    # browser only, at http://localhost:5173
npm test           # engine tests
```

## Build the macOS app

On a Mac:

```bash
npm run dist:mac   # writes .dmg and .zip for Apple Silicon and Intel to release/
```

The repository also has a GitHub Actions workflow (`Hamfist macOS build`) that
runs the same command on a macOS runner and uploads the `.dmg` files as a
build artifact.

The build is ad-hoc signed, not notarised. The first time you open a copy
downloaded from the internet, right-click the app and choose **Open**, or run
`xattr -cr /Applications/Hamfist.app`.

## How it is put together

```
src/engine   Pure TypeScript, no DOM. Genre database, harmony, the key
             translator, the lookahead sequencer and layer generators,
             the MIDI file writer. Covered by tests/engine.test.ts.
src/audio    Tone.js instruments and drum kits, MIDI in and out.
src/app      State (zustand), capture buffer, wiring.
src/ui       React interface.
electron     Main process: window, virtual MIDI port, file save.
```

The engine emits plain note events to a list of sinks. The built-in synths,
MIDI out, the capture buffer and the piano roll are all just sinks, which is
why what you hear, what you see and what you export always agree.

## Built on

Hamfist stands on these open source projects:

- [tonal](https://github.com/tonaljs/tonal) (MIT): scale and chord dictionaries.
- [Tone.js](https://github.com/Tonejs/Tone.js) (MIT): synthesis and audio scheduling.
- [@julusian/midi](https://github.com/Julusian/node-midi) (MIT): the virtual MIDI port, via RtMidi.
- [Electron](https://github.com/electron/electron) (MIT), React, Vite, Tailwind CSS, Motion, Phosphor Icons, Geist.

The idea of turning a handful of buttons into a convincing performance owes a
debt to [Piano Genie](https://github.com/magenta/magenta-js) from Google
Magenta (Apache-2.0). Hamfist takes a rule-based route instead of a neural
one so that it can cover hundreds of styles, drive a whole band and stay
predictable enough to play.

## Honest limits

- The built-in sounds are synthesised, not sampled. They are meant for
  playing and sketching; for finished sound, send MIDI to your own instruments.
- Genres are recipes (scale, changes, groove, instrumentation), not
  machine-learned models of each style. Close cousins can sound alike.
- The macOS build and the virtual MIDI port are produced and exercised on
  macOS only by CI and by you; development here happened on Linux, where the
  same Electron app and engine were tested.

## License

MIT
