import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import { asURL, loadLogic } from './logic-loader.mjs';
const { module: logic, url: logicURL } = await loadLogic('utils/LearningTasks.ts', {});
const { module: script } = await loadLogic('utils/LearningScript.ts', {});
const now = Date.parse('2026-11-12T12:00:00+08:00');
const row = (id = '101', status = '未提交', remaining = '1天2小时3分钟') =>
  ({ id, title: '合成作业', course: '合成课程', status, remaining });
const page = (rows = [row()], kind = 'homework') => ({ kind, rows });

test('learning deadlines preserve Beijing time, zero remaining and unknown due dates', () => {
  assert.equal(logic.learningTime(now), '2026-11-12 12:00');
  assert.equal(logic.learningDeadline('1天2小时3分钟', now), now + 93780000);
  assert.equal(logic.learningDeadline('0分钟', now), now);
  assert.equal(logic.learningDeadline('剩余82小时1分钟', now), now + 82 * 3600000 + 60000);
  assert.equal(logic.learningDeadline('剩余1594小时1分钟', now), now + 1594 * 3600000 + 60000);
  assert.equal(logic.learningDeadline('', now), 0);
  for (const value of ['下周五', '-1天', '1小时2小时', '731天', '60分钟'])
    assert.throws(() => logic.learningDeadline(value, now));
});

test('source IDs separate exams from homework and repeated reads update rather than duplicate', () => {
  let s = logic.mergeLearningPage(logic.emptyLearningSnapshot(), page(), now);
  s = logic.mergeLearningPage(s, page([row('101', '未提交', '2天')]), now + 1000);
  assert.equal(s.tasks.length, 1);
  assert.equal(s.tasks[0].dueAt, now + 1000 + 2 * 86400000);
  s = logic.mergeLearningPage(s, page([row('101', '未开始')], 'exam'), now + 2000);
  assert.equal(s.tasks.length, 2);
  assert.equal(logic.pendingLearningTasks(s).length, 2);
});

test('unsubmitted exams remain actionable without inventing a deadline or completed status', () => {
  const tasks = logic.parseLearningPage(page([row('202', '未交', ''), row('203', '未提交', '')], 'exam'), now);
  assert.equal(tasks.length, 2);
  assert.ok(tasks.every(t => t.active && t.dueAt === 0));
});

test('waiting or reading twice does not move a server-rendered deadline; stale pages must refresh', () => {
  const loadedAt = now - 120000;
  const first = logic.parseLearningPage(page(), logic.learningReadTime(loadedAt, now));
  const second = logic.parseLearningPage(page(), logic.learningReadTime(loadedAt, now + 60000));
  assert.equal(first[0].dueAt, second[0].dueAt);
  assert.equal(first[0].observedAt, loadedAt);
  for (const [loaded, read] of [[0, now], [now + 1, now], [now - 300001, now], [NaN, now]])
    assert.throws(() => logic.learningReadTime(loaded, read), /stalePage/);
});

test('explicit submitted or ended statuses retire tasks, absent rows retain prior observed state', () => {
  let s = logic.mergeLearningPage(logic.emptyLearningSnapshot(), page([row('1'), row('2')]), now);
  s = logic.mergeLearningPage(s, page([row('1', '待批阅')]), now + 1000);
  assert.deepEqual(logic.pendingLearningTasks(s).map(x => x.id), ['homework:2']);
  assert.equal(s.tasks.find(x => x.id === 'homework:2').observedAt, now);
  s = logic.mergeLearningPage(s, page([row('2', '已结束')]), now + 2000);
  assert.equal(logic.pendingLearningTasks(s).length, 0);
  assert.equal(s.tasks.find(x => x.id === 'homework:2').status, '已结束');
});

test('empty, partial malformed, unknown statuses and duplicate IDs reject the entire read', () => {
  for (const p of [page([]), page([row(), row()]), page([row(), row('2', '未知')]),
    page([row('bad')]), page([{...row(), title: ''}]), {...page(), readError: 'origin'}])
    assert.throws(() => logic.parseLearningPage(p, now));
  assert.throws(() => logic.validateLearningSnapshot({...logic.emptyLearningSnapshot(), tasks: [null]}));
});

