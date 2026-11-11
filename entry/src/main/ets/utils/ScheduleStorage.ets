import { fileIo } from '@kit.CoreFileKit';
import { classAttribute, semesterAttribute, exportSemester } from '../constants/ScheduleSources';

interface storedSchedule {
  defaultSemester: number,
  semesters: exportSemester[]
}

let scheduleFilePath: string = '';
let scheduleCache: storedSchedule | null = null;
let fileReady: boolean = false;

/**
 * 初始化 ScheduleStorage。必须在任何读写操作之前调用一次（EntryAbility.onCreate 中调用）。
 * @param context 应用上下文
 * @param forceReload 是否强制丢弃内存缓存并重新从文件读取。用于服务卡片等独立进程，
 *                    避免因进程内缓存陈旧而读到旧数据、并在回写时覆盖其他进程的最新保存。
 */
export function init(context: Context, forceReload: boolean = false): void {
  scheduleFilePath = `${context.filesDir}/scheduleData.json`;
  fileReady = true;
  if (forceReload) {
    scheduleCache = null;
  }
  loadSchedule();
}

export function isReady(): boolean {
  return scheduleFilePath !== '' && fileReady;
}

function loadSchedule(): storedSchedule {
  if (scheduleCache !== null) {
    return scheduleCache;
  }
  try {
    if (fileIo.accessSync(scheduleFilePath)) {
      scheduleCache = JSON.parse(fileIo.readTextSync(scheduleFilePath)) as storedSchedule;
    }
  } catch (e) {
    console.error('ScheduleStorage: failed to load schedule file:', JSON.stringify(e));
  }
  if (scheduleCache === null) {
    scheduleCache = { defaultSemester: 0, semesters: [] };
  }
  return scheduleCache;
}

function copySchedule(): storedSchedule {
  return JSON.parse(JSON.stringify(loadSchedule())) as storedSchedule;
}

function flushSchedule(data: storedSchedule): void {
  const temporaryPath = scheduleFilePath + '.tmp';
  const file = fileIo.openSync(temporaryPath, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
  try {
    fileIo.writeSync(file.fd, JSON.stringify(data));
    fileIo.fsyncSync(file.fd);
  } finally {
    fileIo.closeSync(file);
  }
  fileIo.renameSync(temporaryPath, scheduleFilePath);
  scheduleCache = data;
  fileReady = true;
}

// Validated backups append in one write, never a half-imported set of semesters.
export function appendBackup(semesters: exportSemester[]): number {
  const data = copySchedule();
  const firstIndex = data.semesters.length;
  let id = Date.now();
  for (const existing of data.semesters) id = Math.max(id, existing.attribute.createTime);
  const incoming = JSON.parse(JSON.stringify(semesters)) as exportSemester[];
  for (const semester of incoming) {
    semester.attribute.createTime = ++id;
    data.semesters.push(semester);
  }
  flushSchedule(data);
  return firstIndex;
}

export function getDefaultSemester(): number {
  return loadSchedule().defaultSemester;
}

export function setDefaultSemester(index: number): void {
  const data = copySchedule();
  if (data.defaultSemester === index) return; // 值未变，不写盘
  data.defaultSemester = index;
  flushSchedule(data);
}

export function getSemesters(): semesterAttribute[] {
  return copySchedule().semesters.map(entry => entry.attribute);
}

export function setSemesters(attributes: semesterAttribute[]): void {
  const data = copySchedule();
  data.semesters = attributes.map(attribute => {
    const existing = data.semesters.find(entry => entry.attribute.createTime === attribute.createTime);
    const entry: exportSemester = {
      attribute: attribute,
      courses: existing ? existing.courses : []
    };
    return entry;
  });
  flushSchedule(data);
}

export function getCourses(createTime: number): classAttribute[] {
  const data = copySchedule();
  const entry = data.semesters.find(item => item.attribute.createTime === createTime);
  return entry ? entry.courses : [];
}

export function setCourses(createTime: number, courses: classAttribute[]): void {
  const data = copySchedule();
  const entry = data.semesters.find(item => item.attribute.createTime === createTime);
  if (entry) {
    entry.courses = courses;
  } else {
    data.semesters.push({ attribute: { name: '', source: '', createTime: createTime, beginTime: 0, totalWeekNum: 0 }, courses: courses });
  }
  flushSchedule(data);
}

export function deleteSemesterData(createTime: number): void {
  const data = copySchedule();
  data.semesters = data.semesters.filter(item => item.attribute.createTime !== createTime);
  flushSchedule(data);
}

/**
 * 清除全部课表数据（用于故障恢复页面）。
 */
export function clearScheduleData(): void {
  flushSchedule({ defaultSemester: 0, semesters: [] });
}

/**
 * 将旧版（2.1.1 及以前）保存在 UnifyPreference 中的课表数据导入本地 JSON 文件。
 * @param defaultSemester 旧版默认学期编号
 * @param attributes 旧版学期属性列表
 * @param coursesByCreateTime 旧版各学期课程数据（键为 createTime）
 */
export function importLegacyData(defaultSemester: number, attributes: semesterAttribute[], coursesByCreateTime: Record<string, classAttribute[]>): void {
  const data = copySchedule();
  data.semesters = attributes.map(attribute => {
    const entry: exportSemester = {
      attribute: attribute,
      courses: coursesByCreateTime[String(attribute.createTime)] || []
    };
    return entry;
  });
  if (attributes.length > 0) {
    data.defaultSemester = defaultSemester >= 0 && defaultSemester < attributes.length ? defaultSemester : 0;
  }
  if (data.semesters.length > 0) {
    flushSchedule(data);
  }
}