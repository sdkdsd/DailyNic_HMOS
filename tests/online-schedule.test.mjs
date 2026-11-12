import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import { asURL, loadLogic } from './logic-loader.mjs';
const parser = await loadLogic('utils/SustOnline.ets', {});
const p = parser.module;
const script = (await loadLogic('utils/SustTableScript.ts', {})).module.SUST_READ_TABLE_SCRIPT;
const cell = (text='',rowspan=1) => ({text,rowspan,colspan:1});
const headings=['序号','课程代码','课程名称','学分','课程序号','教师','备注','操作'];
function fixture(kind='学生课表', code='100.01', day=1, start=1, text='(1-4,合成教室)') {
  const data={kind,week:'全部',semester:'2026-2027学年1学期',weekCount:20,
    catalog:[headings,['1','100','合成课程','2',code,'合成教师','','']],rows:[]};
  data.rows.push(['节次/周次',...'一二三四五六日'].map((s,i)=>cell(i?'星期'+s:s)));
  const labels=['一','二','三','四','五','六','七','八','九','十','十一'];
  for(let n=1;n<=11;n++) {
    const row=[cell('第'+labels[n-1]+'节')];
    for(let d=1;d<=7;d++) {
      if(n===start+1&&d===day)continue;
      row.push(n===start&&d===day?cell(`合成课程(${code}) (合成教师)\n${text}`,2):cell());
    }
    data.rows.push(row);
  }
  return data;
}
test('dynamic table parser handles Sunday, merged periods, week ranges and explicit cancellations',()=>{
  const f=fixture('学生课表','100.01',7,3,'(1 3-8(单),合成教室)\n(3,停课(-2))');
  const r=p.parseVisibleSchedule(f,8);
  assert.deepEqual(r.courses[0].weekOfTerm,[1,5,7]);
  assert.deepEqual(r.courses[0].timeSpan,[3,4]);assert.equal(r.courses[0].dayOfWeek,0);
  assert.equal(r.cancelled.length,1);
  assert.deepEqual(p.parseSchoolWeeks('2-8(双周)',20),[2,4,6,8]);
});
test('personal/class combination deduplicates normalized rooms and rejects conflicts or term mismatch',()=>{
  const a=fixture(),b=fixture('班级课表');b.rows[1][1].text=b.rows[1][1].text.replace('合成教室)','合成教室(401D502)');
  assert.equal(p.combineOnline(a,b,8).duplicates,1);
  const extra=fixture('班级课表','200.01',5,7);
  assert.equal(p.combineOnline(a,extra,8).courses.length,2);
  assert.throws(()=>p.combineOnline(a,fixture('班级课表','200.01'),8),/冲突/);
  extra.semester='2027-2028学年1学期';assert.throws(()=>p.combineOnline(a,extra,8),/同一学期/);
});
test('unknown, partial, empty, filtered and unsupported evening tables cannot clear old data',()=>{
  const changes=[f=>f.week='第1周',f=>f.rows.pop(),f=>f.rows[1].pop(),f=>f.rows[1][1].text+='\n未知信息',
    f=>f.catalog[1][5]='不匹配',f=>f.weekCount=0,f=>f.rows[1][1].rowspan=0,f=>f.rows[1][1].text=''];
  for(const change of changes){const f=fixture();change(f);assert.throws(()=>p.parseVisibleSchedule(f,8));}
  assert.throws(()=>p.parseVisibleSchedule(fixture('学生课表','100.01',1,9),8),/节次/);
  assert.throws(()=>p.parseSchoolWeeks('20-21',20));
});
test('DOM reader extracts table data without touching credentials, account links or storage',()=>{
  const f=fixture();const render=rows=>({getClientRects:()=>[1],rows:rows.map(r=>({cells:r.map(c=>({innerText:c.text,rowSpan:c.rowspan,colSpan:c.colspan}))}))});
  const grid=render(f.rows),catalog=render(f.catalog.map(r=>r.map(t=>cell(t))));
  const select=text=>({getClientRects:()=>[1],selectedOptions:[{text}],options:[{text:'全部'},...Array.from({length:20},(_,i)=>({text:`第${i+1}周`}))]});
  const ctx={location:{origin:'https://bkjw.sust.edu.cn',pathname:'/eams/courseTableForStd.action'},document:{
    getElementById:id=>({courseTableType:select('学生课表'),startWeek:select('全部'),manualArrangeCourseTable:grid}[id]),
    querySelectorAll:q=>q==='table'?[grid,catalog]:q==='input[type="text"][id^="semesterBar"][id$="Semester"]'?[{getClientRects:()=>[1],value:f.semester}]:assert.fail('unexpected selector '+q)}};
  Object.defineProperty(ctx.document,'cookie',{get(){assert.fail('cookie access');}});
  const result=JSON.parse(vm.runInNewContext(script,ctx));
  assert.deepEqual(result,f);
  ctx.location.origin='https://login.sust.edu.cn';assert.throws(()=>vm.runInNewContext(script,ctx));
  for(const url of ['http://bkjw.sust.edu.cn/eams/','https://bkjw.sust.edu.cn.evil.test/','https://login.sust.edu.cn@evil.test/','javascript:alert(1)']) assert.equal(p.schoolNavigationAllowed(url),false);
  assert.equal(p.schoolNavigationAllowed('https://login.sust.edu.cn/cas/login'),true);
  assert.equal(p.schedulePageAllowed('https://bkjw.sust.edu.cn/eams/stdElectCourse.action'),false);
});
const fsURL=asURL(`export const files=new Map();export let fail=false;export function setFail(v){fail=v;}
export const fileIo={OpenMode:{WRITE_ONLY:1,CREATE:2,TRUNC:4},accessSync:p=>files.has(p),readTextSync:p=>files.get(p),
openSync:p=>({fd:p}),writeSync:(p,s)=>files.set(p,s),fsyncSync:()=>{},closeSync:()=>{},renameSync:(a,b)=>{if(fail)throw Error('disk');files.set(b,files.get(a));files.delete(a)}};`);
const fs=await import(fsURL);
const timeURL=new URL('../entry/src/main/ets/utils/CampusTime.ts',import.meta.url).href;
const config=await loadLogic('utils/CampusConfig.ets',{'@kit.CoreFileKit':fsURL,'./CampusTime':timeURL});
const prefURL=asURL('export default {};');
const sources=await loadLogic('constants/ScheduleSources.ets',{'../utils/UnifyPreference':prefURL,'../utils/CampusConfig':config.url,'../utils/CampusTime':timeURL});
const types=asURL('export const classAttribute=undefined,semesterAttribute=undefined,exportSemester=undefined;');
const storage=await loadLogic('utils/ScheduleStorage.ets',{'@kit.CoreFileKit':fsURL,'../constants/ScheduleSources':types});
const sync=(await loadLogic('utils/OnlineSchedule.ets',{'./SustOnline':parser.url,'../constants/ScheduleSources':sources.url,
  './CampusConfig':config.url,'./CampusTime':timeURL,'./ScheduleStorage':storage.url})).module;
