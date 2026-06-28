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
  'cpu0 350 0 175 2000 50 0 0 0 0 0',   // +150 total, +0 idle -> 100%
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

const NETDEV = [
  'Inter-|   Receive                                                |  Transmit',
  ' face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets',
  '    lo: 1000 10 0 0 0 0 0 0 1000 10 0 0 0 0 0 0',
  ' wlp1s0: 1000000 100 0 0 0 0 0 0 200000 50 0 0 0 0 0 0',
].join('\n');

test('parseNetDev sums rx/tx bytes of all interfaces except lo', () => {
  const n = S.parseNetDev(NETDEV);
  assert.equal(n.rxBytes, 1000000);
  assert.equal(n.txBytes, 200000);
});

test('rateMBps converts a byte delta over dt to MB/s, clamps resets', () => {
  assert.ok(Math.abs(S.rateMBps(0, 1048576, 1) - 1) < 1e-9);   // 1 MiB/s
  assert.ok(Math.abs(S.rateMBps(0, 524288, 0.5) - 1) < 1e-9);
  assert.equal(S.rateMBps(0, 0, 0), 0);                        // dt<=0 guard
  assert.equal(S.rateMBps(100, 50, 1), 0);                     // counter reset -> 0
});

// /proc/diskstats: major minor name reads rmerged sectorsRead time writes wmerged sectorsWritten ...
const DISK1 = '259 0 nvme0n1 100 0 2048 0 50 0 1024 0 0 0 0\n259 7 nvme0n1p7 90 0 2000 0 40 0 1000 0 0 0 0';
const DISK2 = '259 0 nvme0n1 110 0 4096 0 60 0 3072 0 0 0 0\n259 7 nvme0n1p7 95 0 3000 0 45 0 2000 0 0 0 0';

test('parseDiskstats reads sectorsRead/Written for a whole-disk device', () => {
  const d = S.parseDiskstats(DISK1, 'nvme0n1');
  assert.equal(d.readSectors, 2048);
  assert.equal(d.writeSectors, 1024);
});

test('sectorsRateMBps converts sector deltas (x512) to MB/s', () => {
  // read: (4096-2048)*512 = 1048576 bytes over 0.5s -> 2 MB/s
  assert.ok(Math.abs(S.sectorsRateMBps(2048, 4096, 0.5) - 2) < 1e-9);
});

test('deviceBase strips partition suffix', () => {
  assert.equal(S.deviceBase('/dev/nvme0n1p7'), 'nvme0n1');
  assert.equal(S.deviceBase('/dev/sda1'), 'sda');
  assert.equal(S.deviceBase('/dev/mmcblk0p2'), 'mmcblk0');
});

test('parseDfLine reads used/size bytes from df -B1 output', () => {
  const r = S.parseDfLine('/dev/nvme0n1p7 831134564352 2088000000000');
  assert.equal(r.usedBytes, 831134564352);
  assert.equal(r.sizeBytes, 2088000000000);
  assert.equal(r.source, '/dev/nvme0n1p7');
});

test('parseProfile extracts the ppd profile id from busctl output', () => {
  assert.equal(S.parseProfile('s "power-saver"'), 'power-saver');
  assert.equal(S.parseProfile('s "performance"'), 'performance');
  assert.equal(S.parseProfile('garbage'), '');
});

test('parseTemps picks CPU (k10temp) and disk (nvme) temps in °C', () => {
  const t = S.parseTemps('AC \nk10temp 38625\nnvme 34000\nacpitz 42000');
  assert.equal(t.cpuTempC, 38.625);
  assert.equal(t.diskTempC, 34);
});
test('parseTemps returns null when a sensor is absent', () => {
  const t = S.parseTemps('acpitz 42000');
  assert.equal(t.cpuTempC, null);
  assert.equal(t.diskTempC, null);
});
test('parseSmart parses cache JSON; invalid/garbage -> {valid:false}', () => {
  const s = S.parseSmart('{"healthPct":98,"powerOnHours":14520,"tbwTB":47,"valid":true}');
  assert.equal(s.valid, true); assert.equal(s.healthPct, 98); assert.equal(s.tbwTB, 47);
  assert.equal(S.parseSmart('').valid, false);
  assert.equal(S.parseSmart('{"valid":false}').valid, false);
  assert.equal(S.parseSmart('not json').valid, false);
});

