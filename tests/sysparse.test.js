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

const POWER_APU = 'HASBATTERY=1\nCARD=0 BOOTVGA=1 DRIVER=amdgpu PPT=19067000';
const POWER_DGPU = 'HASBATTERY=0\nCARD=0 BOOTVGA=1 DRIVER=i915 PPT=0\nCARD=1 BOOTVGA=0 DRIVER=nvidia PPT=35000000';

test('parsePowerSection reads battery flag and card lines', () => {
  const ps = S.parsePowerSection(POWER_APU);
  assert.equal(ps.hasBattery, true);
  assert.equal(ps.cards.length, 1);
  assert.equal(ps.cards[0].driver, 'amdgpu');
  assert.equal(ps.cards[0].bootVga, true);
  assert.equal(ps.cards[0].pptUW, 19067000);
});

test('classifyGpuPower: integrated amdgpu on a laptop -> SoC, no GPU', () => {
  const c = S.classifyGpuPower(S.parsePowerSection(POWER_APU));
  assert.ok(Math.abs(c.socW - 19.067) < 1e-6);
  assert.equal(c.gpuW, null);
});

test('classifyGpuPower: discrete nvidia -> GPU, no SoC', () => {
  const c = S.classifyGpuPower(S.parsePowerSection(POWER_DGPU));
  assert.equal(c.socW, null);
  assert.ok(Math.abs(c.gpuW - 35) < 1e-6);
});

test('classifyGpuPower: empty section -> both null', () => {
  const c = S.classifyGpuPower(S.parsePowerSection(''));
  assert.equal(c.socW, null);
  assert.equal(c.gpuW, null);
});

test('parseFans picks the chip with the most fans; computes max', () => {
  const f = S.parseFans('thinkpad fan1=4385\nthinkpad fan2=4379\nacpi_fan fan1=4200');
  assert.deepEqual(f.fans, [4385, 4379]);
  assert.equal(f.maxRpm, 4385);
});
test('parseFans returns empty when no fans present', () => {
  const f = S.parseFans('');
  assert.deepEqual(f.fans, []);
  assert.equal(f.maxRpm, 0);
});
test('parseFans compacts non-contiguous fan indices (no phantom zero)', () => {
  const f = S.parseFans('thinkpad fan1=4000\nthinkpad fan3=4200');
  assert.deepEqual(f.fans, [4000, 4200]);
  assert.equal(f.maxRpm, 4200);
});
test('parseVolts reads vddgfx in volts; null when absent', () => {
  assert.ok(Math.abs(S.parseVolts('vddgfx=1285\nvddnb=693').gpuVoltageV - 1.285) < 1e-9);
  assert.equal(S.parseVolts('vddnb=693').gpuVoltageV, null);
});
test('parseTempSensors maps chip:label -> °C', () => {
  const t = S.parseTempSensors('nvme:Composite=38850\nnvme:Sensor1=52850\nnvme:Sensor2=38850');
  assert.equal(t['nvme:Sensor1'], 52.85);
  assert.equal(t['nvme:Composite'], 38.85);
});

const PROBE_SENSORS = [
  PROBE,                       // reuse the existing complete probe fixture
  '===RAPL1===', '1000000',
  '===RAPL2===', '7000000',    // +6,000,000 µJ over the 0.5s T1->T2 = 12 W
  '===RAPLMAX===', '262143328850',
  '===POWER===', 'HASBATTERY=1\nCARD=0 BOOTVGA=1 DRIVER=amdgpu PPT=19067000',
  '===FANS===', 'thinkpad fan1=4385\nthinkpad fan2=4379',
  '===VOLTS===', 'vddgfx=1285',
  '===TEMPSX===', 'nvme:Composite=38850\nnvme:Sensor1=52850',
].join('\n');

test('parseProbe surfaces power/fan/voltage/sensor fields', () => {
  const r = S.parseProbe(PROBE_SENSORS);
  assert.equal(r.valid, true);
  assert.ok(Math.abs(r.cpuPowerW - 12) < 0.05);
  assert.ok(Math.abs(r.socPowerW - 19.067) < 1e-3);
  assert.equal(r.gpuPowerW, null);
  assert.deepEqual(r.fanRpms, [4385, 4379]);
  assert.equal(r.fanMaxRpm, 4385);
  assert.ok(Math.abs(r.gpuVoltageV - 1.285) < 1e-9);
  assert.equal(r.diskTempSensor1C, 52.85);
});

