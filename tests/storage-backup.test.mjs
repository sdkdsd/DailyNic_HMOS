import test from 'node:test';
import assert from 'node:assert/strict';
import { asURL, loadLogic } from './logic-loader.mjs';
const fsURL=asURL(`export const files=new Map(),closed=[],removed=[];export let failRename=false,partial=false;
export const setFail=v=>{failRename=v;},setPartial=v=>{partial=v;};
export const fileIo={OpenMode:{READ_ONLY:0,WRITE_ONLY:1,CREATE:2,TRUNC:4},accessSync:p=>files.has(p),readTextSync:p=>files.get(p),mkdirSync:()=>{},
openSync:(p,mode)=>({fd:p}),writeSync:(p,data)=>{const b=typeof data==='string'?Buffer.from(data):Buffer.from(data);files.set(p,b.toString());return partial?b.length-1:b.length;},closeSync:f=>closed.push(f.fd),fsyncSync:()=>{},
renameSync:(a,b)=>{if(failRename)throw Error('injected disk failure');files.set(b,files.get(a));files.delete(a);},
statSync:p=>({size:Buffer.byteLength(files.get(p)||'')}),readSync:(p,b)=>{const src=Buffer.from(files.get(p));new Uint8Array(b).set(src);return partial?src.length-1:src.length;},unlinkSync:p=>{removed.push(p);files.delete(p);}};`);
const fs=await import(fsURL);
const types=asURL('export const classAttribute=undefined,semesterAttribute=undefined,exportSemester=undefined;');
const {module:schedule}=await loadLogic('utils/ScheduleStorage.ets',{'@kit.CoreFileKit':fsURL,'../constants/ScheduleSources':types});
const {module:exam}=await loadLogic('utils/ExamStorage.ets',{'@kit.CoreFileKit':fsURL});
const {module:todo}=await loadLogic('utils/TodoStorage.ets',{'@kit.CoreFileKit':fsURL});
const utilURL=asURL(`export const util={TextDecoder:{create:(e,o)=>({decodeWithStream:b=>new TextDecoder(e,o).decode(b)})},TextEncoder:class{encodeInto(t){return new TextEncoder().encode(t);}}};`);
const {module:backup}=await loadLogic('utils/DocumentBackup.ets',{'@kit.CoreFileKit':fsURL,'@kit.ArkTS':utilURL});
test('schedule backup appends atomically with unique IDs and preserves term length',()=>{
  schedule.init({filesDir:'/schedule'});
  const semester={attribute:{name:'synthetic',source:'test',createTime:1,beginTime:1,totalWeekNum:16},courses:[]};
  assert.equal(schedule.appendBackup([semester,semester]),0);
  const saved=fs.files.get('/schedule/scheduleData.json');
  assert.equal(schedule.getSemesters().length,2);
  assert.equal(schedule.getSemesters()[0].totalWeekNum,16);
  assert.notEqual(schedule.getSemesters()[0].createTime,schedule.getSemesters()[1].createTime);
  fs.setFail(true);assert.throws(()=>schedule.appendBackup([semester]));fs.setFail(false);
  assert.equal(fs.files.get('/schedule/scheduleData.json'),saved);
  assert.equal(schedule.getSemesters().length,2);
  schedule.init({filesDir:'/schedule'},true);
  assert.equal(schedule.getSemesters().length,2);
});
test('exam atomic write failure preserves file and cache and closes the temporary descriptor',()=>{
  exam.init({filesDir:'/exam'});exam.setExams([{name:'old'}]);
  fs.setFail(true);assert.throws(()=>exam.setExams([{name:'new'}]));fs.setFail(false);
  assert.equal(exam.getExams()[0].name,'old');
  assert.equal(JSON.parse(fs.files.get('/exam/examData.json'))[0].name,'old');
  assert.ok(fs.closed.includes('/exam/examData.json.tmp'));
});
test('todo CRUD survives reload; failed saves retain data and referenced images',()=>{
  todo.init({filesDir:'/todo'});
  const item={type:0,text:'synthetic',done:false,submitted:false,channels:[],imagePaths:['/todo/todoImages/shared']};
  fs.files.set(item.imagePaths[0],'image');todo.addItem(item);todo.addItem(item);
  todo.removeItem(0);assert.equal(fs.removed.includes(item.imagePaths[0]),false);
  fs.setFail(true);assert.throws(()=>todo.updateItem(0,{...item,done:true,imagePaths:[]}));fs.setFail(false);
  assert.equal(todo.getItems()[0].done,false);assert.equal(fs.files.has(item.imagePaths[0]),true);
  todo.updateItem(0,{...item,done:true});todo.init({filesDir:'/todo'},true);
  assert.equal(todo.getItems()[0].done,true);
  todo.removeItem(0);assert.equal(fs.files.has(item.imagePaths[0]),false);
  todo.deleteImage('/outside/private');assert.equal(fs.removed.includes('/outside/private'),false);
});
test('document backup preserves granted URI, Chinese UTF-8 and closes on short IO',()=>{
  const uri='file://docs/authorized/课表.json',text=JSON.stringify({name:'陕西科技大学'});
  backup.writeBackupUri(uri,text);assert.equal(backup.readBackupUri(uri),text);
  fs.setPartial(true);assert.throws(()=>backup.readBackupUri(uri),/不完整/);
  assert.throws(()=>backup.writeBackupUri(uri,text),/未完整/);fs.setPartial(false);
  assert.equal(fs.closed.at(-1),uri);
});
