'use strict';
// Bridges the app's localStorage save to a real file on disk (<userData>\save.json).
// Runs before any page script, so the seed happens before the app boots.

const { ipcRenderer } = require('electron');
const fs = require('fs');
const path = require('path');

const STORAGE_KEY = 'soloLevelingLifeTracker_v2';

const userDataPath = ipcRenderer.sendSync('get-user-data-path');
const savePath = path.join(userDataPath, 'save.json');

let lastWritten = null;

// 1. Seed localStorage from disk (synchronously, before page scripts run).
try {
  if (fs.existsSync(savePath)) {
    const contents = fs.readFileSync(savePath, 'utf8');
    window.localStorage.setItem(STORAGE_KEY, contents);
    lastWritten = contents;
  }
} catch (err) {
  console.error('Failed to seed save from disk:', err);
}

// 2. Mirror localStorage back to disk, atomically, when it changes.
function writeIfChanged() {
  try {
    const current = window.localStorage.getItem(STORAGE_KEY);
    if (current === null || current === lastWritten) return;
    const tmp = savePath + '.tmp';
    fs.writeFileSync(tmp, current, 'utf8');
    fs.renameSync(tmp, savePath);
    lastWritten = current;
  } catch (err) {
    console.error('Failed to write save to disk:', err);
  }
}

setInterval(writeIfChanged, 5000);
window.addEventListener('beforeunload', writeIfChanged);
