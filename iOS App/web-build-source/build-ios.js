/* Assembles the iOS build from the desktop app.
   The desktop CSS and the entire game script are carried over verbatim;
   only the <head>, the body shell, and an appended style/script differ. */
const fs = require('fs');
const path = require('path');

// Resolved relative to this script (…/iOS App/web-build-source) so the project can be moved.
const SRC = path.join(__dirname, '..', '..', 'solo-leveling-system-v2.html');
const OUT = process.argv[2];
// --artifact emits body-level content only, for hosts that supply their own
// document skeleton. The install <meta> tags are re-declared into <head> at
// runtime by the shell, so Add to Home Screen still works in that mode.
const ARTIFACT = process.argv.includes('--artifact');
const HERE = __dirname;

const lines = fs.readFileSync(SRC, 'utf8').split(/\r?\n/);
// 1-indexed, inclusive slice of the source file.
const L = (a, b) => lines.slice(a - 1, b).join('\n');

/* --- Structural landmarks, asserted so a future edit to the desktop app
       fails loudly here instead of producing a silently broken build. --- */
const expect = (lineNo, needle) => {
  if (!lines[lineNo - 1].includes(needle)) {
    throw new Error(`Landmark moved: line ${lineNo} should contain "${needle}" but is:\n  ${lines[lineNo - 1]}`);
  }
};
expect(10, '<style>');
expect(1107, '</style>');
expect(1109, '<body>');
expect(1393, '<script>');
expect(4106, '</script>');

const DESKTOP_CSS = L(11, 1106);      // inside <style>…</style>
const GAME_SCRIPT = L(1394, 4105);    // inside <script>…</script>, the IIFE

/* Panel chunks, lifted whole out of the desktop body. */
const P = {
  bgLayers:    L(1111, 1115),
  profile:     L(1120, 1145),
  stats:       L(1148, 1154),
  hiddenQuest: L(1157, 1160),
  dailyWeekly: L(1162, 1210),
  mainQuests:  L(1213, 1223),
  boss:        L(1226, 1236),
  shop:        L(1239, 1253),
  apothecary:  L(1256, 1265),
  skills:      L(1268, 1273),
  titles:      L(1276, 1280),
  achievements:L(1283, 1286),
  armor:       L(1289, 1360),
  footer:      L(1362, 1362),
  // 1365 is the notification container, which the shell re-declares itself —
  // starting at 1367 keeps that id unique.
  overlays:    L(1367, 1391),
};

// Sanity-check each chunk really is the panel we think it is.
const chunkMustContain = {
  profile: 'profilePanel', stats: 'statsGrid', hiddenQuest: 'hiddenQuestPanel',
  dailyWeekly: 'weeklyList', mainQuests: 'mainList', boss: 'bossList',
  shop: 'shopGrid', apothecary: 'consGrid', skills: 'skillGrid',
  titles: 'titleGrid', achievements: 'achGrid', armor: 'equipColRight',
  footer: '</footer>', overlays: 'hqAcceptBtn',
};
if (P.overlays.includes('notification-container')) {
  throw new Error('overlays chunk still contains notification-container — id would be duplicated.');
}
if (!P.overlays.includes('levelup-overlay')) {
  throw new Error('overlays chunk lost the level-up overlay.');
}
for (const [k, needle] of Object.entries(chunkMustContain)) {
  if (!P[k].includes(needle)) throw new Error(`Chunk "${k}" is missing "${needle}" — line ranges are stale.`);
}

const MOBILE_CSS = fs.readFileSync(path.join(HERE, 'mobile.css'), 'utf8');
const SHELL_JS   = fs.readFileSync(path.join(HERE, 'mobile-shell.js'), 'utf8');
const ICON_B64   = fs.readFileSync(path.join(HERE, 'icon.b64'), 'utf8').trim();
const ICON_URI   = 'data:image/png;base64,' + ICON_B64;

/* ---------------- Tab bar ---------------- */

const ico = {
  status: '<path d="M12 2.6 3.6 6.4v5.3c0 5.2 3.6 9.4 8.4 10.7 4.8-1.3 8.4-5.5 8.4-10.7V6.4z"/>',
  quests: '<path d="M4.5 3h11.2L19.5 6.8V21H4.5z"/><path d="M8 11.5l2.3 2.3L16 8.6"/>',
  shop:   '<path d="M4 8h16l-1.3 12.5H5.3z"/><path d="M8.6 8V6.2a3.4 3.4 0 0 1 6.8 0V8"/>',
  power:  '<path d="M13.3 2.5 4.8 13.4h5.6l-.7 8.1 8.5-10.9h-5.6z"/>',
  feats:  '<circle cx="12" cy="9.2" r="6"/><path d="M8.4 14.4 7 22l5-2.8L17 22l-1.4-7.6"/>',
};
const svg = d => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;

const TABS = [
  ['status', 'STATUS'],
  ['quests', 'QUESTS'],
  ['shop',   'SHOP'],
  ['power',  'POWER'],
  ['feats',  'FEATS'],
];
const tabbar = TABS.map(([id, label]) =>
  `    <button class="ios-tab" data-tab="${id}" type="button" aria-label="${label}">` +
  `<span class="ios-tab-dot"></span>${svg(ico[id])}<span>${label}</span></button>`
).join('\n');

/* ---------------- Page composition ---------------- */

const page = (id, body) => `  <div class="ios-page" data-page="${id}">\n${body}\n  </div>`;

const transferPanel = `
  <div class="system-panel">
    <div class="panel-title">SAVE TRANSFER</div>
    <div class="treasury-note" style="margin:-2px 0 12px;">Move progress between this phone and the desktop System.</div>
    <button class="data-btn" id="iosTransferBtn" style="width:100%;min-height:46px;">⇅ TRANSFER SAVE DATA</button>
  </div>`;

