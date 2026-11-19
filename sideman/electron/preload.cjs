const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('sideman', {
  isDesktop: true,
  platform: process.platform,
  startDrag: (files) => ipcRenderer.send('drag-out', files),
  saveFile: (opts) => ipcRenderer.invoke('save-file', opts),
  saveFiles: (files) => ipcRenderer.invoke('save-files', files),
  openFile: (filters) => ipcRenderer.invoke('open-file', filters),
  onMenu: (cb) => ipcRenderer.on('menu', (_e, cmd) => cb(cmd)),
  onOpenFile: (cb) => ipcRenderer.on('file-opened', (_e, file) => cb(file)),
});
