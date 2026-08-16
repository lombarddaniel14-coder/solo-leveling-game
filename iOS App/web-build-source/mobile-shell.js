/* ============================================================
   iOS shell — runs after the original script. It only reads the
   DOM the original renders and writes to localStorage through the
   same key, so the game logic above is untouched.
   ============================================================ */
(function(){
  "use strict";

  var STORAGE_KEY = 'soloLevelingLifeTracker_v2';
  var TAB_KEY     = 'soloLevelingLifeTracker_iosTab';
  var PENDING_KEY = STORAGE_KEY + '_pending_import';

  /* ---------------- Tabs ---------------- */

  var tabs  = [].slice.call(document.querySelectorAll('.ios-tab'));
  var pages = [].slice.call(document.querySelectorAll('.ios-page'));

  function showTab(name, remember){
    tabs.forEach(function(t){ t.classList.toggle('active', t.dataset.tab === name); });
    pages.forEach(function(p){ p.classList.toggle('active', p.dataset.page === name); });
    window.scrollTo(0, 0);
    if(remember !== false){ try{ localStorage.setItem(TAB_KEY, name); }catch(e){} }
  }

  tabs.forEach(function(t){
    t.addEventListener('click', function(){ showTab(t.dataset.tab); });
  });

  var startTab = 'status';
  try{
    var saved = localStorage.getItem(TAB_KEY);
    if(saved && tabs.some(function(t){ return t.dataset.tab === saved; })) startTab = saved;
  }catch(e){}
  showTab(startTab, false);

  /* ---------------- Status bar mirror ----------------
     The original renderer owns the profile panel. Rather than
     duplicating IDs (which would break its lookups), mirror the
     values it writes into the compact fixed bar. */

  var src = {
    level:  document.getElementById('levelBadge'),
    name:   document.getElementById('playerName'),
    gold:   document.getElementById('goldAmount'),
    rank:   document.getElementById('rankBadge'),
    xpFill: document.getElementById('xpFill')
  };
  var dst = {
    level:  document.getElementById('tbLevel'),
    name:   document.getElementById('tbName'),
    gold:   document.getElementById('tbGold'),
    rank:   document.getElementById('tbRank'),
    xpFill: document.getElementById('tbXpFill')
  };

  function syncBar(){
    if(src.level && dst.level) dst.level.textContent = src.level.textContent;
    if(src.name  && dst.name)  dst.name.textContent  = src.name.value || 'HUNTER';
    if(src.gold  && dst.gold)  dst.gold.textContent  = src.gold.textContent + ' G';
    if(src.rank  && dst.rank){
      dst.rank.textContent = src.rank.textContent;
      dst.rank.className = 'ios-tb-rank ' + (src.rank.className.match(/rank-[A-Z]+/) || [''])[0];
    }
    if(src.xpFill && dst.xpFill) dst.xpFill.style.width = src.xpFill.style.width || '0%';
    syncAlerts();
  }

  /* A red dot on QUESTS whenever a daily quest is still open today. */
  function syncAlerts(){
    var open = document.querySelectorAll('#dailyList .quest-item:not(.done)').length;
    var qt = document.querySelector('.ios-tab[data-tab="quests"]');
    if(qt) qt.classList.toggle('has-alert', open > 0);
  }

  if(window.MutationObserver){
    var panel = document.getElementById('profilePanel');
    var list  = document.getElementById('dailyList');
    var obs   = new MutationObserver(function(){ syncBar(); });
    var opts  = { childList:true, subtree:true, characterData:true, attributes:true };
    if(panel) obs.observe(panel, opts);
    if(list)  obs.observe(list,  { childList:true, subtree:true, attributes:true });
  }
  if(src.name) src.name.addEventListener('input', syncBar);
  syncBar();
  // The original defers some renders; catch up once things settle.
  setTimeout(syncBar, 300);
  setTimeout(syncBar, 1500);

  /* ---------------- Save transfer ---------------- */

  var sheet = document.getElementById('iosSheet');
  function openSheet(){
    var ta = document.getElementById('iosPasteBox');
    if(ta) ta.value = '';
    sheet.classList.add('open');
  }
  function closeSheet(){ sheet.classList.remove('open'); }

  document.getElementById('iosTransferBtn').addEventListener('click', openSheet);
  document.getElementById('iosSheetClose').addEventListener('click', closeSheet);
  sheet.addEventListener('click', function(e){ if(e.target === sheet) closeSheet(); });

  function toast(msg, bad){
    var c = document.getElementById('notification-container');
    if(!c){ alert(msg); return; }
    var n = document.createElement('div');
    n.className = 'system-notification';
    if(bad) n.style.borderColor = 'var(--danger)';
    var t = document.createElement('div');
    t.className = 'notif-title';
    t.textContent = bad ? 'SYSTEM WARNING' : 'SYSTEM';
    var b = document.createElement('div');
    b.className = 'notif-body';
    b.textContent = msg;
    n.appendChild(t); n.appendChild(b);
    n.addEventListener('click', function(){ n.remove(); });
    c.appendChild(n);
    setTimeout(function(){ if(n.parentNode) n.remove(); }, 3600);
  }

  document.getElementById('iosCopyBtn').addEventListener('click', function(){
    var raw = '';
    try{ raw = localStorage.getItem(STORAGE_KEY) || ''; }catch(e){}
    if(!raw){ toast('No save data found.', true); return; }
    var done = function(){ toast('Save copied to clipboard.'); };
    if(navigator.clipboard && navigator.clipboard.writeText){
      navigator.clipboard.writeText(raw).then(done, function(){ fallbackCopy(raw, done); });
    } else {
      fallbackCopy(raw, done);
    }
  });

  function fallbackCopy(text, done){
    var ta = document.getElementById('iosPasteBox');
    ta.value = text;
    ta.focus();
    ta.setSelectionRange(0, ta.value.length);
    try{
      document.execCommand('copy');
      done();
    }catch(e){
      toast('Copy failed — select the text above and copy manually.', true);
    }
  }

  document.getElementById('iosLoadBtn').addEventListener('click', function(){
    var ta  = document.getElementById('iosPasteBox');
    var raw = (ta.value || '').trim();
    if(!raw){ toast('Paste your save data first.', true); return; }

    var parsed;
    try{
      parsed = JSON.parse(raw);
    }catch(e){
      toast('That is not valid save data (JSON parse failed).', true);
      return;
    }
    // Match what the game script itself demands of a save (player + dailyQuests).
    // Anything looser would be accepted here and then discarded as corrupt at
    // boot, silently resetting to a fresh character.
    if(!parsed || typeof parsed !== 'object' || !parsed.player ||
       typeof parsed.player.level !== 'number' || !parsed.dailyQuests){
      toast('That JSON is not a Solo Leveling save.', true);
      return;
    }

    var cur = null;
    try{ cur = localStorage.getItem(STORAGE_KEY); }catch(e){}
    var curLv = 1;
    if(cur){
      try{ curLv = (JSON.parse(cur).player || {}).level || 1; }catch(e){}
    }

    var msg = 'Replace this device\'s save (Level ' + curLv + ') with the pasted save (Level ' +
              parsed.player.level + ')?\n\nThe current save is backed up first and can be restored.';
    if(!confirm(msg)) return;

    // Stage it rather than writing the live save directly. The game script
    // flushes its in-memory state on pagehide/beforeunload, which would
    // overwrite a direct write on the way out of this reload; the bootstrap
    // in <head> applies the staged copy on the next boot instead.
    try{
      localStorage.setItem(PENDING_KEY, JSON.stringify(parsed));
    }catch(e){
      toast('Could not write the save (storage full?).', true);
      return;
    }
    location.reload();
  });

  /* ---------------- Home-screen metadata ----------------
     Re-declare the install tags into <head> at runtime. When this page is
     served inside a host that wraps the markup (so the original tags end up
     in <body>, where iOS ignores them), this is what makes Add to Home
     Screen still produce a fullscreen app with the right icon and name.
     Safari reads the live DOM at install time, so injecting here is enough.
     Existing tags are reused rather than duplicated. */

  function head(sel, make){
    var el = document.head.querySelector(sel);
    if(!el){ el = make(); document.head.appendChild(el); }
    return el;
  }
  function meta(name, content){
    head('meta[name="' + name + '"]', function(){
      var m = document.createElement('meta');
      m.setAttribute('name', name);
      return m;
    }).setAttribute('content', content);
  }

  var iconEl = document.querySelector('link[rel="apple-touch-icon"]');
  var iconSrc = iconEl ? iconEl.getAttribute('href') : '';

  try{
    meta('apple-mobile-web-app-capable', 'yes');
    meta('mobile-web-app-capable', 'yes');
    meta('apple-mobile-web-app-status-bar-style', 'black-translucent');
    meta('apple-mobile-web-app-title', 'THE SYSTEM');
    meta('theme-color', '#05050a');
    meta('viewport', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover');
    if(iconSrc){
      ['apple-touch-icon', 'icon'].forEach(function(rel){
        head('link[rel="' + rel + '"]', function(){
          var l = document.createElement('link');
          l.setAttribute('rel', rel);
          return l;
        }).setAttribute('href', iconSrc);
      });
    }
  }catch(e){}

  /* ---------------- PWA manifest (generated at runtime — no extra files) ---------------- */

  try{
    var iconHref = iconSrc;
    var manifest = {
      name: 'THE SYSTEM',
      short_name: 'SYSTEM',
      start_url: '.',
      scope: '.',
      display: 'standalone',
      orientation: 'portrait',
      background_color: '#05050a',
      theme_color: '#05050a',
      icons: [
        { src: iconHref, sizes: '180x180', type: 'image/png', purpose: 'any' }
      ]
    };
    var blob = new Blob([JSON.stringify(manifest)], { type: 'application/manifest+json' });
    var link = document.createElement('link');
    link.rel  = 'manifest';
    link.href = URL.createObjectURL(blob);
    document.head.appendChild(link);
  }catch(e){}

  /* ---------------- iOS install hint ----------------
     Shown once, and only in Safari-in-a-tab (not once installed). */

  try{
    var standalone = window.navigator.standalone === true ||
                     (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches);
    var isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) ||
                (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
    var hintKey = STORAGE_KEY + '_iosInstallHintSeen';
    if(isIOS && !standalone && !localStorage.getItem(hintKey)){
      var hint = document.getElementById('iosInstallHint');
      hint.style.display = 'block';
      document.getElementById('iosHintDismiss').addEventListener('click', function(){
        hint.style.display = 'none';
        try{ localStorage.setItem(hintKey, '1'); }catch(e){}
      });
    }
  }catch(e){}

  /* Keep the layout honest when the on-screen keyboard opens/closes. */
  window.addEventListener('orientationchange', function(){ setTimeout(syncBar, 250); });
})();
