import test from 'node:test';
import assert from 'node:assert/strict';
import { asURL, loadLogic } from './logic-loader.mjs';
const storageURL=asURL(`export let saved=[],fail=false;export const getExams=()=>saved;export const setExams=v=>{if(fail)throw Error('disk failed');saved=v;};export const setFail=v=>{fail=v;};`);
const {module:{default:manager}}=await loadLogic('utils/ExamManager.ets',{
  './ExamStorage':storageURL,'./CampusTime':new URL('../entry/src/main/ets/utils/CampusTime.ts',import.meta.url).href
});
const storage=await import(storageURL);
const exam={id:'',type:'',name:'Synthetic',date:'2026-09-13 09:00~11:00',building:'',classroom:'',campus:'',info:'',importance:5};
test('manual exam CRUD validates before replacement and isolates the edit draft',()=>{
  manager.addExam(exam);
  assert.equal(manager.allExamInfo[0].beginTimeStamp,Date.parse('2026-09-13T09:00:00+08:00'));
  assert.notEqual(manager.allExamInfo[0],exam);
  assert.throws(()=>manager.replaceExam(exam,{...exam,date:'2026-09-13 24:00~26:00'}));
  assert.equal(storage.saved.length,1);
  manager.replaceExam(exam,{...exam,name:'Updated'});
  assert.equal(storage.saved[0].name,'Updated');
  manager.deleteExam(storage.saved[0]);
  assert.equal(storage.saved.length,0);
});
test('failed exam persistence preserves old in-memory and stored values',()=>{
  manager.addExam(exam);storage.setFail(true);
  assert.throws(()=>manager.replaceExam(exam,{...exam,name:'Lost'}),/disk/);
  assert.equal(manager.allExamInfo[0].name,'Synthetic');
  assert.equal(storage.saved[0].name,'Synthetic');
  storage.setFail(false);manager.deleteExam(exam);
});