test('parseProbe leaves new fields absent when sections missing', () => {
  const r = S.parseProbe(PROBE);   // original fixture, no new sections
  assert.equal(r.cpuPowerW, null);
  assert.equal(r.socPowerW, null);
  assert.equal(r.gpuPowerW, null);
  assert.deepEqual(r.fanRpms, []);
  assert.equal(r.gpuVoltageV, null);
  assert.equal(r.diskTempSensor1C, null);
});

// ---- desktop / workstation hardware (NVIDIA, several drives, labelled fans) ----

const NVGPU = [
  '0, 00000000:15:00.0, Quadro RTX 4000, 6, 447, 8192, 35, 9.57, 30',
  '1, 00000000:21:00.0, NVIDIA RTX A4500, 0, 66, 20470, 32, 5.96, 30',
].join('\n');

test('parseNvidia reads one entry per nvidia-smi line', () => {
  const g = S.parseNvidia(NVGPU);
  assert.equal(g.length, 2);
  assert.equal(g[0].name, 'Quadro RTX 4000');
  assert.equal(g[1].name, 'RTX A4500');          // "NVIDIA " prefix dropped
  assert.equal(g[0].busy, 6);
  assert.ok(Math.abs(g[0].vramTotalGB - 8) < 1e-9);
  assert.ok(Math.abs(g[0].vramPct - 447 / 8192 * 100) < 1e-9);
  assert.equal(g[0].tempC, 35);
  assert.equal(g[0].powerW, 9.57);
  assert.equal(g[0].fanPct, 30);
  assert.equal(g[0].voltageV, null);
});
test('parseNvidia maps unsupported fields to null and ignores junk', () => {
  const g = S.parseNvidia('0, 00000000:01:00.0, NVIDIA GeForce RTX 4060 Laptop GPU, 12, 300, 8188, 44, [N/A], [N/A]\nNVIDIA-SMI has failed');
  assert.equal(g.length, 1);
  assert.equal(g[0].name, 'RTX 4060 Laptop GPU');
  assert.equal(g[0].powerW, null);
  assert.equal(g[0].fanPct, null);
  assert.deepEqual(S.parseNvidia(''), []);
});
test('parseDiskTemps reads per-drive temperatures', () => {
  const d = S.parseDiskTemps('DEV=nvme1n1 T=29850 S1=30850\nDEV=sda T=32000 S1=');
  assert.deepEqual(d, [
    { dev: 'nvme1n1', tempC: 29.85, sensor1C: 30.85 },
    { dev: 'sda', tempC: 32, sensor1C: null },
  ]);
});
test('parseFans keeps labels aligned with the readings', () => {
  const f = S.parseFans('hp_wmi_sensors fan1=1323 CPU0 Fan\nhp_wmi_sensors fan2=921 Rear Chassis Fan0\nother fan1=500');
  assert.deepEqual(f.fans, [1323, 921]);
  assert.deepEqual(f.labels, ['CPU0 Fan', 'Rear Chassis Fan0']);
  assert.deepEqual(S.parseFans('thinkpad fan1=4385 ').labels, ['']);
});

const PROBE_WORKSTATION = [
  PROBE,
  '===ROOTDEV===', 'nvme1n1',
  // nvme0n1 sorts first but is NOT the root disk
  '===DISKTEMPS===', 'DEV=nvme0n1 T=26850 S1=27850\nDEV=nvme1n1 T=29850 S1=30850\nDEV=sda T=32000 S1=',
  '===NVGPU===', NVGPU,
  '===POWER===', 'HASBATTERY=0',
  '===FANS===', 'hp_wmi_sensors fan1=1323 CPU0 Fan\nhp_wmi_sensors fan2=921 Rear Chassis Fan0',
  '===TEMPSX===', 'nvme:Sensor1=27850\nhp_wmi_sensors:SystemAmbientTemperature=20000',
].join('\n');

