import type { VisibleSchedule } from './SustOnline';
import { combineOnline, courseIdentity, overlap } from './SustOnline';
import type { classAttribute, exportedData, exportSemester } from '../constants/ScheduleSources';
import { validateExportedData } from '../constants/ScheduleSources';
import { getCampusProfile, periodCount } from './CampusConfig';
import { parseMonday, parsePeriods } from './CampusTime';
import { getOnlineSemester, saveOnlineSemester } from './ScheduleStorage';

export interface PendingOnlineSchedule {
  backup: exportedData; expected: string; previous: classAttribute[];
  added: number; removed: number; duplicates: number; cancelled: number;
}
export function prepareOnlineSchedule(student: VisibleSchedule, classroom: VisibleSchedule, firstMonday: string): PendingOnlineSchedule {
  const profile = getCampusProfile();
  if (!profile) throw new Error('请先核对西安校区作息');
  const begin = parseMonday(firstMonday);
  const merged = combineOnline(student, classroom, periodCount());
  const previous = getOnlineSemester(student.semester);
  const local: classAttribute[] = [];
  if (previous) {
    if (!previous.onlineCourses) throw new Error('旧在线记录缺少比对依据，未覆盖');
    for (const c of previous.onlineCourses) {
      if (!previous.courses.some((p: classAttribute): boolean => JSON.stringify(p) === JSON.stringify(c))) {
        throw new Error('已在本地编辑过在线课程，请先导出备份并核对；本次未覆盖');
      }
    }
    for (const c of previous.courses) {
      if (!previous.onlineCourses.some((p: classAttribute): boolean => JSON.stringify(p) === JSON.stringify(c))) local.push(c);
    }
    if (local.some((a: classAttribute): boolean => merged.courses.some((b: classAttribute): boolean => overlap(a, b) || a.id === b.id))) {
      throw new Error('新课表与手动添加课程有冲突，请先核对；本次未覆盖');
    }
  }
  const old = previous?.onlineCourses || [];
  const incoming: exportSemester = {
    attribute: { name: student.semester, onlineTerm: student.semester, createTime: Date.now(), beginTime: begin,
      totalWeekNum: student.weekCount, calendarWeekCount: student.weekCount,
      source: '陕科大教务网页 · 学生课表＋班级补充 · ' + new Date().toISOString() },
    courses: merged.courses.concat(local), onlineCourses: merged.courses
  };
  const backup: exportedData = { exportTime: Date.now() / 1000,
    scheduleVersion: profile.summerPeriodsText === undefined ? 'sust-xian-1' : 'sust-xian-2-seasonal',
    periods: parsePeriods(profile.periodsText), defaultSemester: 0, semesters: [incoming] };
  if (profile.summerPeriodsText !== undefined) backup.summerPeriods = parsePeriods(profile.summerPeriodsText);
  const error = validateExportedData(backup); if (error) throw new Error(error);
  return { backup: backup, expected: JSON.stringify(previous), previous: old,
    added: merged.courses.filter((c: classAttribute): boolean => !old.some((p: classAttribute): boolean => courseIdentity(c) === courseIdentity(p))).length,
    removed: old.filter((c: classAttribute): boolean => !merged.courses.some((p: classAttribute): boolean => courseIdentity(c) === courseIdentity(p))).length,
    duplicates: merged.duplicates, cancelled: merged.cancelled };
}
export function confirmOnlineSchedule(pending: PendingOnlineSchedule, makeDefault: boolean): number {
  const error = validateExportedData(pending.backup); if (error) throw new Error(error);
  return saveOnlineSemester(pending.backup.semesters[0], pending.expected, makeDefault);
}