const PROBE = [
  '===T1===', '1000.000',
  '===STAT1===', STAT1,
  '===NET1===', NETDEV,
  '===DISK1===', DISK1,
  '===T2===', '1000.500',
  '===STAT2===', STAT2,
  '===NET2===',
  '    lo: 1000 10 0 0 0 0 0 0 1000 10 0 0 0 0 0 0',
  ' wlp1s0: 1262144 110 0 0 0 0 0 0 357288 60 0 0 0 0 0 0',  // +262144 rx, +157288 tx over 0.5s
  '===DISK2===', DISK2,
  '===MEM===', MEMINFO,
  '===CORES===', 'cpu0 0\ncpu1 1\ncpu2 0\ncpu3 1',
  '===DF===', '/dev/nvme0n1p7 831134564352 2088000000000',
  '===TEMPS===', 'k10temp 38625\nnvme 34000\nacpitz 42000',
  '===SMART===', '{"healthPct":98,"powerOnHours":14520,"tbwTB":47,"valid":true}',
].join('\n');

test('parseProbe returns a complete, valid result object', () => {
  const r = S.parseProbe(PROBE);
  assert.equal(r.valid, true);
  assert.ok(Math.abs(r.cpuPct - 50) < 1);
  assert.equal(r.coreLoads.length, 2);                    // 4 logical -> 2 physical
  assert.equal(r.coreLoadsLogical.length, 4);             // raw logical cores
  assert.ok(Math.abs(r.ramPct - 57.7) < 0.5);
  assert.ok(Math.abs(r.swapPct - 5.1) < 0.5);
  assert.ok(Math.abs(r.netDownMBps - 0.5) < 0.05);
  assert.ok(Math.abs(r.netUpMBps - 0.3) < 0.05);
  assert.ok(Math.abs(r.diskReadMBps - 2) < 0.05);
  assert.ok(Math.abs(r.diskWriteMBps - 2) < 0.05);
  assert.ok(Math.abs(r.diskPct - 39.8) < 0.5);
  assert.ok(r.diskTotalGB > 1900 && r.diskTotalGB < 2000);
  // temps + smart
  assert.ok(Math.abs(r.cpuTempC - 38.625) < 0.01);
  assert.equal(r.diskTempC, 34);
  assert.equal(r.smartValid, true);
  assert.equal(r.smartHealthPct, 98);
  assert.equal(r.smartPowerOnHours, 14520);
  assert.equal(r.smartTbwTB, 47);
});

test('parseProbe returns valid:false on empty/garbage input', () => {
  assert.equal(S.parseProbe('').valid, false);
  assert.equal(S.parseProbe('nothing useful').valid, false);
});

test('parseGpu reads busy% and VRAM usage; invalid when absent', () => {
  const g = S.parseGpu('BUSY=7\nVRAMUSED=1892376576\nVRAMTOTAL=8589934592');
  assert.equal(g.valid, true);
  assert.equal(g.busy, 7);
  assert.ok(Math.abs(g.vramUsedGB - 1.762) < 0.01);
  assert.ok(Math.abs(g.vramTotalGB - 8.0) < 0.01);
  assert.ok(Math.abs(g.vramPct - 22.0) < 0.5);
  assert.equal(S.parseGpu('').valid, false);
});

test('parseRaplPower computes watts from energy_uj delta over dt', () => {
  // 6,000,000 µJ over 0.5 s = 12 W
  assert.ok(Math.abs(S.parseRaplPower('1000000', '7000000', '262143328850', 0.5) - 12) < 1e-9);
});
test('parseRaplPower handles counter wraparound using raplMax', () => {
  // wrap: e2 < e1; de = (max - e1) + e2 = (100 - 90) + 5 = 15 µJ over 1 s
  assert.ok(Math.abs(S.parseRaplPower('90', '5', '100', 1) - 15e-6) < 1e-12);
});
test('parseRaplPower returns null when energy is unreadable or dt<=0', () => {
  assert.equal(S.parseRaplPower('', '7000000', '100', 0.5), null);
  assert.equal(S.parseRaplPower('1000000', '7000000', '100', 0), null);
  assert.equal(S.parseRaplPower('x', 'y', '100', 0.5), null);
});