const installHint = `
  <div class="system-panel" id="iosInstallHint" style="display:none;border-color:rgba(255,207,77,0.45);">
    <div class="panel-title" style="color:var(--gold);">INSTALL TO HOME SCREEN</div>
    <div class="treasury-note" style="margin:-2px 0 10px;line-height:1.7;">
      Tap <b>Share</b> (the box with the arrow) at the bottom of Safari, then
      <b>Add to Home Screen</b>. The System then opens fullscreen, with no browser bars,
      and keeps working offline.
    </div>
    <button class="data-btn" id="iosHintDismiss" style="width:100%;min-height:44px;">GOT IT</button>
  </div>`;

const pages = [
  page('status', [installHint, P.hiddenQuest, P.profile, P.stats, transferPanel].join('\n')),
  page('quests', [P.dailyWeekly, P.mainQuests, P.boss].join('\n')),
  page('shop',   [P.shop, P.apothecary].join('\n')),
  page('power',  [P.skills, P.titles, P.armor].join('\n')),
  page('feats',  [P.achievements].join('\n')),
].join('\n\n');

/* ---------------- Save-transfer sheet ---------------- */

const sheet = `
<div class="ios-sheet" id="iosSheet">
  <div class="ios-sheet-panel">
    <div class="ios-sheet-title">SAVE TRANSFER</div>
    <div class="ios-sheet-note">
      <b>Desktop → phone.</b> On your PC, click <b>⇩ EXPORT SAVE</b>.<br>
      <i>Easiest:</i> drop that .json in iCloud Drive, then use <b>⇧ IMPORT SAVE</b> on the
      STATUS tab and pick the file.<br>
      <i>Or:</i> open the .json, copy all of it, paste below, and tap LOAD PASTED SAVE.<br><br>
      <b>Phone → desktop.</b> Tap COPY THIS DEVICE'S SAVE, send it to yourself, and use
      ⇧ IMPORT SAVE on the PC.<br><br>
      Whichever save you load replaces the one on this device — the old one is backed up first.
    </div>
    <textarea id="iosPasteBox" placeholder="Paste save data here…" spellcheck="false"
              autocapitalize="off" autocorrect="off"></textarea>
    <div class="ios-sheet-row">
      <button class="data-btn" id="iosCopyBtn" type="button">⧉ COPY THIS DEVICE'S SAVE</button>
      <button class="btn-glow" id="iosLoadBtn" type="button">⇩ LOAD PASTED SAVE</button>
    </div>
    <button class="data-btn ios-sheet-close" id="iosSheetClose" type="button">CLOSE</button>
  </div>
</div>`;

/* ---------------- Boot-time import bootstrap ----------------
   Must run before the game script, which reads the save immediately and
   installs pagehide/beforeunload handlers that write its in-memory state
   back out. Staging + applying here is what makes an import survive. */

const BOOTSTRAP = `<script>
(function(){
  var KEY  = 'soloLevelingLifeTracker_v2';
  var PEND = KEY + '_pending_import';
  var raw;
  try{ raw = localStorage.getItem(PEND); }catch(e){ return; }
  if(!raw) return;
  // Clear the staged copy first, so a value that somehow fails below can
  // never wedge the app in a reload loop.
  try{ localStorage.removeItem(PEND); }catch(e){}
  try{
    var parsed = JSON.parse(raw);
    if(!parsed || typeof parsed !== 'object' || !parsed.player || !parsed.dailyQuests) return;
    var cur = localStorage.getItem(KEY);
    if(cur) localStorage.setItem(KEY + '_ios_import_backup', cur);
    localStorage.setItem(KEY, raw);
  }catch(e){}
})();
<\/script>`;

/* ---------------- Final document ---------------- */

const HEAD_OPEN = ARTIFACT ? `<title>THE SYSTEM</title>
${BOOTSTRAP}
<link rel="apple-touch-icon" href="${ICON_URI}">
` : `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
${BOOTSTRAP}
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
<title>THE SYSTEM</title>
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="THE SYSTEM">
<meta name="theme-color" content="#05050a">
<meta name="color-scheme" content="dark">
<link rel="apple-touch-icon" href="${ICON_URI}">
<link rel="icon" type="image/png" href="${ICON_URI}">
`;

const HEAD_CLOSE = ARTIFACT ? '' : '</head>\n<body>';
const DOC_CLOSE  = ARTIFACT ? '' : '</body>\n</html>';

const html = `${HEAD_OPEN}<style>
${DESKTOP_CSS}
</style>
<style>
${MOBILE_CSS}
</style>
${HEAD_CLOSE}

${P.bgLayers}

<div class="ios-topbar">
  <div class="ios-topbar-inner">
    <span class="ios-tb-lv" id="tbLevel">LV. 1</span>
    <div class="ios-tb-mid">
      <div class="ios-tb-name" id="tbName">HUNTER</div>
      <div class="ios-tb-xpbar"><div class="ios-tb-xpfill" id="tbXpFill"></div></div>
    </div>
    <span class="ios-tb-gold" id="tbGold">0 G</span>
    <span class="ios-tb-rank" id="tbRank">E-RANK</span>
  </div>
</div>

<div class="app-container">

${pages}

${P.footer}

</div>

<nav class="ios-tabbar">
${tabbar}
</nav>

${sheet}

<div id="notification-container"></div>

${P.overlays}

<script>
${GAME_SCRIPT}
</script>

<script>
${SHELL_JS}
</script>
${DOC_CLOSE}
`;

fs.writeFileSync(OUT, html, 'utf8');
console.log('Wrote ' + OUT);
console.log('  size: ' + (Buffer.byteLength(html) / 1024).toFixed(0) + ' KB');
console.log('  lines: ' + html.split('\n').length);
