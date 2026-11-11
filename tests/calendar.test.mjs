import test from 'node:test';
import assert from 'node:assert/strict';
import { asURL, loadLogic } from './logic-loader.mjs';
const kit = asURL('export const calendarManager={EventType:{NORMAL:0}};');
const timeURL = new URL('../entry/src/main/ets/utils/CampusTime.ts', import.meta.url).href;
const { module: { CalendarSync } } = await loadLogic('utils/CalendarSync.ets', { '@kit.CalendarKit':kit });
const { module: events } = await loadLogic('utils/CalendarEvents.ets', {
  '@kit.CalendarKit':kit, './CampusTime':timeURL,
  '../constants/ScheduleSources':asURL('export const classAttribute=undefined,semesterAttribute=undefined;'),
  './ExamStorage':asURL('export const examAttribute=undefined;')
});
const own = {name:'SustPersonal.class_notification',type:0};
function fixture() {
  const log=[];
  let nextId=1;
  let failWrite=false, failDelete=false;
  const calendars=[];
  const make=account=>({id:nextId++,getAccount:()=>account,
    setConfig:async config=>{log.push(['config',config]);},
    addEvents:async input=>{log.push(['write',input]);if(failWrite)throw Error('injected');}
  });
  const manager={
    getAllCalendars:async()=>{log.push(['list']);return calendars.slice();},
    deleteCalendar:async calendar=>{log.push(['delete',calendar.id]);if(failDelete)throw Error('injected');calendars.splice(calendars.indexOf(calendar),1);},
    createCalendar:async account=>{const c=make(account);calendars.push(c);log.push(['create',c.id]);return c;}
  };
  calendars.push(make({name:'Unrelated personal calendar',type:0}),make(own));
  return {manager,calendars,log,setFailWrite:v=>failWrite=v,setFailDelete:v=>failDelete=v};
}
test('calendar replacement awaits operations, preserves unrelated accounts and is repeatable',async()=>{
  const f=fixture(), writer=new CalendarSync();
  await writer.replace(f.manager,own,[{title:'synthetic'}],'#ffffff',true);
  assert.deepEqual(f.log.map(x=>x[0]),['list','delete','create','config','write']);
  assert.equal(f.calendars.length,2);
  await writer.replace(f.manager,own,[{title:'updated'}],'#ffffff',false);
  assert.equal(f.calendars.length,2);
  await writer.clear(f.manager,[own]);
  assert.equal(f.calendars.length,1);
  assert.equal(f.calendars[0].getAccount().name,'Unrelated personal calendar');
});
test('partial calendar writes are cleaned up and a retry succeeds',async()=>{
  const f=fixture(), writer=new CalendarSync();f.setFailWrite(true);
  await assert.rejects(writer.replace(f.manager,own,[{}],'#ffffff',true),/更新失败/);
  assert.equal(f.calendars.length,1);
  f.setFailWrite(false);
  await writer.replace(f.manager,own,[{}],'#ffffff',true);
  assert.equal(f.calendars.length,2);
});
test('calendar deletion failure never creates a replacement or reports success',async()=>{
  const f=fixture(), writer=new CalendarSync();f.setFailDelete(true);
  await assert.rejects(writer.replace(f.manager,own,[{}],'#ffffff',true));
  assert.equal(f.log.some(x=>x[0]==='create'),false);
  f.setFailDelete(false);
  await writer.clear(f.manager,[own]);
});
test('concurrent calendar operations are rejected until the first one finishes',async()=>{
  const f=fixture(), writer=new CalendarSync();let release;
  f.manager.getAllCalendars=()=>new Promise(resolve=>{release=()=>resolve(f.calendars.slice());});
  const first=writer.replace(f.manager,own,[{}],'#ffffff',true);
  await assert.rejects(writer.clear(f.manager,[own]),/进行中/);
  release(); await first;
});
test('course events use only actual teaching weeks and China Sunday times without mutating input',()=>{
  const course={name:'Synthetic',location:'',timeSpan:[1,2],weekOfTerm:[1,3],dayOfWeek:0};
  const before=JSON.stringify(course);
  const semester={beginTime:Date.parse('2026-09-07T00:00:00+08:00'),totalWeekNum:3};
  const periods=[['--:--','--:--'],['08:10','08:55'],['09:05','09:50']];
  const result=events.courseEvents([course],semester,periods,10);
  assert.deepEqual(result.map(x=>x.startTime),['2026-09-13T08:10:00+08:00','2026-09-27T08:10:00+08:00'].map(Date.parse));
  assert.equal(result[0].endTime,Date.parse('2026-09-13T09:50:00+08:00'));
  assert.equal(JSON.stringify(course),before);
  assert.throws(()=>events.courseEvents([{...course,timeSpan:[3]}],semester,periods,10));
  assert.throws(()=>events.courseEvents([{...course,weekOfTerm:[4]}],semester,periods,10));
});
test('exam events use China timestamps, reject invalid input and support no reminder',()=>{
  const result=events.examEvents([{name:'Synthetic',building:'A',classroom:'1',date:'2026-09-13 08:00~10:00'}],-1);
  assert.equal(result[0].startTime,Date.parse('2026-09-13T08:00:00+08:00'));
  assert.deepEqual(result[0].reminderTime,[]);
  assert.throws(()=>events.examEvents([{date:'2026-09-13 08:00~08:00'}],10));
});
