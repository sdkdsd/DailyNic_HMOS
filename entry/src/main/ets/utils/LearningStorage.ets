import { fileIo } from '@kit.CoreFileKit';
import type { LearningSnapshot, LearningPage, LearningTask } from './LearningTasks';
import { emptyLearningSnapshot, validateLearningSnapshot,
  mergeLearningPage, pendingLearningTasks, uncertainLearningTasks, learningTime } from './LearningTasks';

let dataPath: string = '';
export function initLearningStorage(context: Context): void { dataPath = `${context.filesDir}/learningTasks.json`; }
export function getLearningSnapshot(): LearningSnapshot {
  if (!dataPath) throw new Error('storage');
  if (!fileIo.accessSync(dataPath)) return emptyLearningSnapshot();
  const snapshot = JSON.parse(fileIo.readTextSync(dataPath)) as LearningSnapshot;
  validateLearningSnapshot(snapshot);
  return snapshot;
}
export interface LearningView { tasks: LearningTask[]; uncertain: LearningTask[]; summary: string; }
export function getLearningView(): LearningView {
  try {
    const s = getLearningSnapshot();
    const now = Date.now();
    const tasks = pendingLearningTasks(s, now);
    return { tasks, uncertain: uncertainLearningTasks(s, now), summary: s.homeworkAt || s.examAt ?
      `作业：${s.homeworkAt ? learningTime(s.homeworkAt) : '尚未读取'}\n考试：${s.examAt ? learningTime(s.examAt) : '尚未读取'}\n已结束或到期的事项不再显示，可联网更新。` : '尚未同步学习通作业和考试' };
  } catch (_) { return { tasks: [], uncertain: [], summary: '学习通缓存无法读取，原文件保留；请反馈此提示。' }; }
}
export interface LearningPreview { baseline: string; snapshot: LearningSnapshot; capturedAt: number; count: number; }
export function prepareLearningUpdate(page: LearningPage, capturedAt: number): LearningPreview {
  const current = getLearningSnapshot();
  return { baseline: JSON.stringify(current), snapshot: mergeLearningPage(current, page, capturedAt),
    capturedAt, count: page.rows.length };
}
export function confirmLearningUpdate(preview: LearningPreview, now: number): void {
  if (now < preview.capturedAt || now - preview.capturedAt > 300000 ||
    JSON.stringify(getLearningSnapshot()) !== preview.baseline) throw new Error('stale');
  validateLearningSnapshot(preview.snapshot);
  const text = JSON.stringify(preview.snapshot);
  const temp = dataPath + '.tmp';
  const file = fileIo.openSync(temp, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
  try { fileIo.writeSync(file.fd, text); fileIo.fsyncSync(file.fd); }
  finally { fileIo.closeSync(file); }
  if (fileIo.readTextSync(temp) !== text) throw new Error('write');
  fileIo.renameSync(temp, dataPath);
}
