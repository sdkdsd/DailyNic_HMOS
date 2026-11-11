// Synthetic test fixtures only: these dates/times are NOT SUST's timetable.
import test from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { parseMonday, chinaDayStart, chinaWeekday, mondayStart, mondayOffset,
  teachingWeek, classTimestamp, parsePeriods, clockStamp, expandWeeks } from '../entry/src/main/ets/utils/CampusTime.ts';

const first = parseMonday('2026-09-07');
test('academic week rolls at Monday 00:00 China, never at Sunday or after midnight', () => {
  assert.equal(teachingWeek(first - 1, first), 0);
  assert.equal(teachingWeek(first, first), 1);
  assert.equal(teachingWeek(Date.parse('2026-09-13T23:59:59+08:00'), first), 1);
  assert.equal(teachingWeek(Date.parse('2026-09-14T00:00:00+08:00'), first), 2);
  assert.equal(mondayStart(Date.parse('2026-09-13T23:59:59+08:00')), first);
});
test('all seven days round trip between JS weekday, grid column and calendar timestamp', () => {
  for (let column = 0; column < 7; column++) {
    const day = (column + 1) % 7;
    const stamp = classTimestamp(first, 2, day, clockStamp('10:15'));
    assert.equal(mondayOffset(day), column);
    assert.equal(chinaWeekday(stamp), day);
    assert.equal(teachingWeek(stamp, first), 2);
    assert.equal(chinaDayStart(stamp), first + (7 + column) * 86400000);
    assert.equal(stamp - chinaDayStart(stamp), 36900000);
  }
});
test('tomorrow switches week on Sunday, including last term day', () => {
  for (const date of ['2026-09-12', '2026-09-13', '2026-12-31']) {
    const now = Date.parse(date + 'T12:00:00+08:00');
    const day = chinaWeekday(now);
    assert.equal(teachingWeek(now, first) + (day === 0 ? 1 : 0), teachingWeek(now + 86400000, first));
    assert.equal((day + 1) % 7, chinaWeekday(now + 86400000));
  }
});
test('date rules reject invalid / Sunday / normalized-overflow dates', () => {
  for (const date of ['', '2026-9-7', '2026-09-06', '2026-02-30', 'wrong']) assert.throws(() => parseMonday(date));
  assert.throws(() => classTimestamp(first, 0, 1, 0));
  assert.throws(() => classTimestamp(first, 1, 7, 0));
  assert.throws(() => classTimestamp(first + 1, 1, 1, 0));
  assert.throws(() => classTimestamp(first, 1, 1, 86400000));
});
test('periods have no inferred defaults and reject malformed/overlapping/reversed times', () => {
  assert.deepEqual(parsePeriods('08:10-08:55\r\n09:05-09:50'), [['08:10', '08:55'], ['09:05', '09:50']]);
  for (const text of ['', '8:10-08:55', '24:00-24:30', '09:00-08:00', '09:00-09:00', '08:00-09:00\n08:50-09:30', '08:00-08:45\n\n09:00-09:45']) {
    assert.throws(() => parsePeriods(text), text);
  }
});
test('single/double weeks are academic week parity, including mixed ranges', () => {
  assert.deepEqual(expandWeeks('1-8(单)'), [1, 3, 5, 7]);
  assert.deepEqual(expandWeeks('1~8周（双周），9,11-12'), [2, 4, 6, 8, 9, 11, 12]);
  assert.deepEqual(expandWeeks('2-7(单),1,3'), [1, 3, 5, 7]);
  assert.deepEqual(expandWeeks('28-30(双)'), [28, 30]);
  for (const text of ['0-3', '3-1', '1-31', '1-8(奇)', '1,,2', '2(单)', '全部', 'NaN']) assert.throws(() => expandWeeks(text));
});
test('China academic calculations are independent of host/device timezone', () => {
  const moduleURL = new URL('../entry/src/main/ets/utils/CampusTime.ts', import.meta.url).href;
  const code = `import {parseMonday,teachingWeek,chinaWeekday,classTimestamp} from ${JSON.stringify(moduleURL)}; const d=parseMonday('2026-09-07'); console.log(JSON.stringify([d,teachingWeek(d+6*86400000,d),chinaWeekday(d),classTimestamp(d,1,0,36000000)]));`;
  const results = ['UTC', 'Asia/Shanghai', 'America/New_York', 'Asia/Tokyo'].map(TZ =>
    execFileSync(process.execPath, ['--input-type=module', '-e', code], { env: { ...process.env, TZ }, encoding: 'utf8' }));
  assert.equal(new Set(results).size, 1);
});
