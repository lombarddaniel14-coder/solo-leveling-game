'use strict';
// Standalone test: runs the repair routine against Daniel's real exported save
// (read-only) with a mocked "today" of 2026-07-30 and asserts the exact outcome.

const assert = require('assert');
const fs = require('fs');
const path = require('path');
const { repair } = require(path.join(__dirname, '..', 'repair.js'));

const FIXTURE = 'C:\\Users\\Daniel\\Downloads\\solo-leveling-save-2026-07-25.json';
const TODAY = '2026-07-30';

const original = JSON.parse(fs.readFileSync(FIXTURE, 'utf8'));
const originalSnapshot = JSON.stringify(original);

const { repairedState: s, summaryLines } = repair(original, TODAY);

// Input object must not be mutated (and the Downloads file is never written).
assert.strictEqual(JSON.stringify(original), originalSnapshot, 'input state was mutated');

// 1. Streak recomputed to 9 (Jul 9-15 = 7, Jul 16-21 frozen pins chain, Jul 22 -> 8, Jul 23 -> 9)
assert.strictEqual(s.player.streak, 9, 'streak should be 9, got ' + s.player.streak);

// 2. Gap days 2026-07-24 .. 2026-07-29 frozen - exactly those, no others new
const expectFrozen = ['2026-07-24', '2026-07-25', '2026-07-26', '2026-07-27', '2026-07-28', '2026-07-29'];
for (const day of expectFrozen) {
  assert.ok(s.history[day], 'missing history entry for ' + day);
  assert.strictEqual(s.history[day].frozen, 1, day + ' should be frozen');
}
const newKeys = Object.keys(s.history).filter((k) => !(k in original.history)).sort();
assert.deepStrictEqual(newKeys, expectFrozen, 'unexpected new history keys: ' + newKeys);
assert.ok(!s.history[TODAY], 'today must not get a history entry');

// 3. Hidden quest deadline 2026-08-22 -> 2026-08-28 (+6 days)
assert.strictEqual(s.hiddenQuests.active.deadline, '2026-08-28',
  'deadline should be 2026-08-28, got ' + s.hiddenQuests.active.deadline);

// 4. Fatigue cleared
assert.strictEqual(s.player.fatigued, false, 'fatigued should be false');

// 5. XP / gold untouched
assert.strictEqual(s.player.xp, 218, 'xp should be unchanged at 218');
assert.strictEqual(s.player.gold, 56, 'gold should be unchanged at 56');

// 6. Rollover markers set to mocked today
assert.strictEqual(s.player.lastActiveDate, TODAY);
assert.strictEqual(s.player.lastRolloverDay, TODAY);

console.log('ALL ASSERTIONS PASSED');
console.log('streak: 0 -> ' + s.player.streak);
console.log('frozen days: ' + expectFrozen.join(', '));
console.log('deadline: 2026-08-22 -> ' + s.hiddenQuests.active.deadline);
console.log('fatigued: ' + s.player.fatigued + ' | xp: ' + s.player.xp + ' | gold: ' + s.player.gold);
console.log('--- dialog summary ---');
summaryLines.forEach((l) => console.log('  ' + l));
