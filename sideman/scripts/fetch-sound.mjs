// Puts the sampled-instrument preview in place:
//   public/sound/processor.js   the synth's audio worklet (copied from spessasynth_lib, Apache-2.0)
//   public/sound/gm.sf3         FluidR3Mono GM SoundFont (MIT), downloaded once and checked
// Both are build inputs, not source: they are git-ignored. If the download fails the app
// still builds and falls back to its built-in synth.
import { createHash } from 'node:crypto';
import { copyFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const out = join(root, 'public', 'sound');
mkdirSync(out, { recursive: true });

copyFileSync(join(root, 'node_modules', 'spessasynth_lib', 'dist', 'spessasynth_processor.min.js'), join(out, 'processor.js'));
console.log('worklet: copied');

const URL_SF = 'https://raw.githubusercontent.com/musescore/MuseScore/2.3.2/share/sound/FluidR3Mono_GM.sf3';
const SHA256 = process.env.SIDEMAN_SF_SHA256 ?? 'cfcd66d89e8386823400eca64934b14fbea7bf48ba1f00d21189af1262794ec2';
const dest = join(out, 'gm.sf3');
const sha = (buf) => createHash('sha256').update(buf).digest('hex');

if (existsSync(dest) && sha(readFileSync(dest)) === SHA256) {
  console.log('soundfont: already in place');
} else {
  try {
    const res = await fetch(URL_SF);
    if (!res.ok) throw new Error('HTTP ' + res.status);
    const buf = Buffer.from(await res.arrayBuffer());
    const got = sha(buf);
    if (got !== SHA256) throw new Error(`checksum mismatch: ${got}`);
    writeFileSync(dest, buf);
    console.log(`soundfont: downloaded ${(buf.length / 1e6).toFixed(1)} MB, sha256 ${got}`);
  } catch (err) {
    console.warn(`soundfont: not available (${err.message}). The app will use its built-in synth.`);
  }
}
