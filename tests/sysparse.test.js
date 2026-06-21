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

// /proc/stat: cpu  user nice system idle iowait irq softirq steal guest guest_nice
const STAT1 = [
  'cpu  1000 0 500 8000 200 0 0 0 0 0',
  'cpu0 250 0 125 2000 50 0 0 0 0 0',
  'cpu1 250 0 125 2000 50 0 0 0 0 0',
  'cpu2 250 0 125 2000 50 0 0 0 0 0',
  'cpu3 250 0 125 2000 50 0 0 0 0 0',
  'intr 12345',
].join('\n');
// second snapshot: total jiffies +1000, of which idle +500 -> 50% busy overall.
const STAT2 = [
  'cpu  1375 0 625 8400 300 0 0 0 0 0',
  'cpu0 350 0 175 2000 50 0 0 0 0 0',   // +400 total, +0 idle -> ~100%
  'cpu1 250 0 125 2200 50 0 0 0 0 0',   // +200 total, +200 idle -> 0%
  'cpu2 300 0 150 2100 75 0 0 0 0 0',   // +200 total, +125 idle -> ~37.5%
  'cpu3 300 0 150 2100 75 0 0 0 0 0',
  'intr 99999',
].join('\n');

test('parseCpuStat reads total + per-logical-cpu idle/total', () => {
  const p = S.parseCpuStat(STAT1);
  assert.equal(p.cores.length, 4);
  assert.equal(p.total.idle, 8200);          // idle+iowait
  assert.equal(p.total.total, 1000+500+8000+200);
});

test('cpuPct computes overall and per-core busy percent', () => {
  const r = S.cpuPct(S.parseCpuStat(STAT1), S.parseCpuStat(STAT2));
  assert.ok(Math.abs(r.total - 50) < 1);
  assert.ok(Math.abs(r.cores[0] - 100) < 1);
  assert.ok(Math.abs(r.cores[1] - 0) < 1);
  assert.ok(Math.abs(r.cores[2] - 37.5) < 1);
});

test('physicalCoreLoads averages SMT siblings by core_id', () => {
  // 4 logical -> 2 physical: cpu0+cpu2 = core0, cpu1+cpu3 = core1
  const phys = S.physicalCoreLoads([100, 0, 50, 20], [0, 1, 0, 1]);
  assert.equal(phys.length, 2);
  assert.equal(phys[0], 75);   // (100+50)/2
  assert.equal(phys[1], 10);   // (0+20)/2
});

test('physicalCoreLoads falls back to identity when no coreIds', () => {
  const phys = S.physicalCoreLoads([10, 20], null);
  assert.deepEqual(phys, [10, 20]);
});

test('parseCoreIds maps "cpuN id" lines in numeric order', () => {
  const ids = S.parseCoreIds('cpu0 0\ncpu1 0\ncpu2 1\ncpu3 1');
  assert.deepEqual(ids, [0, 0, 1, 1]);
});
