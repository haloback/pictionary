// Sampled-instrument preview: a SoundFont synthesizer (spessasynth_lib) playing
// a General MIDI sound bank. It is fed the same channel messages a MIDI file
// would contain, so what you hear is the exported performance: velocities,
// expression, vibrato, pitch bends, sustain pedal and program changes.

import { WorkletSynthesizer } from 'spessasynth_lib';

function load(url: string): Promise<ArrayBuffer> {
  // XMLHttpRequest rather than fetch: it also reads local files inside the packaged app
  return new Promise((resolve, reject) => {
    const x = new XMLHttpRequest();
    x.open('GET', url);
    x.responseType = 'arraybuffer';
    x.onload = () => (x.status === 0 || (x.status >= 200 && x.status < 300)) && x.response && (x.response as ArrayBuffer).byteLength > 1000 ? resolve(x.response as ArrayBuffer) : reject(new Error('Sound bank not found'));
    x.onerror = () => reject(new Error('Sound bank not found'));
    x.send();
  });
}

export class SfSynth {
  ready = false;
  failed = false;
  private synth: WorkletSynthesizer | null = null;
  private out: GainNode | null = null;
  private loading: Promise<boolean> | null = null;

  /** Load the worklet and the sound bank. Resolves false if either is missing. */
  init(ctx: AudioContext, destination: AudioNode): Promise<boolean> {
    if (this.loading) return this.loading;
    this.loading = (async () => {
      try {
        const base = new URL('./sound/', document.baseURI);
        const [bank] = await Promise.all([load(new URL('gm.sf3', base).href), ctx.audioWorklet.addModule(new URL('processor.js', base).href)]);
        const synth = new WorkletSynthesizer(ctx);
        this.out = ctx.createGain();
        this.out.gain.value = 2.2;
        synth.connect(this.out);
        this.out.connect(destination);
        await synth.soundBankManager.addSoundBank(bank, 'gm');
        await synth.isReady;
        this.synth = synth;
        this.ready = true;
        return true;
      } catch (err) {
        console.warn('Sampled instruments unavailable, using the built-in synth:', err);
        this.failed = true;
        return false;
      }
    })();
    return this.loading;
  }

  /** Send one channel message, scheduled at an AudioContext time. */
  send(bytes: number[], when: number): void {
    this.synth?.sendMessage(bytes, 0, { time: when });
  }
  now(bytes: number[]): void {
    this.synth?.sendMessage(bytes);
  }
  silence(): void {
    this.synth?.stopAll(true);
  }
}
