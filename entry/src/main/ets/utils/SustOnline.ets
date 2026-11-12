// Pure parser for the visible SUST EAMS table. No credentials, network or private fixtures.
import type { classAttribute } from '../constants/ScheduleSources';

export interface VisibleCell { text: string; rowspan: number; colspan: number; }
export interface VisibleSchedule {
  kind: string; week: string; semester: string; weekCount: number;
  rows: VisibleCell[][]; catalog: string[][];
  readError?: string;
}
export interface ParsedSchedule { courses: classAttribute[]; cancelled: classAttribute[]; }
export interface OnlinePreview { courses: classAttribute[]; duplicates: number; cancelled: number; }
export const SUST_TABLE_URL: string = 'https://bkjw.sust.edu.cn/eams/courseTableForStd.action';
export function schoolNavigationAllowed(url: string): boolean {
  return /^https:\/\/(?:bkjw|login|my)\.sust\.edu\.cn(?::443)?(?:\/|$)/.test(url);
}
// EAMS sends an HTTP Location even when entered over HTTPS. Upgrade only a
// main-frame GET on the exact verified EAMS/CAS hosts; never replay a credential POST.
export function secureSchoolRedirect(url: string, method: string, mainFrame: boolean): string {
  if (!mainFrame || method !== 'GET' || !/^http:\/\/(?:bkjw|login)\.sust\.edu\.cn(?:\/|$)/.test(url)) return '';
  return 'https://' + url.substring('http://'.length);
}
export function schedulePageAllowed(url: string): boolean {
  return /^https:\/\/bkjw\.sust\.edu\.cn(?::443)?\/eams\/courseTableForStd\.action(?:;jsessionid=[A-Za-z0-9._-]+)?(?:[?#]|$)/.test(url);
}
function check(ok: boolean, message: string): void { if (!ok) throw new Error(message); }
export function parseSchoolWeeks(text: string, maximum: number): number[] {
  const normalized = text.trim().replace(/（/g, '(').replace(/）/g, ')')
    .replace(/[–～~]/g, '-').replace(/\s*([-()])\s*/g, '$1');
  const result: number[] = [];
  for (const token of normalized.split(/[,，、\s]+/)) {
    const match = /^(\d+)(?:-(\d+))?(?:周)?(?:\(([单双])(?:周)?\))?$/.exec(token);
    check(match !== null, '无法识别教学周，请核对网页');
    const start = Number(match![1]); const end = Number(match![2] || match![1]);
    check(start >= 1 && end >= start && end <= maximum, '教学周超出本学期范围');
    for (let week = start; week <= end; week++) {
      if ((!match![3] || week % 2 === (match![3] === '单' ? 1 : 0)) && !result.includes(week)) result.push(week);
    }
  }
  check(result.length > 0, '教学周为空');
  return result.sort((a: number, b: number): number => a - b);
}
function room(text: string): string {
  const coded = /^(.+?)\([A-Za-z0-9-]+\)\)?$/.exec(text);
  if (coded) return coded[1].trim();
  check(text.endsWith(')') && !text.includes('('), '教室格式有变化，未保存');
  return text.substring(0, text.length - 1).trim();
}
export function courseSlot(c: classAttribute): string { return `${c.id}|${c.dayOfWeek}|${c.timeSpan.join(',')}`; }
export function courseIdentity(c: classAttribute): string {
  return `${courseSlot(c)}|${c.weekOfTerm.join(',')}|${c.name}|${c.teacher}|${c.location}|${c.credits}`;
}
export function overlap(a: classAttribute, b: classAttribute): boolean {
  return a.dayOfWeek === b.dayOfWeek && a.timeSpan.some((n: number): boolean => b.timeSpan.includes(n)) &&
    a.weekOfTerm.some((n: number): boolean => b.weekOfTerm.includes(n));
}
function removeCancelled(courses: classAttribute[], stopped: classAttribute[]): classAttribute[] {
  const copy = JSON.parse(JSON.stringify(courses)) as classAttribute[];
  for (const stop of stopped) for (const c of copy) {
    if (courseSlot(c) === courseSlot(stop)) c.weekOfTerm = c.weekOfTerm.filter((n: number): boolean => !stop.weekOfTerm.includes(n));
  }
  return copy.filter((c: classAttribute): boolean => c.weekOfTerm.length > 0);
}
export function parseVisibleSchedule(data: VisibleSchedule, maxPeriod: number): ParsedSchedule {
  check(data !== null && typeof data === 'object', '未读取到课表');
  check(['学生课表', '班级课表'].includes(data.kind) && data.week === '全部', '请在网页选择学生或班级课表及全部教学周');
  check(/^\d{4}-\d{4}学年[12]学期$/.test(data.semester), '未识别学年学期');
  check(Number.isInteger(data.weekCount) && data.weekCount >= 1 && data.weekCount <= 30, '教学周列表无效');
  const headings = ['序号', '课程代码', '课程名称', '学分', '课程序号', '教师', '备注', '操作'];
  check(Array.isArray(data.catalog) && JSON.stringify(data.catalog[0]) === JSON.stringify(headings), '课程列表结构有变化');
  const lookup = new Map<string, string[]>();
  for (const row of data.catalog.slice(1)) {
    check(Array.isArray(row) && row.length === 8 && row.every((s: string): boolean => typeof s === 'string'), '课程列表行无效');
    check(/^[A-Za-z0-9]+\.[A-Za-z0-9]+$/.test(row[4]) && !lookup.has(row[4]) && row[2].length > 0 && /^\d+(?:\.\d+)?$/.test(row[3]), '课程序号或学分无效');
    lookup.set(row[4], row);
  }
  check(Array.isArray(data.rows) && data.rows.length === 12, '需要完整的第1–11节网格');
  const headers = ['节次/周次', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
  check(JSON.stringify(data.rows[0].map((c: VisibleCell): string => c.text.trim())) === JSON.stringify(headers) &&
    data.rows[0].every((c: VisibleCell): boolean => c.rowspan === 1 && c.colspan === 1), '星期表头有变化');
  const labels = ['一','二','三','四','五','六','七','八','九','十','十一'];
  const occupied = new Set<string>(); const seen = new Set<string>();
  const courses: classAttribute[] = []; const cancelled: classAttribute[] = [];
  for (let p = 1; p <= 11; p++) {
    const row = data.rows[p];
    check(Array.isArray(row) && row.length > 0 && row[0].text.trim() === `第${labels[p - 1]}节` && row[0].rowspan === 1 && row[0].colspan === 1, '节次顺序有变化');
    let day = 1;
    for (const cell of row.slice(1)) {
      while (occupied.has(`${p}:${day}`)) day++;
      check(Number.isInteger(cell.rowspan) && cell.rowspan > 0 && p + cell.rowspan <= 12 && cell.colspan === 1 && day <= 7 && typeof cell.text === 'string', '合并单元格不完整');
      const periods: number[] = [];
      for (let n = p; n < p + cell.rowspan; n++) {
        check(!occupied.has(`${n}:${day}`), '网格重叠'); occupied.add(`${n}:${day}`); periods.push(n);
      }
      let current: classAttribute | null = null; let hasSession = false;
      for (const line of cell.text.split(/\r?\n/).map((s: string): string => s.trim()).filter((s: string): boolean => s.length > 0)) {
        const header = /^(.+)\(([A-Za-z0-9]+\.[A-Za-z0-9]+)\)(?:\s*\(([^()]*)\))?$/.exec(line);
        if (header) {
          check(current === null || hasSession, '课程缺少安排');
          const record = lookup.get(header[2]);
          check(record !== undefined && record[2] === header[1] && record[5] === (header[3] || ''), '课表与课程列表不一致');
          current = { name: header[1], id: header[2], teacher: header[3] || '', credits: record![3], dayOfWeek: day % 7,
            timeSpan: periods, weekOfTerm: [], location: '', color: '#FF6487B5', priority: 5 };
          seen.add(header[2]); hasSession = false;
        } else {
          const session = /^\(([\d\s,，、()（）单双周\-–～~]+),(.+)$/.exec(line);
          check(current !== null && session !== null, '课表格式有变化，拒绝部分更新');
          const c = JSON.parse(JSON.stringify(current)) as classAttribute;
          c.weekOfTerm = parseSchoolWeeks(session![1], data.weekCount); c.location = room(session![2]); hasSession = true;
          if (c.location === '停课') cancelled.push(c);
          else { check(periods[periods.length - 1] <= maxPeriod && c.location.length > 0, '包含未确认节次或空教室，旧课表保留'); courses.push(c); }
        }
      }
      check(current === null || hasSession, '课程缺少安排'); day++;
    }
    for (let d = 1; d <= 7; d++) check(occupied.has(`${p}:${d}`), '网格不完整');
  }
  check(courses.length > 0 && seen.size === lookup.size, '课表为空或课程列表未完整安排，旧课表保留');
  return { courses: removeCancelled(courses, cancelled), cancelled: cancelled };
}
export function combineOnline(student: VisibleSchedule, classroom: VisibleSchedule, maxPeriod: number): OnlinePreview {
  check(student.kind === '学生课表' && classroom.kind === '班级课表' && student.semester === classroom.semester && student.weekCount === classroom.weekCount, '两张课表须为同一学期');
  const personal = parseVisibleSchedule(student, maxPeriod); const group = parseVisibleSchedule(classroom, maxPeriod);
  const stopped = personal.cancelled.concat(group.cancelled);
  const result = removeCancelled(personal.courses, stopped); let duplicates = 0;
  for (const extra of removeCancelled(group.courses, stopped)) {
    if (result.some((c: classAttribute): boolean => courseIdentity(c) === courseIdentity(extra))) duplicates++;
    else { check(!result.some((c: classAttribute): boolean => overlap(c, extra)), '学生与班级课表有时间冲突，请先在网页核对；未覆盖旧课表'); result.push(extra); }
  }
  check(result.length > 0, '没有可保存的课程');
  return { courses: result, duplicates: duplicates, cancelled: stopped.length };
}
