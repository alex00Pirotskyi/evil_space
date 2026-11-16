import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {curateLegacyMenuGroups, discontinuedMenuItem,
  canonicalMenuGroupForItem} from './menu_catalog_policy.js';

test('legacy published catalog merges Monthly into Coworking without losing original records', () => {
  const legacy=[
    {id:'coworking', name:'Coworking', items:[{id:'coworking-day',priceVnd:200000}]},
    {id:'membership', name:'Monthly', items:[{id:'coworking-month',priceVnd:2500000}]},
    {id:'storage-locker',name:'Storage Locker',items:[{id:'storage-locker-month',priceVnd:1000000}]},
    {id:'drinks',name:'Drinks',items:[{id:'cola',priceVnd:25000}]},
  ];
  const before=JSON.stringify(legacy);
  const curated=curateLegacyMenuGroups(legacy);
  assert.equal(JSON.stringify(legacy),before,'do not mutate stored historical catalog');
  assert.deepEqual(curated.map(g=>g.id),['coworking','drinks']);
  assert.deepEqual(curated[0].items.map(i=>i.id),['coworking-day','coworking-month']);
  assert.equal(curated[0].items[1].priceVnd,2500000);
  assert.deepEqual(curateLegacyMenuGroups(curated),curated,'idempotent during re-publish');
  assert.equal(discontinuedMenuItem('storage-locker-month'),true);
  assert.equal(discontinuedMenuItem('coworking-month'),false);
  assert.equal(canonicalMenuGroupForItem('coworking-month','membership'),'coworking');
});

test('ordinary empty editor draft groups survive curation',()=>{
  const groups=[{id:'new-section',name:'Untitled',items:[]}];
  assert.deepEqual(curateLegacyMenuGroups(groups),groups);
});

test('existing published catalog without separate Monthly still renders once',()=>{
  const groups=[
    {id:'coworking',items:[{id:'coworking-day'},{id:'coworking-month'}]},
    {id:'snacks',items:[{id:'chocolate'}]},
  ];
  assert.deepEqual(curateLegacyMenuGroups(groups),groups);
});

test('new bundled cafe menu has monthly pass under coworking and no locker category', async()=>{
  const json=JSON.parse(await readFile(new URL('../docs/menu.json',import.meta.url),'utf8'));
  assert.ok(json.version>=6);
  const group=json.groups.find(g=>g.id==='coworking');
  assert.deepEqual(group.items.map(x=>x.id),['coworking-day','coworking-month']);
  assert.equal(group.items[1].priceVnd,2500000);
  assert.ok(!json.groups.some(g=>g.id==='membership'||g.id==='storage-locker'));
  assert.ok(!JSON.stringify(json).toLowerCase().includes('locker'));
});
