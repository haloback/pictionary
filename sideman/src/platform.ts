// Bridge to the desktop shell (Electron). Everything has a browser fallback so
// the same build runs with `npm run dev`.

interface DragFile {
  name: string;
  data: Uint8Array;
}
interface Bridge {
  isDesktop: true;
  platform: string;
  startDrag(files: DragFile[]): void;
  saveFile(opts: { name: string; data: Uint8Array; filters: { name: string; extensions: string[] }[] }): Promise<string | null>;
  saveFiles(files: DragFile[]): Promise<string | null>;
  openFile(filters: { name: string; extensions: string[] }[]): Promise<{ name: string; data: Uint8Array } | null>;
  onMenu(cb: (cmd: string) => void): void;
  onOpenFile(cb: (file: { name: string; data: Uint8Array }) => void): void;
}
declare global {
  interface Window {
    sideman?: Bridge;
  }
}

export const desktop = typeof window !== 'undefined' ? window.sideman : undefined;
export const isMac = typeof navigator !== 'undefined' && /Mac/i.test(navigator.platform || navigator.userAgent);

function toBase64(data: Uint8Array): string {
  let s = '';
  for (let i = 0; i < data.length; i++) s += String.fromCharCode(data[i]);
  return btoa(s);
}

/**
 * Start dragging MIDI files out of the app. In the desktop app this is a real
 * file drag that any DAW or Finder accepts; in a browser it falls back to the
 * Chromium "DownloadURL" drag, which works for one file onto the desktop.
 */
export function dragOut(e: React.DragEvent, files: DragFile[]): void {
  if (!files.length) {
    e.preventDefault();
    return;
  }
  if (desktop) {
    e.preventDefault();
    desktop.startDrag(files);
    return;
  }
  const f = files[0];
  e.dataTransfer.effectAllowed = 'copy';
  e.dataTransfer.setData('DownloadURL', `audio/midi:${f.name}:data:audio/midi;base64,${toBase64(f.data)}`);
  e.dataTransfer.setData('text/plain', f.name);
}

export function download(name: string, data: Uint8Array | string, mime: string): void {
  const blob = new Blob([data as BlobPart], { type: mime });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = name;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 2000);
}

export async function saveMidi(name: string, data: Uint8Array): Promise<string | null> {
  if (desktop) return desktop.saveFile({ name, data, filters: [{ name: 'MIDI file', extensions: ['mid'] }] });
  download(name, data, 'audio/midi');
  return name;
}

/** Save several files into a folder the user picks (desktop), or download them one by one. */
export async function saveMany(files: DragFile[]): Promise<string | null> {
  if (desktop) return desktop.saveFiles(files);
  files.forEach((f, i) => setTimeout(() => download(f.name, f.data, 'audio/midi'), i * 150));
  return 'Downloads';
}

export async function saveProject(name: string, json: string): Promise<string | null> {
  const data = new TextEncoder().encode(json);
  if (desktop) return desktop.saveFile({ name, data, filters: [{ name: 'Sideman session', extensions: ['sideman'] }] });
  download(name, json, 'application/json');
  return name;
}

export async function openFile(): Promise<{ name: string; data: Uint8Array } | null> {
  if (desktop) return desktop.openFile([{ name: 'Sessions, MIDI and chord charts', extensions: ['sideman', 'mid', 'midi', 'txt'] }]);
  return new Promise((resolve) => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = '.sideman,.mid,.midi,.txt,.json';
    input.onchange = async () => {
      const f = input.files?.[0];
      if (!f) return resolve(null);
      resolve({ name: f.name, data: new Uint8Array(await f.arrayBuffer()) });
    };
    input.click();
  });
}
