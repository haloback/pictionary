import { useEffect, useState } from 'react';
import { FileArrowDown } from '@phosphor-icons/react';
import { useApp } from './store';
import { SongBar, Toolbar } from './Header';
import { Tracks } from './Tracks';
import { Inspector } from './Inspector';
import { desktop } from '../platform';

function isTyping(el: EventTarget | null): boolean {
  const e = el as HTMLElement | null;
  if (!e || !e.tagName) return false;
  if (e.tagName === 'TEXTAREA' || e.tagName === 'SELECT' || e.isContentEditable) return true;
  return e.tagName === 'INPUT' && (e as HTMLInputElement).type !== 'range' && (e as HTMLInputElement).type !== 'checkbox';
}

let shellBound = false;

export function App() {
  const theme = useApp((s) => s.theme);
  const toast = useApp((s) => s.toast);
  const [dropping, setDropping] = useState(false);

  useEffect(() => {
    if (theme === 'auto') delete document.documentElement.dataset.theme;
    else document.documentElement.dataset.theme = theme;
  }, [theme]);

  // keyboard shortcuts
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const s = useApp.getState();
      const mod = e.metaKey || e.ctrlKey;
      const typing = isTyping(e.target);
      // in the desktop app the native menu owns the modifier shortcuts
      if (desktop && mod) return;
      if (mod && e.key.toLowerCase() === 'z' && !typing) {
        e.preventDefault();
        if (e.shiftKey) s.redo();
        else s.undo();
      } else if (mod && e.key.toLowerCase() === 's') {
        e.preventDefault();
        void s.saveSession();
      } else if (mod && e.key.toLowerCase() === 'e') {
        e.preventDefault();
        void s.exportAll();
      } else if (mod && e.key.toLowerCase() === 'o') {
        e.preventDefault();
        void s.openDialog();
      } else if (!mod && !typing && e.code === 'Space') {
        e.preventDefault();
        s.togglePlay();
      } else if (!mod && !typing && e.key.toLowerCase() === 'r') {
        e.preventDefault();
        s.randomizeAll();
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  // menu commands from the desktop shell (bound once, even under StrictMode)
  useEffect(() => {
    if (shellBound) return;
    shellBound = true;
    desktop?.onMenu((cmd) => {
      const s = useApp.getState();
      const typing = isTyping(document.activeElement);
      if (cmd === 'undo') typing ? document.execCommand('undo') : s.undo();
      else if (cmd === 'redo') typing ? document.execCommand('redo') : s.redo();
      else if (cmd === 'new') s.newSession();
      else if (cmd === 'open') void s.openDialog();
      else if (cmd === 'save') void s.saveSession();
      else if (cmd === 'export') void s.exportAll();
      else if (cmd === 'stems') void s.exportStems();
      else if (cmd === 'randomize') s.randomizeAll();
      else if (cmd === 'play') s.togglePlay();
    });
    desktop?.onOpenFile((f) => useApp.getState().importFile(f.name, f.data));
  }, []);

  // drop files anywhere: MIDI (read its chords), a chord chart, or a session
  useEffect(() => {
    let depth = 0;
    const hasFiles = (e: DragEvent) => !!e.dataTransfer && Array.from(e.dataTransfer.types).includes('Files');
    const over = (e: DragEvent) => {
      if (hasFiles(e)) e.preventDefault();
    };
    const enter = (e: DragEvent) => {
      if (!hasFiles(e)) return;
      depth++;
      setDropping(true);
    };
    const leave = (e: DragEvent) => {
      if (!hasFiles(e)) return;
      depth = Math.max(0, depth - 1);
      if (!depth) setDropping(false);
    };
    const drop = async (e: DragEvent) => {
      if (!hasFiles(e)) return;
      e.preventDefault();
      depth = 0;
      setDropping(false);
      const f = e.dataTransfer?.files?.[0];
      if (f) useApp.getState().importFile(f.name, new Uint8Array(await f.arrayBuffer()));
    };
    window.addEventListener('dragover', over);
    window.addEventListener('dragenter', enter);
    window.addEventListener('dragleave', leave);
    window.addEventListener('drop', drop);
    return () => {
      window.removeEventListener('dragover', over);
      window.removeEventListener('dragenter', enter);
      window.removeEventListener('dragleave', leave);
      window.removeEventListener('drop', drop);
    };
  }, []);

  return (
    <div className="app">
      <Toolbar />
      <SongBar />
      <main className="workspace">
        <Tracks />
        <Inspector />
      </main>
      {dropping && (
        <div className="drop-overlay" aria-hidden="true">
          <div>
            <FileArrowDown size={34} />
            <strong>Drop to load</strong>
            <p>A MIDI file to read its chords, a text chord chart, or a Sideman session.</p>
          </div>
        </div>
      )}
      <div className="toast-zone" aria-live="polite">
        {toast && (
          <div className="toast" key={toast.id}>
            {toast.msg}
          </div>
        )}
      </div>
    </div>
  );
}
