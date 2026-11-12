import { classTimes, classStamps, periodCount, campusReady, getCampusProfile } from '../utils/CampusConfig';
import { mondayStart, parsePeriods } from '../utils/CampusTime';

import UnifiedPreferences from '../utils/UnifyPreference';

export interface classAttribute {
  name: string,
  teacher: string,
  weekOfTerm: number[],    // 以枚举形式写出哪几周
  timeSpan: number[],      // 包含完整的第几节课
  dayOfWeek: number,
  location: string,
  id: string,
  color: string,
  priority: number,
  credits: string // 防止小数精度丢失
}

export interface semesterAttribute {
  name: string, // 名称
  createTime: number, // 课表创建时间戳，用于读取不同课表
  source: string, // 最后一次编辑来源
  beginTime: number, // 学期开始时间戳
  totalWeekNum: number, // 校历周数和课程最大周数中的较大值
  calendarWeekCount?: number // 明确应用的校历周数；旧版数据可缺省
  onlineTerm?: string // Only dedicated online semesters are refreshed
}

export interface exportSemester {
  attribute: semesterAttribute,
  courses: classAttribute[]
  onlineCourses?: classAttribute[] // Last school snapshot protects subsequent local edits
};

export interface exportedData {
  exportTime: number,
  scheduleVersion: string,
  periods: string[][],
  summerPeriods?: string[][],
  defaultSemester: number,
  semesters: exportSemester[]
};

export let remindBefore: number[] = [];
export let examRemindBefore: number[] = [];

export function initSchedulePre() {
  remindBefore[0] = UnifiedPreferences.getNumberSync('remindBefore', 0) as number;
  if (remindBefore[0] == -1)
    remindBefore = [];
  examRemindBefore[0] = UnifiedPreferences.getNumberSync('examRemindBefore', 0) as number;
  if (examRemindBefore[0] == -1)
    examRemindBefore = [];
}

export function setRemindBefore(minute: number) {
  if (minute == -1)
    remindBefore = [];
  else
    remindBefore[0] = minute;
  UnifiedPreferences.putSync('remindBefore', minute);
}

export function setExamRemindBefore(minute: number) {
  if (minute == -1)
    examRemindBefore = [];
  else
    examRemindBefore[0] = minute;
  UnifiedPreferences.putSync('examRemindBefore', minute);
}

// User-confirmed campus times, never USTC defaults.
export const commonClassTime: string[][] = classTimes;
export const commonClassStamp: number[][] = classStamps;

/**
 * 校验 JSON.parse 解析后的对象是否符合 exportedData 接口规范
 * @param data JSON.parse 解析后的原始对象（仅此处用 object 类型）
 * @returns string[] 校验结果和错误信息
 */
