import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const ets = join(root, 'entry/src/main/ets');
function walk(dir) { return readdirSync(dir, { withFileTypes:true }).flatMap(item => item.isDirectory() ? walk(join(dir,item.name)) : [join(dir,item.name)]); }
const sources = walk(ets).filter(p=>/\.(ets|ts)$/.test(p) && !p.includes('/jsencrypt/') && !p.endsWith('/Encryption.ets'));
test('no compiled first-party source imports credentials or registers a password bridge', () => {
  for (const path of sources) {
    const text = readFileSync(path,'utf8');
    assert.doesNotMatch(text, /(?:from\s+['"][^'"]*(?:Encryption|PasswordDialog)|javaScriptProxy|registerJavaScriptProxy|getPassword\s*\(|fillInformationJS|console\.[a-z]+\([^\n]*\+ result)/, path);
    assert.doesNotMatch(text, /https?:\/\/[^\s'"`]*ustc\.edu\.cn/, path);
  }
});
test('relative imports and explicitly named resources resolve', () => {
  const resourceRoot=join(root,'entry/src/main/resources');
  const resourceNames = new Set();
  for (const dir of [resourceRoot,join(root,'AppScope/resources')]) {
    for (const path of walk(dir)) {
      if (path.endsWith('.json') && path.includes('/element/')) {
        const content=JSON.parse(readFileSync(path,'utf8'));
        for(const [kind,values] of Object.entries(content)) for(const value of values) resourceNames.add(kind+'.'+value.name);
      }
      if(path.includes('/media/')) resourceNames.add('media.'+path.split('/').pop().replace(/\.[^.]+$/,''));
    }
  }
  for (const path of sources) {
    const text=readFileSync(path,'utf8');
    for (const match of text.matchAll(/from\s+['"](\.[^'"]+)['"]/g)) {
      const target=resolve(dirname(path),match[1]);
      assert.ok(['','.ets','.ts','.js','/index.ets','/index.ts'].some(ext=>existsSync(target+ext)), `${path}: ${match[1]}`);
    }
    for (const match of text.matchAll(/\$r\(['"]app\.([^'"]+)['"]\)/g)) assert.ok(resourceNames.has(match[1]), `${path}: ${match[1]}`);
  }
});
test('fork bundle identity is consistent in launch, shortcuts and widget creation', () => {
  for (const file of ['AppScope/app.json5','entry/src/main/resources/base/profile/shortcuts_config.json','entry/src/main/ets/utils/WantAbility.ets','entry/src/main/ets/pages/AddCard.ets']) {
    const source=readFileSync(join(root,file),'utf8');
    assert.match(source,/com\.sdkdsd\.dailynic\.sust/);
    assert.doesNotMatch(source,/com\.nic\.dailynic/);
  }
});
test('no USTC 13-period layout or fixed morning/afternoon split remains', () => {
  const schedule=readFileSync(join(ets,'pages/Schedule.ets'),'utf8');
  assert.doesNotMatch(schedule,/commonClassStamp\[13\]|createArray\(1, 13\)|Array\(14\)|\/ 13\b|\.layoutWeight\(5\)/);
  const sources=readFileSync(join(ets,'constants/ScheduleSources.ets'),'utf8');
  assert.doesNotMatch(sources,/'07:50'|'19:30'/);
  assert.match(readFileSync(join(ets,'class_schedule_daily/pages/Class_schedule_dailyCard.ets'),'utf8'), /@LocalStorageProp\('periodTimes'\)/);
});
