'use strict';
// Penalty-repair routine for the Solo Leveling save state.
// Generic: everything is computed from the save data itself, nothing hard-coded.

const ACTIVITY_KEYS = ['daily', 'weekly', 'boss', 'consumableBuy', 'consumableUse'];

function pad2(n) {
  return String(n).padStart(2, '0');
}

function formatDate(d) {
  return d.getFullYear() + '-' + pad2(d.getMonth() + 1) + '-' + pad2(d.getDate());
}

function parseDate(str) {
  const [y, m, d] = str.split('-').map(Number);
  return new Date(y, m - 1, d); // local time
}

function addDays(str, n) {
  const d = parseDate(str);
  d.setDate(d.getDate() + n);
  return formatDate(d);
}

function hasActivity(entry) {
  if (!entry) return false;
  return ACTIVITY_KEYS.some((k) => typeof entry[k] === 'number' && entry[k] > 0);
}

// Max history date whose entry has real activity (frozen-only entries ignored).
function findLastLogDate(history) {
  let last = null;
  for (const key of Object.keys(history)) {
    if (hasActivity(history[key])) {
      if (last === null || key > last) last = key;
    }
  }
  return last;
}

// Faithful simulation of the app's streak logic over the history calendar.
function computeStreak(history, lastLogDate) {
  const keys = Object.keys(history).sort();
  if (keys.length === 0 || !lastLogDate) return 0;
  let streak = 0;
  let lastActive = null;
  for (let day = keys[0]; day <= lastLogDate; day = addDays(day, 1)) {
    const entry = history[day];
    if (entry && entry.frozen) {
      // Freeze pins the marker; no increment, even if the day also has activity.
      lastActive = day;
    } else if (hasActivity(entry)) {
      streak = lastActive === addDays(day, -1) ? streak + 1 : 1;
      lastActive = day;
    }
    // else: gap, do nothing
  }
  return streak;
}

/**
 * Repairs a save state that took streak/rollover penalties during an inactivity gap.
 * @param {object} state parsed save JSON (mutated copy is returned; input untouched)
 * @param {string} [today] YYYY-MM-DD, defaults to the current local date
 * @returns {{repairedState: object, summaryLines: string[]}}
 */
function repair(state, today) {
  const s = JSON.parse(JSON.stringify(state));
  if (!today) today = formatDate(new Date());
  const summaryLines = [];

  s.history = s.history || {};
  s.player = s.player || {};

  const lastLogDate = findLastLogDate(s.history);
  if (!lastLogDate) {
    return { repairedState: s, summaryLines: ['No logged activity found - nothing to repair.'] };
  }

  // 1. Streak
  const computedStreak = computeStreak(s.history, lastLogDate);
  const oldStreak = s.player.streak || 0;
  if (oldStreak !== computedStreak) {
    summaryLines.push('Streak restored: ' + oldStreak + ' → ' + computedStreak + '.');
  } else {
    summaryLines.push('Streak already correct at ' + computedStreak + '.');
  }
  s.player.streak = computedStreak;

  // 2. Fatigue
  if (s.player.fatigued) {
    summaryLines.push('Fatigue cleared.');
  }
  s.player.fatigued = false;

  // 3. Freeze the gap days (lastLogDate+1 .. yesterday, today excluded)
  const yesterday = addDays(today, -1);
  const frozenDays = [];
  for (let day = addDays(lastLogDate, 1); day <= yesterday; day = addDays(day, 1)) {
    if (!s.history[day]) s.history[day] = {};
    s.history[day].frozen = 1;
    frozenDays.push(day);
  }
  if (frozenDays.length > 0) {
    summaryLines.push(
      'Days ' + frozenDays[0] + ' → ' + frozenDays[frozenDays.length - 1] +
      ' (' + frozenDays.length + ' day' + (frozenDays.length === 1 ? '' : 's') +
      ') marked as vacation-frozen.'
    );
  }

  // 4. Reset activity markers so today continues the streak with no rollover penalty.
  s.player.lastActiveDate = today;
  s.player.lastRolloverDay = today;
  summaryLines.push('Last-active and rollover markers set to today (' + today + ').');

  // 5. Extend hidden-quest deadline by the newly frozen days.
  if (s.hiddenQuests && s.hiddenQuests.active && s.hiddenQuests.active.deadline && frozenDays.length > 0) {
    const oldDeadline = s.hiddenQuests.active.deadline;
    const newDeadline = addDays(oldDeadline, frozenDays.length);
    s.hiddenQuests.active.deadline = newDeadline;
    summaryLines.push(
      'Secret quest deadline extended ' + frozenDays.length + ' day' +
      (frozenDays.length === 1 ? '' : 's') + ': ' + oldDeadline + ' → ' + newDeadline + '.'
    );
  }

  summaryLines.push('No XP, gold, stat, quest, or consumable changes.');

  return { repairedState: s, summaryLines };
}

module.exports = { repair, computeStreak, findLastLogDate, hasActivity, addDays, formatDate };
