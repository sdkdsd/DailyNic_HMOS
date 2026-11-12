import { calendarManager } from '@kit.CalendarKit';
import { classAttribute, semesterAttribute } from '../constants/ScheduleSources';
import { examAttribute } from './ExamStorage';
import { classTimestamp, clockStamp, examTimestamps, isSummerDate } from './CampusTime';

export function courseEvents(courses: classAttribute[], semester: semesterAttribute,
  periods: string[][], minute: number, summerPeriods?: string[][]): calendarManager.Event[] {
  const events: calendarManager.Event[] = [];
  if (summerPeriods !== undefined && summerPeriods.length !== periods.length) throw new Error('夏冬季节次数不一致');
  for (const course of courses) {
    if (!course.timeSpan.length || !course.weekOfTerm.length) throw new Error('课程缺少节次或周次');
    for (let i = 0; i < course.timeSpan.length; i++) {
      const period = course.timeSpan[i];
      if (!Number.isInteger(period) || period < 1 || period >= periods.length ||
        (i > 0 && period !== course.timeSpan[i - 1] + 1)) throw new Error('课程节次与配置不一致');
    }
    for (let i = 0; i < course.weekOfTerm.length; i++) {
      const week = course.weekOfTerm[i];
      if (week > semester.totalWeekNum || (i > 0 && week <= course.weekOfTerm[i - 1])) throw new Error('课程周次无效');
      const day = classTimestamp(semester.beginTime, week, course.dayOfWeek, 0);
      const times = summerPeriods !== undefined && isSummerDate(day) ? summerPeriods : periods;
      const start = day + clockStamp(times[course.timeSpan[0]][0]);
      const end = classTimestamp(semester.beginTime, week, course.dayOfWeek,
        clockStamp(times[course.timeSpan[course.timeSpan.length - 1]][1]));
      if (end <= start) throw new Error('课程结束时间无效');
      events.push({ title: course.name, location: { location: course.location },
        type: calendarManager.EventType.NORMAL, startTime: start, endTime: end,
        reminderTime: minute < 0 ? [] : [minute] });
    }
  }
  return events;
}

export function examEvents(exams: examAttribute[], minute: number): calendarManager.Event[] {
  return exams.map((exam: examAttribute): calendarManager.Event => {
    const times = examTimestamps(exam.date);
    return { title: exam.name, location: { location: exam.building + exam.classroom },
      type: calendarManager.EventType.NORMAL, startTime: times[0], endTime: times[1],
      reminderTime: minute < 0 ? [] : [minute] };
  });
}