function readDOM(kind, cards, origin = 'https://mooc1-api.chaoxing.com', path) {
  const cardNodes = cards.map(({url, label}) => ({
    getAttribute: name => name === 'data' ? url : null,
    querySelectorAll: selector => {
      assert.equal(selector, '[aria-label]');
      return [{getAttribute: name => name === 'aria-label' ? label : null}];
    }
  }));
  const document = {readyState: 'complete', querySelectorAll: selector => {
    assert.equal(selector, 'li[data]'); return cardNodes;
  }};
  Object.defineProperty(document, 'cookie', {get() {throw Error('must not access cookies');}});
  return JSON.parse(vm.runInNewContext(script.LEARNING_READ_SCRIPT, {URL, document,
    location: {origin, pathname: path ?? (kind === 'homework' ? '/work/stu-work' : '/exam-ans/exam/phone/examcode')}}));
}
test('DOM reader extracts metadata only from supported per-card labels', () => {
  const p = readDOM('homework', [{url: 'https://mooc1-api.chaoxing.com/mooc-ans/android/mtaskmsgspecial?taskrefId=101&secret=not-exported',
    label: '作业名称合成作业作业状态未提交所属课程《合成课程》剩余时间1天2小时3分钟'}]);
  assert.deepEqual(p, page());
  assert.doesNotMatch(JSON.stringify(p), /secret|not-exported/);
  const e = readDOM('exam', [{url: '/exam-ans/exam/phone/task-exam?taskrefId=202',
    label: '考试名称：合成考试; 考试状态：未开始; 剩余时间：2小时'}]);
  assert.equal(logic.parseLearningPage(e, now)[0].kind, 'exam');
  assert.equal(e.rows[0].course, '');
});
test('DOM reader rejects wrong origin/routes and empty or changed structures', () => {
  assert.equal(readDOM('homework', [], 'https://example.org').readError, 'origin');
  assert.equal(readDOM('homework', [], undefined, '/login').readError, 'path');
  assert.equal(readDOM('homework', []).readError, 'empty');
  assert.equal(readDOM('homework', [{url:'/mooc-ans/android/mtaskmsgspecial?taskrefId=1', label:'changed'}]).readError, 'structure');
  for (const url of ['http://i.chaoxing.com/', 'https://i.chaoxing.com.evil.test/', 'https://i.chaoxing.com@evil.test/', 'file:///private', 'https://i.chaoxing.com:8443/'])
    assert.equal(logic.learningNavigationAllowed(url), false);
  assert.equal(logic.learningNavigationAllowed('https://passport2.chaoxing.com/login'), true);
});

const fsURL = asURL(`export const files=new Map();let failure=false,partial=false;
export const setFailure=v=>failure=v,setPartial=v=>partial=v;
export const fileIo={OpenMode:{WRITE_ONLY:1,CREATE:2,TRUNC:4},accessSync:p=>files.has(p),readTextSync:p=>files.get(p),
openSync:p=>({fd:p}),writeSync:(p,s)=>files.set(p,partial?s.slice(0,-1):s),fsyncSync:()=>{},closeSync:()=>{},
renameSync:(a,b)=>{if(failure)throw Error('disk');files.set(b,files.get(a));files.delete(a);}};`);
const fs = await import(fsURL);
const { module: storage } = await loadLogic('utils/LearningStorage.ets', {'@kit.CoreFileKit':fsURL,'./LearningTasks':logicURL});
test('preview writes nothing; atomic failure and stale concurrent previews preserve cached tasks', () => {
  storage.initLearningStorage({filesDir:'/learning'});
  const first = storage.prepareLearningUpdate(page(), now);
  assert.equal(fs.files.has('/learning/learningTasks.json'), false);
  storage.confirmLearningUpdate(first, now + 1);
  const saved = fs.files.get('/learning/learningTasks.json');
  const next = storage.prepareLearningUpdate(page([row('101', '待批阅')]), now + 2);
  fs.setFailure(true); assert.throws(() => storage.confirmLearningUpdate(next, now + 3)); fs.setFailure(false);
  assert.equal(fs.files.get('/learning/learningTasks.json'), saved);
  fs.setPartial(true); assert.throws(() => storage.confirmLearningUpdate(next, now + 3)); fs.setPartial(false);
  assert.equal(fs.files.get('/learning/learningTasks.json'), saved);
  assert.throws(() => storage.confirmLearningUpdate(next, now + 400000));
  storage.confirmLearningUpdate(next, now + 3);
  assert.throws(() => storage.confirmLearningUpdate(first, now + 4));
  storage.initLearningStorage({filesDir:'/learning'});
  assert.equal(storage.getLearningView().tasks.length, 0);
  fs.files.set('/learning/learningTasks.json', '{damaged');
  assert.match(storage.getLearningView().summary, /无法读取/);
  assert.throws(() => storage.prepareLearningUpdate(page(), now + 5));
  assert.equal(fs.files.get('/learning/learningTasks.json'), '{damaged');
});
