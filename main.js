const { app, BrowserWindow, Menu, ipcMain } = require('electron');
const path = require('path');

function createWindow() {
  const win = new BrowserWindow({
    width: 1280,
    height: 800,
    minWidth: 960,
    minHeight: 640,
    backgroundColor: '#0a0a1a',
    title: 'Toe-Kan Clicker',
    show: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true
    }
  });

  Menu.setApplicationMenu(null);
  win.once('ready-to-show', () => {
    win.show();
    const smokeQuitMs = Number.parseInt(process.env.TOEKAN_SMOKE_QUIT_MS || '', 10);
    if (Number.isFinite(smokeQuitMs) && smokeQuitMs > 0) {
      setTimeout(() => app.quit(), smokeQuitMs);
    }
  });
  win.loadFile(path.join(__dirname, 'fireworks.html'));
}

app.whenReady().then(createWindow);

ipcMain.on('toekan:quit', () => app.quit());

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) createWindow();
});