test('parseProbe: NVIDIA GPUs form the gpu list; scalars mirror the first', () => {
  const r = S.parseProbe(PROBE_WORKSTATION);
  assert.equal(r.gpus.length, 2);
  assert.equal(r.gpuValid, true);
  assert.equal(r.gpuBusy, 6);
  assert.equal(r.gpuTempC, 35);
  assert.equal(r.gpuPowerW, 9.57);
  assert.equal(r.gpuFanPct, 30);
  assert.equal(r.socPowerW, null);
});
test('parseProbe: disk temperature belongs to the root disk, others are listed', () => {
  const r = S.parseProbe(PROBE_WORKSTATION);
  assert.equal(r.diskTempC, 29.85);
  assert.equal(r.diskTempSensor1C, 30.85);
  assert.deepEqual(r.otherDiskTemps, [{ dev: 'nvme0n1', tempC: 26.85 }, { dev: 'sda', tempC: 32 }]);
});
test('parseProbe: no temperature is guessed when the root disk has no sensor', () => {
  const r = S.parseProbe([PROBE, '===ROOTDEV===', 'sda', '===DISKTEMPS===', 'DEV=nvme0n1 T=26850 S1=27850'].join('\n'));
  assert.equal(r.diskTempC, null);
  assert.equal(r.diskTempSensor1C, null);
});
test('parseProbe: fan labels and ambient temperature', () => {
  const r = S.parseProbe(PROBE_WORKSTATION);
  assert.deepEqual(r.fanLabels, ['CPU0 Fan', 'Rear Chassis Fan0']);
  assert.equal(r.ambientTempC, 20);
  assert.equal(S.parseProbe(PROBE).ambientTempC, null);
  assert.deepEqual(S.parseProbe(PROBE).gpus.length, S.parseProbe(PROBE).gpuValid ? 1 : 0);
});

// ---- correctness fixes ----

test('parseCpuStat does not count guest time twice', () => {
  // user already includes guest: 100 user (of which 60 guest), 100 idle
  const p = S.parseCpuStat('cpu  100 0 0 100 0 0 0 0 60 0');
  assert.equal(p.total.total, 200);
});
test('offline CPUs leave no phantom core', () => {
  const a = 'cpu  0 0 0 0 0 0 0 0\ncpu0 100 0 0 100 0 0 0 0\ncpu2 100 0 0 100 0 0 0 0';
  const b = 'cpu  0 0 0 0 0 0 0 0\ncpu0 200 0 0 100 0 0 0 0\ncpu2 100 0 0 200 0 0 0 0';
  const r = S.cpuPct(S.parseCpuStat(a), S.parseCpuStat(b));
  const ids = S.parseCoreIds('cpu0 0\ncpu2 1');
  assert.deepEqual(S.physicalCoreLoads(r.cores, ids), [100, 0]);
});
test('parseCoreIds keeps cores of different packages apart', () => {
  const ids = S.parseCoreIds('cpu0 0\ncpu1 100000');   // core 0 on package 0 and 1
  assert.deepEqual(S.physicalCoreLoads([10, 30], ids), [10, 30]);
});
test('parseNetDev counts only the listed physical interfaces', () => {
  const dev = [
    '    lo: 500 0 0 0 0 0 0 0 500 0 0 0 0 0 0 0',
    '  eno1: 1000 0 0 0 0 0 0 0 2000 0 0 0 0 0 0 0',
    'tailscale0: 900 0 0 0 0 0 0 0 1800 0 0 0 0 0 0 0',
    'docker0: 5 0 0 0 0 0 0 0 5 0 0 0 0 0 0 0',
  ].join('\n');
  assert.deepEqual(S.parseNetDev(dev, ['eno1']), { rxBytes: 1000, txBytes: 2000 });
  assert.deepEqual(S.parseNetDev(dev), { rxBytes: 1905, txBytes: 3805 });   // legacy: all but lo
  assert.deepEqual(S.parseNetDev(dev, []), { rxBytes: 1905, txBytes: 3805 });
});
test('deviceBase leaves whole devices alone', () => {
  assert.equal(S.deviceBase('/dev/sda2'), 'sda');
  assert.equal(S.deviceBase('/dev/nvme0n1p7'), 'nvme0n1');
  assert.equal(S.deviceBase('/dev/dm-0'), 'dm-0');
  assert.equal(S.deviceBase('/dev/md0'), 'md0');
});
test('parseSmart: missing fields are null, an all-empty record is invalid', () => {
  const r = S.parseSmart('{"healthPct":null,"powerOnHours":1200,"tbwTB":null,"valid":true}');
  assert.equal(r.valid, true);
  assert.equal(r.healthPct, null);
  assert.equal(r.powerOnHours, 1200);
  assert.equal(S.parseSmart('{"healthPct":null,"powerOnHours":null,"tbwTB":null,"valid":true}').valid, false);
});
test('parseUpdate reads the updater status', () => {
  const u = S.parseUpdate('STATE=available\nLOCAL=58f2336\nREMOTE=abc1234\nCOUNT=3\nSUBJECT=fix: a=b thing');
  assert.equal(u.state, 'available');
  assert.equal(u.count, 3);
  assert.equal(u.subject, 'fix: a=b thing');
  assert.equal(S.parseUpdate('').state, 'unknown');
  const a = S.parseUpdate('RESULT=updated\nNEEDS_ROOT=1\nSTATE=current');
  assert.equal(a.result, 'updated');
  assert.equal(a.needsRoot, true);
});
