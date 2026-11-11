import test from 'node:test';
import assert from 'node:assert/strict';
import { asURL, loadLogic } from './logic-loader.mjs';
globalThis.$r = text=>text;
const timeURL=new URL('../entry/src/main/ets/utils/CampusTime.ts',import.meta.url).href;
const configURL=asURL(`export let ready=true;export const setReady=v=>{ready=v;};export const campusReady=()=>ready,initCampusProfile=()=>{};export const classTimes=[['--:--','--:--'],['08:10','08:55']];`);
const scheduleURL=asURL(`export default {init:()=>{},defaultSemester:0,semesters:[{beginTime:Date.parse('2026-09-07T00:00:00+08:00'),totalWeekNum:3}],getDefaultClassByDay:(week,day)=>week>=1&&week<=3?[{name:week+'-'+day,timeSpan:[1]}]:[]};`);
const examURL=asURL(`export default {readStoredExam:()=>{},allExamInfo:[{name:'old',endTimeStamp:0},{name:'future',endTimeStamp:Date.parse('2027-01-01T00:00:00+08:00')}]};`);
const todoURL=asURL(`export const init=()=>{},TodoType={Assignment:1};export const getEffectiveTime=i=>i.ddl||0,getUnfinished=()=>[{item:{text:'Synthetic',type:1,ddl:Date.parse('2026-09-01T00:00:00+08:00'),done:false}}];`);
const deps={
 '../utils/CampusConfig':configURL,'../utils/CampusTime':timeURL,
 '@kit.AbilityKit':asURL('export const Want=undefined;'),
 '@kit.PerformanceAnalysisKit':asURL('export const hilog={info:()=>{},error:()=>{}};'),
 '@kit.FormKit':asURL('export class FormExtensionAbility{};export const formBindingData={},formInfo={},formProvider={};'),
 '../utils/Classes/ScheduleManager':scheduleURL,
 '../utils/ScheduleStorage':asURL('export const init=()=>{};'),
 '../constants/ScheduleSources':asURL(''),
 '../utils/ExamStorage':asURL('export const examAttribute=undefined,init=()=>{};'),
 '../utils/ExamManager':examURL,
 '../utils/UnifyPreference':asURL('export const millisecondsPerWeek=604800000;export default {init:()=>{},getNumberSync:()=>0};'),
 '@kit.LocalizationKit':asURL('export const i18n={System:{is24HourClock:()=>true}};'),
 '../utils/TodoStorage':todoURL,
 '../todo_info/viewmodel/TodoCardItem':asURL('export const TodoCardItem=undefined;')
};
const {module:{FormDataClass}}=await loadLogic('entryformability/EntryFormAbility.ets',deps);
const config=await import(configURL);
test('widget data covers term-start eve, Sunday roll-over, term-end and unconfigured state',()=>{
 let data=new FormDataClass(0,Date.parse('2026-09-06T23:00:00+08:00'));
 assert.deepEqual(data.todayCourse,[]);assert.equal(data.tomorrowCourse[0].name,'1-1');
 data=new FormDataClass(0,Date.parse('2026-09-13T23:00:00+08:00'));
 assert.equal(data.todayCourse[0].name,'1-0');assert.equal(data.tomorrowCourse[0].name,'2-1');
 data=new FormDataClass(0,Date.parse('2026-09-27T23:00:00+08:00'));
 assert.equal(data.todayCourse[0].name,'3-0');assert.deepEqual(data.tomorrowCourse,[]);
 config.setReady(false);data=new FormDataClass(0,Date.parse('2026-09-13T23:00:00+08:00'));
 assert.equal(data.campusConfigured,false);assert.deepEqual(data.todayCourse,[]);assert.deepEqual(data.tomorrowCourse,[]);
 config.setReady(true);
});
test('exam and todo widget payloads filter expired exams and expose unfinished work',()=>{
 const now=Date.parse('2026-09-13T12:00:00+08:00');
 const exams=new FormDataClass(1,now);assert.equal(exams.count,1);assert.equal(exams.examInfo[0].name,'future');
 const todo=new FormDataClass(2,now);assert.equal(todo.count,1);assert.equal(todo.todoList[0].overdue,true);
});
