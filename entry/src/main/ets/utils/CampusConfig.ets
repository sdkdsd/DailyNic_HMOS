// Personal SUST Xi'an profile. Empty until the user checks their official timetable.
import { fileIo } from '@kit.CoreFileKit';
import { parsePeriods, parseMonday, clockStamp } from './CampusTime';

export const CAMPUS_PROFILE_FILE: string = 'sustXianTimeProfileV1.json';
export const SCHOOL_PORTAL: string = 'https://my.sust.edu.cn/';
export const SCHOOL_LOGIN: string = 'https://login.sust.edu.cn/cas/login';
export const FORK_URL: string = 'https://github.com/sdkdsd/DailyNic_HMOS';

export interface CampusProfile {
  firstMonday: string;
  periodsText: string;
  source: string;
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

export function loadCampusProfile(): void {
  classTimes.splice(1);
  classStamps.splice(1);
  profile = undefined;
  try {
    if (!profilePath || !fileIo.accessSync(profilePath)) return;
    const candidate = JSON.parse(fileIo.readTextSync(profilePath)) as CampusProfile | null;
    if (!candidate || typeof candidate.source !== 'string' || !candidate.source.trim()) return;
    parseMonday(candidate.firstMonday);
    const periods = parsePeriods(candidate.periodsText);
    for (const pair of periods) {
      classTimes.push(pair);
      classStamps.push([clockStamp(pair[0]), clockStamp(pair[1])]);
    }
    profile = candidate;
  } catch (_) {
    // Malformed/absent config is unverified; never fall back to USTC times.
  }
}

export function saveCampusProfile(candidate: CampusProfile): void {
  parseMonday(candidate.firstMonday);
  parsePeriods(candidate.periodsText);
  if (!candidate.source.trim()) throw new Error('请填写核对依据，例如本学期西安校区作息通知');
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
