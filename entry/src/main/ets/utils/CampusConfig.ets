// Personal SUST Xi'an profile. Empty until the user checks their official timetable.
import { fileIo } from '@kit.CoreFileKit';
import { parsePeriods, parseMonday, clockStamp, isSummerDate } from './CampusTime';

export const CAMPUS_PROFILE_FILE: string = 'sustXianTimeProfileV1.json';
export const SCHOOL_PORTAL: string = 'https://my.sust.edu.cn/';
export const SCHOOL_LOGIN: string = 'https://login.sust.edu.cn/cas/login';
export const FORK_URL: string = 'https://github.com/sdkdsd/DailyNic_HMOS';

export interface CampusProfile {
  firstMonday: string;
  periodsText: string;
  source: string;
  // Absent preserves legacy single-table profiles. Present enables seasonal dates.
  summerPeriodsText?: string;
}

export const classTimes: string[][] = [['--:--', '--:--']];
export const classStamps: number[][] = [[0, 0]];
let profile: CampusProfile | undefined = undefined;
let profilePath: string = '';

// Read the file on each form callback; Preferences cache is not shared across processes.
export function initCampusProfile(context: Context): void {
  profilePath = `${context.filesDir}/${CAMPUS_PROFILE_FILE}`;
  loadCampusProfile();
}

export function getCampusProfile(): CampusProfile | undefined { return profile; }
export function periodCount(): number { return classTimes.length - 1; }
export function campusReady(): boolean { return profile !== undefined && periodCount() > 0; }
export function firstTeachingMonday(): number { return profile ? parseMonday(profile.firstMonday) : 0; }

export function periodsForDate(timestamp: number): string[][] {
  if (!profile) return [['--:--', '--:--']];
  const text = profile.summerPeriodsText !== undefined && isSummerDate(timestamp) ? profile.summerPeriodsText : profile.periodsText;
  return [['--:--', '--:--'], ...parsePeriods(text)];
}

export function stampsForDate(timestamp: number): number[][] {
  return periodsForDate(timestamp).map((pair: string[], index: number): number[] =>
    index === 0 ? [0, 0] : [clockStamp(pair[0]), clockStamp(pair[1])]);
}

// Keep existing array aliases alive, but always select by the actual date.
export function refreshCampusTimes(timestamp: number = Date.now()): void {
  classTimes.splice(1);
  classStamps.splice(1);
  const periods = periodsForDate(timestamp);
  for (let index = 1; index < periods.length; index++) {
    classTimes.push(periods[index]);
    classStamps.push([clockStamp(periods[index][0]), clockStamp(periods[index][1])]);
  }
}

function validateProfile(candidate: CampusProfile): void {
  parseMonday(candidate.firstMonday);
  const winter = parsePeriods(candidate.periodsText);
  if (candidate.summerPeriodsText !== undefined) {
    const summer = parsePeriods(candidate.summerPeriodsText);
    if (summer.length !== winter.length) throw new Error('夏冬季节次数必须一致');
  }
  if (typeof candidate.source !== 'string' || !candidate.source.trim()) throw new Error('请填写核对依据');
}

export function loadCampusProfile(): void {
  classTimes.splice(1);
  classStamps.splice(1);
  profile = undefined;
  try {
    if (!profilePath || !fileIo.accessSync(profilePath)) return;
    const candidate = JSON.parse(fileIo.readTextSync(profilePath)) as CampusProfile | null;
    if (!candidate || typeof candidate.source !== 'string' || !candidate.source.trim()) return;
    validateProfile(candidate);
    profile = candidate;
    refreshCampusTimes();
  } catch (_) {
    // Malformed/absent config is unverified; never fall back to USTC times.
  }
}

export function saveCampusProfile(candidate: CampusProfile): void {
  validateProfile(candidate);
  if (!profilePath) throw new Error('本地配置存储尚未初始化');
  const temporaryPath: string = profilePath + '.tmp';
  const file = fileIo.openSync(temporaryPath, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
  try {
    fileIo.writeSync(file.fd, JSON.stringify(candidate));
  } finally {
    fileIo.closeSync(file);
  }
  fileIo.renameSync(temporaryPath, profilePath);
  loadCampusProfile();
  if (!campusReady()) throw new Error('配置未能保存，请检查本地存储');
}
