// Sideman desktop shell: window, native menus, file dialogs and real file
// drags (so parts can be dropped straight into a DAW or Finder).

const { app, BrowserWindow, Menu, dialog, ipcMain, nativeImage, session, shell } = require('electron');
const path = require('path');
const fs = require('fs');

const DEV = !!process.env.SIDEMAN_DEV;
const isMac = process.platform === 'darwin';
let win = null;
let pendingFile = null;

function safeName(name, fallback) {
  const base = path.basename(String(name || fallback)).replace(/[^\w.\- ]+/g, '_');
  return base || fallback;
}
function toBuffer(data) {
  return Buffer.from(data.buffer ? new Uint8Array(data.buffer, data.byteOffset, data.byteLength) : data);
}

function createWindow() {
  win = new BrowserWindow({
    width: 1440,
    height: 900,
    minWidth: 900,
    minHeight: 600,
    show: false,
    title: 'Sideman',
    backgroundColor: '#101113',
    titleBarStyle: isMac ? 'hiddenInset' : 'default',
    trafficLightPosition: { x: 18, y: 18 },
    webPreferences: {
      preload: path.join(__dirname, 'preload.cjs'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });
  win.once('ready-to-show', () => win.show());
  if (DEV) win.loadURL('http://localhost:5173');
  else win.loadFile(path.join(__dirname, '..', 'dist', 'index.html'));

  // never navigate away from the app; open outside links in the browser
  win.webContents.setWindowOpenHandler(({ url }) => {
    if (/^https?:/.test(url)) shell.openExternal(url);
    return { action: 'deny' };
  });
  win.webContents.on('will-navigate', (e, url) => {
    if (!DEV || !url.startsWith('http://localhost:5173')) e.preventDefault();
  });
  win.webContents.on('did-finish-load', () => {
    if (pendingFile) {
      sendFile(pendingFile);
      pendingFile = null;
    }
  });
  win.on('closed', () => (win = null));
}

function sendFile(filePath) {
  try {
    const data = fs.readFileSync(filePath);
    if (data.length > 20 * 1024 * 1024) return;
    win?.webContents.send('file-opened', { name: path.basename(filePath), data: new Uint8Array(data) });
  } catch {
    /* unreadable file: ignore */
  }
}

function send(cmd) {
  win?.webContents.send('menu', cmd);
}

function buildMenu() {
  const template = [
    ...(isMac
      ? [
          {
            label: app.name,
            submenu: [{ role: 'about' }, { type: 'separator' }, { role: 'services' }, { type: 'separator' }, { role: 'hide' }, { role: 'hideOthers' }, { role: 'unhide' }, { type: 'separator' }, { role: 'quit' }],
          },
        ]
      : []),
    {
      label: 'File',
      submenu: [
        { label: 'New Session', accelerator: 'CmdOrCtrl+N', click: () => send('new') },
        { label: 'Open…', accelerator: 'CmdOrCtrl+O', click: () => send('open') },
        { type: 'separator' },
        { label: 'Save Session…', accelerator: 'CmdOrCtrl+S', click: () => send('save') },
        { type: 'separator' },
        { label: 'Export MIDI File…', accelerator: 'CmdOrCtrl+E', click: () => send('export') },
        { label: 'Export Each Part…', accelerator: 'Shift+CmdOrCtrl+E', click: () => send('stems') },
        ...(isMac ? [] : [{ type: 'separator' }, { role: 'quit' }]),
      ],
    },
    {
      label: 'Edit',
      submenu: [
        { label: 'Undo', accelerator: 'CmdOrCtrl+Z', click: () => send('undo') },
        { label: 'Redo', accelerator: 'Shift+CmdOrCtrl+Z', click: () => send('redo') },
        { type: 'separator' },
        { role: 'cut' },
        { role: 'copy' },
        { role: 'paste' },
        { role: 'selectAll' },
      ],
    },
    {
      label: 'Band',
      submenu: [
        { label: 'Play / Stop', click: () => send('play') },
        { label: 'Randomize Band', accelerator: 'CmdOrCtrl+R', click: () => send('randomize') },
      ],
    },
    {
      label: 'View',
      submenu: [{ role: 'togglefullscreen' }, ...(DEV ? [{ type: 'separator' }, { role: 'toggleDevTools' }, { role: 'forceReload' }] : [])],
    },
    { role: 'windowMenu' },
  ];
  Menu.setApplicationMenu(Menu.buildFromTemplate(template));
}

// ---- IPC

// Real OS-level drag: write the MIDI to a temp folder, then hand the files to the system.
ipcMain.on('drag-out', (event, files) => {
  try {
    if (!Array.isArray(files) || !files.length || files.length > 32) return;
    const dir = path.join(app.getPath('temp'), 'sideman-drag');
    fs.mkdirSync(dir, { recursive: true });
    const paths = files.map((f, i) => {
      let name = safeName(f.name, `part-${i + 1}.mid`);
      if (!/\.mid$/i.test(name)) name += '.mid';
      const p = path.join(dir, name);
      fs.writeFileSync(p, toBuffer(f.data));
      return p;
    });
    const icon = nativeImage.createFromPath(path.join(__dirname, 'drag.png'));
    event.sender.startDrag(paths.length > 1 ? { file: paths[0], files: paths, icon } : { file: paths[0], icon });
  } catch (err) {
    console.error('drag failed', err);
  }
});

ipcMain.handle('save-file', async (_e, opts) => {
  const res = await dialog.showSaveDialog(win, { defaultPath: safeName(opts.name, 'sideman.mid'), filters: opts.filters });
  if (res.canceled || !res.filePath) return null;
  fs.writeFileSync(res.filePath, toBuffer(opts.data));
  return res.filePath;
});

ipcMain.handle('save-files', async (_e, files) => {
  const res = await dialog.showOpenDialog(win, { title: 'Choose a folder for the part files', properties: ['openDirectory', 'createDirectory'], buttonLabel: 'Save Here' });
  if (res.canceled || !res.filePaths[0]) return null;
  for (const f of files) fs.writeFileSync(path.join(res.filePaths[0], safeName(f.name, 'part.mid')), toBuffer(f.data));
  return res.filePaths[0];
});

ipcMain.handle('open-file', async (_e, filters) => {
  const res = await dialog.showOpenDialog(win, { properties: ['openFile'], filters });
  if (res.canceled || !res.filePaths[0]) return null;
  const data = fs.readFileSync(res.filePaths[0]);
  return { name: path.basename(res.filePaths[0]), data: new Uint8Array(data) };
});

// ---- lifecycle

app.on('open-file', (e, filePath) => {
  e.preventDefault();
  if (win && !win.webContents.isLoading()) sendFile(filePath);
  else pendingFile = filePath;
});

app.whenReady().then(() => {
  // live MIDI output to hardware and virtual ports (IAC etc.)
  session.defaultSession.setPermissionRequestHandler((_wc, permission, cb) => cb(permission === 'midi' || permission === 'midiSysex'));
  session.defaultSession.setPermissionCheckHandler((_wc, permission) => permission === 'midi' || permission === 'midiSysex');
  buildMenu();
  createWindow();
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (!isMac) app.quit();
});
