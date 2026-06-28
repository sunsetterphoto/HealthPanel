const test = require('node:test');
const assert = require('node:assert/strict');
const L = require('../plasmoid/contents/ui/layoutmeta.js');

test('systemSections lists the 7 sections in default order', () => {
  assert.deepEqual(L.systemSections().map(s => s.id),
    ['powerMode','cpu','gpu','ram','disk','fans','net']);
});

test('defaultOrder marks all visible except defaultVisible:false', () => {
  const d = L.defaultOrder(L.batteryBlocks());
  const serial = d.find(x => x.id === 'serial');
  assert.equal(serial.v, false);
  assert.equal(d.find(x => x.id === 'status').v, true);
});

test('parseOrder keeps known ids in stored order, honoring v', () => {
  const json = '[{"id":"net","v":true},{"id":"cpu","v":false}]';
  const r = L.parseOrder(json, L.systemSections());
  assert.equal(r[0].id, 'net');
  assert.equal(r[1].id, 'cpu');
  assert.equal(r[1].v, false);
});

test('parseOrder appends known ids missing from the stored list (visible)', () => {
  const r = L.parseOrder('[{"id":"net","v":true}]', L.systemSections());
  // net first, then the remaining 6 in meta order, all visible
  assert.equal(r[0].id, 'net');
  assert.equal(r.length, 7);
  assert.ok(r.slice(1).every(x => x.v === true));
  assert.deepEqual(r.map(x => x.id).slice().sort(),
    ['cpu','disk','fans','gpu','net','powerMode','ram'].sort());
});

test('parseOrder drops unknown ids and tolerates garbage/empty', () => {
  const r = L.parseOrder('[{"id":"bogus","v":true},{"id":"cpu","v":true}]', L.systemSections());
  assert.ok(!r.some(x => x.id === 'bogus'));
  assert.equal(L.parseOrder('not json', L.systemSections()).length, 7);
  assert.equal(L.parseOrder('', L.columns()).length, 3);
});

test('serialize round-trips through parseOrder', () => {
  const arr = L.defaultOrder(L.systemSections());
  assert.deepEqual(L.parseOrder(L.serialize(arr), L.systemSections()), arr);
});