function init(){config.module.initCampusProfile({filesDir:'/online'});config.module.saveCampusProfile({firstMonday:'2026-08-31',periodsText:Array.from({length:8},(_,i)=>`${String(i+8).padStart(2,'0')}:00-${String(i+8).padStart(2,'0')}:50`).join('\n'),source:'synthetic'});storage.module.init({filesDir:'/online'},true);storage.module.clearScheduleData();}
test('preview does not write; repeated fetch updates one semester, new term adds another, data survives reload',()=>{
  init();const a=fixture(),b=fixture('班级课表');
  const preview=sync.prepareOnlineSchedule(a,b,'2026-08-31');assert.equal(storage.module.getSemesters().length,0);
  sync.confirmOnlineSchedule(preview,true);const id=storage.module.getSemesters()[0].createTime;
  a.rows[1][1].text=a.rows[1][1].text.replace('合成教室','新教室');b.rows[1][1].text=a.rows[1][1].text;
  const update=sync.prepareOnlineSchedule(a,b,'2026-08-31');assert.equal(update.added,1);assert.equal(update.removed,1);
  sync.confirmOnlineSchedule(update,true);assert.equal(storage.module.getSemesters().length,1);assert.equal(storage.module.getSemesters()[0].createTime,id);
  storage.module.init({filesDir:'/online'},true);assert.equal(storage.module.getCourses(id)[0].location,'新教室');
  a.semester=b.semester='2027-2028学年1学期';sync.confirmOnlineSchedule(sync.prepareOnlineSchedule(a,b,'2027-08-30'),false);
  assert.equal(storage.module.getSemesters().length,2);assert.equal(storage.module.getDefaultSemester(),0);
});
test('manual additions survive; edits, stale previews and disk failures preserve the saved timetable',()=>{
  init();const a=fixture(),b=fixture('班级课表');sync.confirmOnlineSchedule(sync.prepareOnlineSchedule(a,b,'2026-08-31'),true);
  const id=storage.module.getSemesters()[0].createTime;const courses=storage.module.getCourses(id);
  courses.push({...courses[0],id:'manual',dayOfWeek:6});storage.module.setCourses(id,courses);
  const preview=sync.prepareOnlineSchedule(a,b,'2026-08-31');assert.equal(preview.backup.semesters[0].courses.length,2);
  const before=fs.files.get('/online/scheduleData.json');fs.setFail(true);assert.throws(()=>sync.confirmOnlineSchedule(preview,true));fs.setFail(false);
  assert.equal(fs.files.get('/online/scheduleData.json'),before);
  courses[0].location='本地修改';storage.module.setCourses(id,courses);
  assert.throws(()=>sync.confirmOnlineSchedule(preview,true),/已改变/);
  assert.throws(()=>sync.prepareOnlineSchedule(a,b,'2026-08-31'),/本地编辑/);
  assert.equal(storage.module.getCourses(id)[0].location,'本地修改');
});
test('term metadata edits preserve online baseline and cancellation on the class page removes personal stale weeks',()=>{
  init();const a=fixture(),b=fixture('班级课表');b.rows[1][1].text+='\n(2,停课(-2))';
  const pending=sync.prepareOnlineSchedule(a,b,'2026-08-31');assert.deepEqual(pending.backup.semesters[0].courses[0].weekOfTerm,[1,3,4]);
  sync.confirmOnlineSchedule(pending,true);const attrs=storage.module.getSemesters();attrs[0].name='改名';storage.module.setSemesters(attrs);
  assert.ok(storage.module.getOnlineSemester(a.semester).onlineCourses);
  assert.doesNotThrow(()=>sync.prepareOnlineSchedule(a,b,'2026-08-31'));
  storage.module.appendBackup(pending.backup.semesters);
  assert.equal(storage.module.getSemesters()[1].onlineTerm,undefined);
  assert.doesNotThrow(()=>sync.prepareOnlineSchedule(a,b,'2026-08-31'));
});
test('online page uses a temporary WebView with no native proxy or automatic login',()=>{
  const source=readFileSync(new URL('../entry/src/main/ets/pages/GetSchedule.ets',import.meta.url),'utf8');
  assert.match(source,/incognitoMode: true/);assert.match(source,/handleCancel\(\)/);
  assert.doesNotMatch(source,/fetchCookie|configCookie|javaScriptProxy|registerJavaScriptProxy|fetch\(/);
});
