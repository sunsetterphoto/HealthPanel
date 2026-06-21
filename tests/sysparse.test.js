const test = require('node:test');
const assert = require('node:assert/strict');
const S = require('../plasmoid/contents/ui/sysparse.js');

const MEMINFO = [
  'MemTotal:       16077216 kB',
  'MemFree:         1234567 kB',
  'MemAvailable:    6800000 kB',
  'SwapTotal:       8388604 kB',
  'SwapFree:        7960000 kB',
].join('\n');

test('parseMeminfo extracts the four counters', () => {
  const mi = S.parseMeminfo(MEMINFO);
  assert.equal(mi.memTotalKb, 16077216);
  assert.equal(mi.memAvailKb, 6800000);
  assert.equal(mi.swapTotalKb, 8388604);
  assert.equal(mi.swapFreeKb, 7960000);
});

test('memStats computes used GB / percent for RAM and swap', () => {
  const m = S.memStats(S.parseMeminfo(MEMINFO));
  assert.ok(Math.abs(m.totalGB - 15.33) < 0.02);     // 16077216/1048576
  assert.ok(Math.abs(m.usedGB - 8.85) < 0.02);       // (16077216-6800000)/1048576
  assert.ok(Math.abs(m.pct - 57.7) < 0.5);
  assert.ok(Math.abs(m.swapTotalGB - 8.0) < 0.02);
  assert.ok(Math.abs(m.swapPct - 5.1) < 0.5);
});
