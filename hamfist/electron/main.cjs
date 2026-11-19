// Electron main process: window, MIDI permission, virtual MIDI port, file save.
const { app, BrowserWindow, dialog, ipcMain, nativeTheme, session, shell } = require("electron");
const fs = require("node:fs/promises");
const path = require("node:path");

const DEV = process.env.HAMFIST_DEV === "1";

// A key press is the whole point: sound must start without a click first.
app.commandLine.appendSwitch("autoplay-policy", "no-user-gesture-required");

let win = null;
let virtualOut = null;

/** Opens a CoreMIDI source named "Hamfist" that any DAW can record from. */
function openVirtualPort() {
  if (virtualOut) return true;
  try {
    const midi = require("@julusian/midi");
    const out = new midi.Output();
    out.openVirtualPort("Hamfist");
    virtualOut = out;
    return true;
  } catch (err) {
    console.warn("[hamfist] virtual MIDI port unavailable:", err && err.message);
    return false;
  }
}

function createWindow() {
  win = new BrowserWindow({
    width: 1320,
    height: 840,
    minWidth: 1100,
    minHeight: 680,
    show: false,
    title: "Hamfist",
    backgroundColor: nativeTheme.shouldUseDarkColors ? "#0b0b0d" : "#ededef",
    titleBarStyle: process.platform === "darwin" ? "hiddenInset" : "default",
    trafficLightPosition: { x: 18, y: 22 },
    webPreferences: {
      preload: path.join(__dirname, "preload.cjs"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false,
      // The sequencer clock must keep running when the window is behind a DAW.
      backgroundThrottling: false,
    },
  });
  win.once("ready-to-show", () => win.show());
  win.webContents.setWindowOpenHandler(({ url }) => {
    if (/^https:\/\//.test(url)) shell.openExternal(url);
    return { action: "deny" };
  });
  if (DEV) win.loadURL("http://localhost:5173");
  else win.loadFile(path.join(__dirname, "..", "dist", "index.html"));
  win.on("closed", () => (win = null));
}

app.whenReady().then(() => {
  const allowed = new Set(["midi", "midiSysex"]);
  session.defaultSession.setPermissionRequestHandler((_wc, permission, cb) => cb(allowed.has(permission)));
  session.defaultSession.setPermissionCheckHandler((_wc, permission) => allowed.has(permission));

  ipcMain.handle("midi:virtual", () => openVirtualPort());

  // Events arrive slightly ahead of time with a wall-clock timestamp.
  ipcMain.on("midi:send", (_e, bytes, atEpochMs) => {
    if (!virtualOut || !Array.isArray(bytes)) return;
    const delay = atEpochMs - Date.now();
    const fire = () => {
      try {
        virtualOut.sendMessage(bytes);
      } catch {
        /* port closed */
      }
    };
    if (delay > 1) setTimeout(fire, delay);
    else fire();
  });

  ipcMain.handle("file:save-midi", async (_e, name, bytes) => {
    const res = await dialog.showSaveDialog(win, {
      title: "Save MIDI",
      defaultPath: path.join(app.getPath("music"), String(name).replace(/[/\\:]/g, "-")),
      filters: [{ name: "MIDI file", extensions: ["mid"] }],
    });
    if (res.canceled || !res.filePath) return null;
    await fs.writeFile(res.filePath, Buffer.from(bytes));
    return res.filePath;
  });

  createWindow();
  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on("window-all-closed", () => {
  try {
    virtualOut && virtualOut.closePort();
  } catch {
    /* ignore */
  }
  app.quit();
});
