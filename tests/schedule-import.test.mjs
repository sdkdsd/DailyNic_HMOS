// Synthetic fixtures, isolated in-memory preferences; no real student information.
import test from 'node:test';
import assert from 'node:assert/strict';
import { asURL, loadLogic } from './logic-loader.mjs';
const timeURL = new URL('../entry/src/main/ets/utils/CampusTime.ts', import.meta.url).href;
const prefsURL = asURL(`const data = new Map(); export default {getSync:(key, fallback='')=>data.get(key)??fallback, putSync:(key,value)=>data.set(key,value), getNumberSync:(key,fallback)=>data.get(key)??fallback};`);
const fileURL = asURL(`export const files=new Map(); export const fileIo={OpenMode:{WRITE_ONLY:1,CREATE:2,TRUNC:4},accessSync:p=>files.has(p),readTextSync:p=>files.get(p),openSync:p=>({fd:p}),writeSync:(p,s)=>files.set(p,s),closeSync:()=>{},renameSync:(a,b)=>{files.set(b,files.get(a));files.delete(a)}};`);
const config = await loadLogic('utils/CampusConfig.ets', { '@kit.CoreFileKit': fileURL, './CampusTime': timeURL });
const sources = await loadLogic('constants/ScheduleSources.ets', { '../utils/UnifyPreference': prefsURL, '../utils/CampusConfig': config.url, '../utils/CampusTime': timeURL });
const c = config.module;
const validate = sources.module.validateExportedData;
const fixture = () => ({
  exportTime: 1790000000, scheduleVersion: 'sust-xian-1', defaultSemester: 0,
  periods: [['08:10', '08:55'], ['09:05', '09:50']],
  semesters: [{ attribute: { name: 'Synthetic fixture', source: 'test only', createTime: 1790000000000,
    beginTime: Date.parse('2026-09-07T00:00:00+08:00'), totalWeekNum: 16 },
    courses: [{ name: 'Synthetic course', teacher: '', location: '', id: '', color: '#FFFFFFFF', priority: 5,
      credits: '', dayOfWeek: 0, timeSpan: [1, 2], weekOfTerm: [1, 3, 5] }] }]
});
test('no timetable or import is enabled until an explicit campus profile is saved', () => {
  c.initCampusProfile({ filesDir: "/fixture" });
  assert.equal(c.campusReady(), false);
  assert.equal(c.periodCount(), 0);
  assert.notEqual(validate(fixture()), '');
  c.saveCampusProfile({ firstMonday: '2026-09-07', periodsText: '08:10-08:55\n09:05-09:50', source: 'Synthetic fixture, not SUST evidence' });
  assert.equal(c.campusReady(), true);
  assert.equal(c.periodCount(), 2);
  assert.equal(sources.module.commonClassTime[1][0], '08:10');
  assert.equal(sources.module.commonClassStamp[1][0], 29400000);
  assert.equal(validate(fixture()), '');
});
test('backup validation refuses incompatible school/version, timing and bad indices before persistence', () => {
  const bad = [
    f => { f.scheduleVersion = '2.1.0'; },
    f => { delete f.periods; },
    f => { f.periods[0][0] = '07:50'; },
    f => { f.defaultSemester = 1; },
    f => { f.defaultSemester = 0.5; },
    f => { f.semesters[0].attribute.beginTime -= 86400000; },
    f => { f.semesters[0].attribute.beginTime = Infinity; },
    f => { f.semesters[0].attribute.createTime = NaN; },
    f => { f.semesters.push(structuredClone(f.semesters[0])); },
    f => { f.semesters[0].courses[0].timeSpan = []; },
    f => { f.semesters[0].courses[0].timeSpan = [13]; },
    f => { f.semesters[0].courses[0].timeSpan = [2, 1]; },
    f => { f.semesters[0].courses[0].timeSpan = [1, 1]; },
    f => { f.semesters[0].courses[0].weekOfTerm = []; },
    f => { f.semesters[0].courses[0].weekOfTerm = [3, 1]; },
    f => { f.semesters[0].courses[0].weekOfTerm = [1, 17]; },
    f => { f.semesters[0].courses[0].dayOfWeek = 7; },
  ];
  for (const mutate of bad) { const data = fixture(); mutate(data); assert.notEqual(validate(data), '', mutate.toString()); }
});
test('bad stored configuration does not silently fall back to another university timetable', async () => {
  const files = (await import(fileURL)).files;
  files.set("/fixture/" + c.CAMPUS_PROFILE_FILE, '{broken');
  c.loadCampusProfile();
  assert.equal(c.campusReady(), false);
  assert.equal(c.periodCount(), 0);
  assert.deepEqual(sources.module.commonClassTime, [['--:--', '--:--']]);
  assert.throws(() => c.saveCampusProfile({ firstMonday: '2026-09-06', periodsText: '08:10-08:55', source: 'test' }));
});

test('seasonal profiles reload both tables; backups compare both seasons independent of export date', async () => {
  const winter='08:00-08:50\n14:00-14:50';
  const summer='08:00-08:50\n14:30-15:20';
  c.saveCampusProfile({firstMonday:'2026-08-31',periodsText:winter,summerPeriodsText:summer,source:'Synthetic seasonal fixture'});
  c.loadCampusProfile();
  assert.equal(c.periodsForDate(Date.parse('2026-09-30T23:59:59+08:00'))[2][0],'14:30');
  assert.equal(c.periodsForDate(Date.parse('2026-10-01T00:00:00+08:00'))[2][0],'14:00');
  assert.equal(c.periodsForDate(Date.parse('2027-04-30T23:59:59+08:00'))[2][0],'14:00');
  assert.equal(c.periodsForDate(Date.parse('2027-05-01T00:00:00+08:00'))[2][0],'14:30');
  const backup=fixture();
  backup.scheduleVersion='sust-xian-2-seasonal';
  backup.periods=[['08:00','08:50'],['14:00','14:50']];
  backup.summerPeriods=[['08:00','08:50'],['14:30','15:20']];
  backup.semesters[0].attribute.totalWeekNum=20;
  backup.semesters[0].attribute.calendarWeekCount=20;
  for(const date of ['2026-08-31','2026-10-01']) {
    c.refreshCampusTimes(Date.parse(date+'T00:00:00+08:00'));
    assert.equal(validate(backup),'');
  }
  backup.summerPeriods[1][0]='14:31';assert.notEqual(validate(backup),'');
  assert.throws(()=>c.saveCampusProfile({firstMonday:'2026-08-31',periodsText:winter,summerPeriodsText:'14:30-15:20',source:'x'}));
  assert.equal(c.getCampusProfile().summerPeriodsText,summer);
  const times=c.periodsForDate(Date.parse('2026-10-01T00:00:00+08:00'));times[2][0]='00:00';
  assert.equal(c.periodsForDate(Date.parse('2026-10-01T00:00:00+08:00'))[2][0],'14:00');
});
