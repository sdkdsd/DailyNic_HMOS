import test from 'node:test';
import assert from 'node:assert/strict';
import { asURL, loadLogic } from './logic-loader.mjs';
const storageURL = asURL(`
  export let semesters = []; export const courses = new Map(); export let defaultIndex = 0;
  export const isReady=()=>true, getSemesters=()=>semesters, setSemesters=v=>{semesters=v;};
  export const getDefaultSemester=()=>defaultIndex, setDefaultSemester=v=>{defaultIndex=v;};
  export const getCourses=k=>courses.get(k)||[], setCourses=(k,v)=>courses.set(k,v);
`);
const profileURL = asURL(`export let ready=false; export const setReady=v=>{ready=v;}; export const campusReady=()=>ready; export const firstTeachingMonday=()=>ready?Date.parse('2026-09-07T00:00:00+08:00'):0;`);
// Type-only symbols are left as imports by Node's syntax stripper (ArkTS resolves them as types).
const enumURL = asURL('export const classAttribute=undefined,semesterAttribute=undefined,COVER_MODE={COVER:0,COVER_DUPLICATE:1,APPEND:2};');
const toolsURL = asURL(`export const colorSet=['#FFFFFFFF'],colorSetLen=1,getRandomInt=()=>0,extractCredits=()=>[];`);
const loaded = await loadLogic('utils/Classes/ScheduleManager.ets', {
  '../ScheduleStorage':storageURL, '../CampusConfig':profileURL,
  '../../constants/ScheduleSources':enumURL, '../tools':toolsURL
});
const manager = loaded.module.default;
const storage = await import(storageURL);
const config = await import(profileURL);
test('first launch initializes an empty semester safely without invented dates or courses', () => {
  assert.equal(manager.semesters.length, 1);
  assert.equal(manager.semesters[0].beginTime, 0);
  assert.deepEqual(manager.getDefaultClassByDay(1, 1), []);
  assert.equal(manager.defaultSemester, 0);
});
test('bad saved default index recovers to first semester', () => {
  for (const index of [999, -1, NaN, 0.5]) {
    storage.setDefaultSemester(index);
    manager.init();
    assert.equal(manager.defaultSemester, 0);
  }
});
test('Sunday remains in its teaching week; odd-week course does not appear in even weeks', () => {
  config.setReady(true);
  const course = {name:'Synthetic',teacher:'',location:'',id:'',color:'#FFFFFFFF',priority:5,credits:'',dayOfWeek:0,timeSpan:[1],weekOfTerm:[1,3]};
  const id = manager.semesters[0].createTime;
  storage.setCourses(id,[course]);
  manager.init();
  assert.equal(manager.getDefaultClassByDay(1,0).length,1);
  assert.equal(manager.getDefaultClassByDay(2,0).length,0);
  assert.equal(manager.getDefaultClassByDay(3,0).length,1);
  assert.equal(manager.getDefaultClassByDay(1,1).length,0);
  config.setReady(false);
  assert.deepEqual(manager.getDefaultClassByDay(1,0),[]);
});
