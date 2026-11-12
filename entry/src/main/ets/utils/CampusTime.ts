// SUST adaptation, 2026-11-12. GPL-3.0-or-later; see LICENSE.
// Pure logic shared by ArkTS and host tests. No school times are assumed.
export const DAY_MS: number = 86400000;
export const WEEK_MS: number = 7 * DAY_MS;
export const CHINA_OFFSET_MS: number = 8 * 3600000;

// Personal seasonal rule: May 1 inclusive through September 30 in Beijing time.
export function isSummerDate(timestamp: number): boolean {
  if (!Number.isFinite(timestamp)) throw new Error('作息日期无效');
  const month = new Date(timestamp + CHINA_OFFSET_MS).getUTCMonth() + 1;
  return month >= 5 && month < 10;
}

export function chinaDayStart(timestamp: number): number {
  return Math.floor((timestamp + CHINA_OFFSET_MS) / DAY_MS) * DAY_MS - CHINA_OFFSET_MS;
}

// Storage keeps JavaScript weekdays: Sunday=0, Monday=1, ..., Saturday=6.
export function chinaWeekday(timestamp: number): number {
  return new Date(timestamp + CHINA_OFFSET_MS).getUTCDay();
}

export function mondayOffset(day: number): number {
  if (!Number.isInteger(day) || day < 0 || day > 6) throw new Error('星期必须为 0–6');
  return (day + 6) % 7;
}

export function mondayStart(timestamp: number): number {
  return chinaDayStart(timestamp) - mondayOffset(chinaWeekday(timestamp)) * DAY_MS;
}

export function parseMonday(text: string): number {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(text)) throw new Error('首周周一须为 YYYY-MM-DD');
  const stamp = Date.parse(text + 'T00:00:00+08:00');
  if (!Number.isFinite(stamp) || new Date(stamp + CHINA_OFFSET_MS).toISOString().slice(0, 10) !== text || chinaWeekday(stamp) !== 1) {
    throw new Error('请填写校历第 1 教学周的星期一（北京时间）');
  }
  return stamp;
}

// Manual exam dates are wall-clock times in Xi'an, independent of device timezone.
export function examTimestamps(text: string): number[] {
  if (!/^\d{4}-\d{2}-\d{2} [0-2]\d:[0-5]\d~[0-2]\d:[0-5]\d$/.test(text)) {
    throw new Error('考试时间须为 YYYY-MM-DD HH:mm~HH:mm（北京时间）');
  }
  const date = text.slice(0, 10);
  const midnight = Date.parse(date + 'T00:00:00+08:00');
  if (!Number.isFinite(midnight) || new Date(midnight + CHINA_OFFSET_MS).toISOString().slice(0, 10) !== date) {
    throw new Error('考试日期无效');
  }
  const start = midnight + clockStamp(text.slice(11, 16));
  const end = midnight + clockStamp(text.slice(17, 22));
  if (end <= start) throw new Error('考试结束时间须晚于开始时间，暂不支持跨日考试');
  return [start, end];
}

export function teachingWeek(timestamp: number, firstMonday: number): number {
  return Math.floor((chinaDayStart(timestamp) - firstMonday) / WEEK_MS) + 1;
}

export function classTimestamp(firstMonday: number, week: number, day: number, timeOfDay: number): number {
  if (!Number.isInteger(week) || week < 1 || firstMonday !== mondayStart(firstMonday) ||
    !Number.isFinite(timeOfDay) || timeOfDay < 0 || timeOfDay >= DAY_MS) throw new Error('课程日期无效');
  return firstMonday + (week - 1) * WEEK_MS + mondayOffset(day) * DAY_MS + timeOfDay;
}

export function clockStamp(clock: string): number {
  if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(clock)) throw new Error('时间须为 HH:mm');
  return (Number(clock.slice(0, 2)) * 60 + Number(clock.slice(3))) * 60000;
}

// One line per period, in period order. Intentionally no default campus table.
export function parsePeriods(text: string): string[][] {
  const lines = text.trim().split(/\r?\n/);
  if (!text.trim() || lines.length > 24) throw new Error('请逐行填写 1–24 节的实际起止时间');
  const result: string[][] = [];
  let previousEnd: number = -1;
  for (const line of lines) {
    const pair = line.trim().split('-');
    if (pair.length !== 2) throw new Error('每行格式为 HH:mm-HH:mm');
    const start = clockStamp(pair[0]);
    const end = clockStamp(pair[1]);
    if (start >= end || start < previousEnd) throw new Error('节次须按时间递增，且不能重叠或跨日');
    previousEnd = end;
    result.push(pair);
  }
  return result;
}

export function expandWeeks(text: string, maxWeek: number = 30): number[] {
  if (!Number.isInteger(maxWeek) || maxWeek < 1 || maxWeek > 60) throw new Error('学期周数无效');
  const cleaned = text.replace(/\s/g, '').replace(/，/g, ',').replace(/[~～]/g, '-').replace(/（/g, '(').replace(/）/g, ')');
  const result: number[] = [];
  for (const part of cleaned.split(',')) {
    const match = /^(\d+)(?:-(\d+))?(?:周)?(?:\((单|双)(?:周)?\))?$/.exec(part);
    if (!match) throw new Error('周次格式应为 1-16(单),18 或明确的周次列表');
    const start = Number(match[1]);
    const end = Number(match[2] || match[1]);
    if (start < 1 || start > end || end > maxWeek) throw new Error('周次超出范围');
    for (let week = start; week <= end; week++) {
      if (match[3] === '单' && week % 2 !== 1) continue;
      if (match[3] === '双' && week % 2 !== 0) continue;
      if (!result.includes(week)) result.push(week);
    }
  }
  if (result.length === 0) throw new Error('至少选择一个上课周');
  return result.sort((a: number, b: number) => a - b);
}
