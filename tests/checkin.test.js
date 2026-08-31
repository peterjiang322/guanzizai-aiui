const assert = require('assert');
const fs = require('fs');

const source = fs.readFileSync('pages/index/index.ink', 'utf8');
const match = source.match(/function calculateCheckinStreak[\s\S]*?\n}/);
assert(match, 'calculateCheckinStreak must be defined in index.ink');
const calculateCheckinStreak = new Function(`return (${match[0]})`)();

assert.strictEqual(calculateCheckinStreak('2026-08-10', '', 0), 1);
assert.strictEqual(calculateCheckinStreak('2026-08-10', '2026-08-10', 4), 4);
assert.strictEqual(calculateCheckinStreak('2026-08-11', '2026-08-10', 4), 5);
assert.strictEqual(calculateCheckinStreak('2026-08-12', '2026-08-10', 4), 1);
assert.strictEqual(calculateCheckinStreak('2026-09-01', '2026-08-31', 4), 5);

console.log('checkin tests passed');
