'use strict';
const { app, BrowserWindow, dialog, ipcMain } = require('electron');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { repair } = require('./repair');

let userDataPath;
let savePath;

function atomicWrite(filePath, contents) {
  const tmp = filePath + '.tmp';
  fs.writeFileSync(tmp, contents, 'utf8');
  fs.renameSync(tmp, filePath);
}

// First-run: offer to import an existing exported save before the window opens.
function firstRunFlow() {
  for (;;) {
    const choice = dialog.showMessageBoxSync({
      type: 'question',
      title: 'THE SYSTEM',
      message: 'Import your existing progress?',
      detail: 'If you exported a save from the browser version, import it now. Otherwise start fresh.',
      buttons: ['Import save file', 'Start fresh'],
      defaultId: 0,
      cancelId: 1
    });
    if (choice !== 0) return; // Start fresh: no save.json, app boots clean

    const picked = dialog.showOpenDialogSync({
      title: 'Select your exported save',
      defaultPath: path.join(os.homedir(), 'Downloads'),
      filters: [{ name: 'Save files', extensions: ['json'] }],
      properties: ['openFile']
    });
    if (!picked || picked.length === 0) continue; // back to first dialog

    let raw, state;
    try {
      raw = fs.readFileSync(picked[0], 'utf8');
      state = JSON.parse(raw);
    } catch (err) {
      dialog.showMessageBoxSync({
        type: 'error',
        title: 'THE SYSTEM',
        message: 'Could not read that file as a save.',
        detail: String(err.message || err)
      });
      continue;
    }

    let result;
    try {
      result = repair(state);
    } catch (err) {
      // Repair itself failed - offer plain import.
      const fallback = dialog.showMessageBoxSync({
        type: 'warning',
        title: 'THE SYSTEM',
        message: 'Repair check failed - import the file as-is?',
        detail: String(err.message || err),
        buttons: ['Import as-is', 'Cancel'],
        defaultId: 0,
        cancelId: 1
      });
      if (fallback === 0) {
        atomicWrite(savePath, raw);
        return;
      }
      continue;
    }

    const action = dialog.showMessageBoxSync({
      type: 'info',
      title: 'THE SYSTEM - Save repair',
      message: 'Repair summary',
      detail: result.summaryLines.join('\n'),
      buttons: ['Apply', 'Import without repair', 'Cancel'],
      defaultId: 0,
      cancelId: 2
    });
    if (action === 0) {
      atomicWrite(savePath, JSON.stringify(result.repairedState));
      return;
    }
    if (action === 1) {
      atomicWrite(savePath, raw);
      return;
    }
    // Cancel: back to first dialog
  }
}

// Daily rolling backups: one per day, keep newest 14.
function runBackups() {
  try {
    if (!fs.existsSync(savePath)) return;
    const backupDir = path.join(userDataPath, 'backups');
    fs.mkdirSync(backupDir, { recursive: true });
    const now = new Date();
    const today = now.getFullYear() + '-' +
      String(now.getMonth() + 1).padStart(2, '0') + '-' +
      String(now.getDate()).padStart(2, '0');
    const todayFile = path.join(backupDir, 'save-' + today + '.json');
    if (!fs.existsSync(todayFile)) {
      fs.copyFileSync(savePath, todayFile);
    }
    const backups = fs.readdirSync(backupDir)
      .filter((f) => /^save-\d{4}-\d{2}-\d{2}\.json$/.test(f))
      .sort()
      .reverse(); // newest first (date-named, so lexical sort works)
    for (const old of backups.slice(14)) {
      fs.unlinkSync(path.join(backupDir, old));
    }
  } catch (err) {
    console.error('Backup step failed:', err);
  }
}

function createWindow() {
  const win = new BrowserWindow({
    width: 1280,
    height: 800,
    minWidth: 1000,
    minHeight: 700,
    backgroundColor: '#0a0e1a',
    title: 'THE SYSTEM — Solo Leveling',
    autoHideMenuBar: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      sandbox: false,
      contextIsolation: false,
      nodeIntegration: false
    }
  });
  win.loadFile(path.join(__dirname, 'app', 'index.html'));
}

app.whenReady().then(() => {
  userDataPath = app.getPath('userData');
  savePath = path.join(userDataPath, 'save.json');

  ipcMain.on('get-user-data-path', (event) => {
    event.returnValue = userDataPath;
  });

  if (!fs.existsSync(savePath) && !process.env.SL_SMOKE_TEST) {
    firstRunFlow();
  }
  runBackups();
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  app.quit();
});