export function validateExportedData(data: object): string {
  // 第一步：校验顶层结构（原生判断）
  if (typeof data !== 'object' || data === null || Array.isArray(data)) {
    return 'exportedData 必须是一个非空对象';
  }

  // 类型断言为显式定义的类型（仅用于 TS 编译，运行时靠原生判断）
  const exportedData = data as exportedData;
  if (!campusReady()) return '请先核对并配置西安校区作息';
  const campusProfile = getCampusProfile()!;
  const seasonal = campusProfile.summerPeriodsText !== undefined;
  if (exportedData.scheduleVersion !== (seasonal ? 'sust-xian-2-seasonal' : 'sust-xian-1')) return '备份作息模式或版本不一致，请先核对夏冬季配置；不直接导入旧学校备份';
  if (JSON.stringify(exportedData.periods) !== JSON.stringify(parsePeriods(campusProfile.periodsText))) return '备份作息与当前配置不同，请先核对课时后再导入';
  if (seasonal && JSON.stringify(exportedData.summerPeriods) !== JSON.stringify(parsePeriods(campusProfile.summerPeriodsText!))) return '备份夏季作息与当前配置不同';

  // ------------------------------
  // 校验顶层字段（typeof 判断）
  // ------------------------------
  // 1. exportTime
  if (exportedData.exportTime === undefined || exportedData.exportTime === null) {
    return 'exportedData 缺少必填字段: exportTime';
  } else if (!Number.isFinite(exportedData.exportTime)) {
    return 'exportedData.exportTime 必须是 number 类型';
  } else if (exportedData.exportTime <= 0) {
    return 'exportedData.exportTime 必须是有效的时间戳（正数）';
  }

  // 2. scheduleVersion
  if (exportedData.scheduleVersion === undefined || exportedData.scheduleVersion === null) {
    return 'exportedData 缺少必填字段: scheduleVersion';
  } else if (typeof exportedData.scheduleVersion !== 'string') {
    return 'exportedData.scheduleVersion 必须是 string 类型';
  }

  // 3. defaultSemester
  if (exportedData.defaultSemester === undefined || exportedData.defaultSemester === null) {
    return 'exportedData 缺少必填字段: defaultSemester';
  } else if (!Number.isInteger(exportedData.defaultSemester)) {
    return 'exportedData.defaultSemester 必须是 number 类型';
  } else if (exportedData.defaultSemester < 0) {
    return 'exportedData.defaultSemester 必须是非负整数';
  }

  // 4. semesters
  if (exportedData.semesters === undefined || exportedData.semesters === null) {
    return 'exportedData 缺少必填字段: semesters';
  } else if (!Array.isArray(exportedData.semesters)) {
    return 'exportedData.semesters 必须是数组类型';
  }

  if (exportedData.defaultSemester >= exportedData.semesters.length) return '默认学期越界或备份无学期';
  const seenTimes: number[] = [];
  if (Array.isArray(exportedData.semesters)) {
    // 显式指定 semester: exportSemester, semesterIndex: number
    for (let semesterIndex = 0; semesterIndex < exportedData.semesters.length; semesterIndex++) {
      const semester = exportedData.semesters[semesterIndex];
      const semesterPath = `exportedData.semesters[${semesterIndex}]`;

      // 运行时兜底校验：确保 semester 是纯对象
      if (typeof semester !== 'object' || semester === null || Array.isArray(semester)) {
        return `${semesterPath} 必须是一个非空对象`;
      }

      // 校验 attribute 字段
      if (semester.attribute === undefined || semester.attribute === null) {
        return `${semesterPath} 缺少必填字段: attribute`;
      } else if (typeof semester.attribute !== 'object' || semester.attribute === null || Array.isArray(semester.attribute)) {
        return `${semesterPath}.attribute 必须是非空对象`;
      }

      // 校验 courses 字段
      if (semester.courses === undefined || semester.courses === null) {
        return `${semesterPath} 缺少必填字段: courses`;
      } else if (!Array.isArray(semester.courses)) {
        return `${semesterPath}.courses 必须是数组类型`;
      }

      // ------------------------------
      // 校验 semesterAttribute
      // ------------------------------
      if (typeof semester.attribute === 'object' && semester.attribute !== null && !Array.isArray(semester.attribute)) {
        const attribute = semester.attribute;
        const attributePath = `${semesterPath}.attribute`;

        // 1. name
        if (attribute.name === undefined || attribute.name === null) {
          return `${attributePath} 缺少必填字段: name`;
        } else if (typeof attribute.name !== 'string') {
          return `${attributePath}.name 必须是 string 类型`;
        }

        // 2. createTime
        if (attribute.createTime === undefined || attribute.createTime === null) {
          return `${attributePath} 缺少必填字段: createTime`;
        } else if (typeof attribute.createTime !== 'number') {
          return `${attributePath}.createTime 必须是 number 类型`;
        } else if (attribute.createTime <= 0) {
          return `${attributePath}.createTime 必须是有效的时间戳`;
        }

        // 3. source
        if (attribute.source === undefined || attribute.source === null) {
          return `${attributePath} 缺少必填字段: source`;
        } else if (typeof attribute.source !== 'string') {
          return `${attributePath}.source 必须是 string 类型`;
        }

        // 4. beginTime
        if (attribute.beginTime === undefined || attribute.beginTime === null) {
          return `${attributePath} 缺少必填字段: beginTime`;
        } else if (typeof attribute.beginTime !== 'number') {
          return `${attributePath}.beginTime 必须是 number 类型`;
        } else if (attribute.beginTime <= 0) {
          return `${attributePath}.beginTime 必须是有效的时间戳`;
        }

        if (!Number.isFinite(attribute.beginTime) || attribute.beginTime !== mondayStart(attribute.beginTime)) return '学期须从北京时间周一零点开始';
        if (!Number.isFinite(attribute.createTime) || seenTimes.includes(attribute.createTime)) return '学期标识无效或重复';
        seenTimes.push(attribute.createTime);
        // 5. totalWeekNum
        if (attribute.calendarWeekCount !== undefined && (!Number.isInteger(attribute.calendarWeekCount) ||
          attribute.calendarWeekCount < 1 || attribute.calendarWeekCount > 30 || attribute.totalWeekNum < attribute.calendarWeekCount)) return '校历周数无效';
        if (attribute.totalWeekNum === undefined || attribute.totalWeekNum === null) {
          return `${attributePath} 缺少必填字段: totalWeekNum`;
        } else if (typeof attribute.totalWeekNum !== 'number') {
          return `${attributePath}.totalWeekNum 必须是 number 类型`;
        } else if (attribute.totalWeekNum < 0 || attribute.totalWeekNum > 30 || !Number.isInteger(attribute.totalWeekNum)) {
          return `${attributePath}.totalWeekNum 必须是非负整数`;
        }
      }

      // 校验 courses 数组
      if (Array.isArray(semester.courses)) {
        for (let courseIndex = 0; courseIndex < semester.courses.length; courseIndex++){
          const course = semester.courses[courseIndex];
          const coursePath = `${semesterPath}.courses[${courseIndex}]`;

          // 运行时兜底校验
          if (typeof course !== 'object' || course === null || Array.isArray(course)) {
            return `${coursePath} 必须是一个非空对象`;
          }

          // 1. name
          if (course.name === undefined || course.name === null) {
            return `${coursePath} 缺少必填字段: name`;
          } else if (typeof course.name !== 'string') {
            return `${coursePath}.name 必须是 string 类型`;
          }

          // 2. teacher
          if (course.teacher === undefined || course.teacher === null) {
            return `${coursePath} 缺少必填字段: teacher`;
          } else if (typeof course.teacher !== 'string') {
            return `${coursePath}.teacher 必须是 string 类型`;
          }

          // 3. weekOfTerm
          if (course.weekOfTerm === undefined || course.weekOfTerm === null) {
            return `${coursePath} 缺少必填字段: weekOfTerm`;
          } else if (!Array.isArray(course.weekOfTerm)) {
            return `${coursePath}.weekOfTerm 必须是数组类型`;
          } else if (!course.weekOfTerm.every(item => typeof item === 'number' && Number.isInteger(item) && item > 0)) {
            return `${coursePath}.weekOfTerm 必须是正整数数组`;
          }

          // 4. timeSpan
          if (course.timeSpan === undefined || course.timeSpan === null) {
            return `${coursePath} 缺少必填字段: timeSpan`;
          } else if (!Array.isArray(course.timeSpan)) {
            return `${coursePath}.timeSpan 必须是数组类型`;
          } else if (!course.timeSpan.every(item => typeof item === 'number' && Number.isInteger(item) && item > 0)) {
            return `${coursePath}.timeSpan 必须是正整数数组`;
          }

          if (course.timeSpan.length === 0 || course.timeSpan.some((p: number, i: number) => p > periodCount() || (i > 0 && p !== course.timeSpan[i - 1] + 1))) return '节次须为有效的连续递增列表';
          if (course.weekOfTerm.length === 0 || course.weekOfTerm.some((w: number, i: number) => w > semester.attribute.totalWeekNum || (i > 0 && w <= course.weekOfTerm[i - 1]))) return '周次须为学期范围内的递增列表';
          // 5. dayOfWeek
          if (course.dayOfWeek === undefined || course.dayOfWeek === null) {
            return `${coursePath} 缺少必填字段: dayOfWeek`;
          } else if (typeof course.dayOfWeek !== 'number') {
            return `${coursePath}.dayOfWeek 必须是 number 类型`;
          } else if (!Number.isInteger(course.dayOfWeek) || course.dayOfWeek < 0 || course.dayOfWeek > 6) {
            return `${coursePath}.dayOfWeek 必须是 0-6 的整数`;
          }

          // 6. location
          if (course.location === undefined || course.location === null) {
            return `${coursePath} 缺少必填字段: location`;
          } else if (typeof course.location !== 'string') {
            return `${coursePath}.location 必须是 string 类型`;
          }

          // 7. id
          if (course.id === undefined || course.id === null) {
            return `${coursePath} 缺少必填字段: id`;
          } else if (typeof course.id !== 'string') {
            return `${coursePath}.id 必须是 string 类型`;
          }

          // 8. color
          if (course.color === undefined || course.color === null) {
            return `${coursePath} 缺少必填字段: color`;
          } else if (typeof course.color !== 'string') {
            return `${coursePath}.color 必须是 string 类型`;
          }

          // 9. priority
          if (course.priority === undefined || course.priority === null) {
            return `${coursePath} 缺少必填字段: priority`;
          } else if (typeof course.priority !== 'number') {
            return `${coursePath}.priority 必须是 number 类型`;
          } else if (!Number.isInteger(course.priority) || course.priority < 0) {
            return `${coursePath}.priority 必须是非负整数`;
          }

          // 10. credits
          if (course.credits === undefined || course.credits === null) {
            return `${coursePath} 缺少必填字段: credits`
          } else if (typeof course.credits !== 'string') {
            return `${coursePath}.credits 必须是 string 类型`
          }
        }
      }
    }
  }

  return '';
}

export enum COVER_MODE { COVER, COVER_DUPLICATE, APPEND };
