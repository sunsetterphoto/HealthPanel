const test = require('node:test');
const assert = require('node:assert/strict');
const B = require('../plasmoid/contents/ui/batparse.js');

const ENERGY = [
  'POWER_SUPPLY_NAME=BAT0', 'POWER_SUPPLY_STATUS=Discharging', 'POWER_SUPPLY_PRESENT=1',
  'POWER_SUPPLY_TECHNOLOGY=Li-poly', 'POWER_SUPPLY_CYCLE_COUNT=112',
  'POWER_SUPPLY_VOLTAGE_MIN_DESIGN=15480000', 'POWER_SUPPLY_VOLTAGE_NOW=16100000',
  'POWER_SUPPLY_POWER_NOW=8200000', 'POWER_SUPPLY_ENERGY_FULL_DESIGN=51500000',
  'POWER_SUPPLY_ENERGY_FULL=48000000', 'POWER_SUPPLY_ENERGY_NOW=24000000',
  'POWER_SUPPLY_CAPACITY=50', 'POWER_SUPPLY_MODEL_NAME=5B11B79217',
  'POWER_SUPPLY_MANUFACTURER=SMP', 'POWER_SUPPLY_SERIAL_NUMBER= 1234 ',
  'HP_CHARGE_START=75', 'HP_CHARGE_END=80', 'HP_CHARGE_BEHAVIOUR=[auto] inhibit-charge force-discharge',
].join('\n');

test('energy-based battery (ThinkPad style)', () => {
  const r = B.parseBattery(ENERGY);
  assert.equal(r.present, true);
  assert.equal(r.name, 'BAT0');
  assert.equal(r.serial, '1234');
  assert.equal(r.capacityPct, 50);
  assert.equal(r.cycleCount, 112);
  assert.ok(Math.abs(r.energyFullDesignWh - 51.5) < 1e-9);
  assert.ok(Math.abs(r.healthPct - 48 / 51.5 * 100) < 1e-9);
  assert.ok(Math.abs(r.powerNowW - 8.2) < 1e-9);
  assert.equal(r.hasPowerNow, true);
  assert.equal(r.hasChargeThreshold, true);
  assert.equal(r.chargeStart, 75);
  assert.equal(r.chargeEnd, 80);
  assert.equal(r.chargeBehaviour, 'auto');
});

test('charge-based battery (µAh/µA) is converted to Wh/W', () => {
  const r = B.parseBattery([
    'POWER_SUPPLY_NAME=BAT1', 'POWER_SUPPLY_PRESENT=1', 'POWER_SUPPLY_STATUS=Discharging',
    'POWER_SUPPLY_VOLTAGE_MIN_DESIGN=11400000', 'POWER_SUPPLY_VOLTAGE_NOW=12000000',
    'POWER_SUPPLY_CHARGE_FULL_DESIGN=5000000', 'POWER_SUPPLY_CHARGE_FULL=4000000',
    'POWER_SUPPLY_CHARGE_NOW=2000000', 'POWER_SUPPLY_CURRENT_NOW=-1000000',
    'POWER_SUPPLY_CAPACITY=50', 'HP_CHARGE_START=', 'HP_CHARGE_END=', 'HP_CHARGE_BEHAVIOUR=',
  ].join('\n'));
  assert.ok(Math.abs(r.energyFullDesignWh - 57) < 1e-9);   // 5 Ah * 11.4 V
  assert.ok(Math.abs(r.energyFullWh - 45.6) < 1e-9);
  assert.ok(Math.abs(r.healthPct - 80) < 1e-9);
  assert.ok(Math.abs(r.powerNowW - 12) < 1e-9);            // |−1 A| * 12 V
  assert.equal(r.hasPowerNow, true);
  assert.equal(r.hasChargeThreshold, false);
  assert.equal(r.chargeBehaviour, '');
});

test('no battery: only the HP_* lines arrive', () => {
  const r = B.parseBattery('HP_CHARGE_START=\nHP_CHARGE_END=\nHP_CHARGE_BEHAVIOUR=');
  assert.equal(r.present, false);
  assert.equal(r.hasPowerNow, false);
  assert.equal(B.parseBattery('').present, false);
});

test('a driver without PRESENT still counts as present; PRESENT=0 does not', () => {
  assert.equal(B.parseBattery('POWER_SUPPLY_NAME=macsmc-battery\nPOWER_SUPPLY_CAPACITY=80').present, true);
  assert.equal(B.parseBattery('POWER_SUPPLY_NAME=BAT0\nPOWER_SUPPLY_PRESENT=0').present, false);
});
