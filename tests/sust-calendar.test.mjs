import test from 'node:test';
import assert from 'node:assert/strict';
import {parseMonday, teachingWeek, isSummerDate, parsePeriods} from '../entry/src/main/ets/utils/CampusTime.ts';
import {SUST_FIRST_MONDAY, SUST_TERM_WEEKS, SUST_WINTER_PERIODS, SUST_SUMMER_PERIODS} from '../entry/src/main/ets/utils/SustCalendar.ts';
test('provided official calendar maps week 1 through week 20 across the year boundary',()=>{
 const first=parseMonday(SUST_FIRST_MONDAY);
 assert.equal(first,Date.parse('2026-08-31T00:00:00+08:00'));
 assert.equal(SUST_TERM_WEEKS,20);
 for(const [date,week] of [['2026-08-30',0],['2026-08-31',1],['2026-09-06',1],['2026-11-12',11],['2027-01-17',20],['2027-01-18',21]])
  assert.equal(teachingWeek(Date.parse(date+'T12:00:00+08:00'),first),week);
});
test('seasonal boundaries use Beijing midnight rather than runtime timezone',()=>{
 assert.equal(isSummerDate(Date.parse('2026-09-30T15:59:59Z')),true);
 assert.equal(isSummerDate(Date.parse('2026-09-30T16:00:00Z')),false);
 assert.equal(isSummerDate(Date.parse('2027-04-30T15:59:59Z')),false);
 assert.equal(isSummerDate(Date.parse('2027-04-30T16:00:00Z')),true);
 assert.equal(isSummerDate(Date.parse('2027-01-01T00:00:00Z')),false);
 assert.throws(()=>isSummerDate(NaN));
});
test('personal screenshots map the same morning and distinct afternoon to both seasons',()=>{
 const winter=parsePeriods(SUST_WINTER_PERIODS),summer=parsePeriods(SUST_SUMMER_PERIODS);
 assert.equal(winter.length,8);assert.equal(summer.length,8);
 assert.deepEqual(winter.slice(0,4),summer.slice(0,4));
 assert.deepEqual(winter[4],['14:00','14:50']);assert.deepEqual(summer[4],['14:30','15:20']);
 assert.equal(winter[8],undefined);assert.equal(summer[8],undefined); // disputed evening lengths are not guessed
});
