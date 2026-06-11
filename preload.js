const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('ToekanShell', {
  quit: () => ipcRenderer.send('toekan:quit')
});
