const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("hamfist", {
  platform: process.platform,
  virtualMidi: () => ipcRenderer.invoke("midi:virtual"),
  midiSend: (bytes, atEpochMs) => ipcRenderer.send("midi:send", bytes, atEpochMs),
  saveMidi: (name, bytes) => ipcRenderer.invoke("file:save-midi", name, bytes),
});
