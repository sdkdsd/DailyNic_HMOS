import { fileIo } from '@kit.CoreFileKit';
import type { LearningSnapshot, LearningPage, LearningTask } from './LearningTasks';
import { emptyLearningSnapshot, validateLearningSnapshot,
  mergeLearningPage, pendingLearningTasks } from './LearningTasks';

let dataPath: string = '';
export function initLearningStorage(context: Context): void { dataPath = `${context.filesDir}/learningTasks.json`; }
export function getLearningSnapshot(): LearningSnapshot {
  if (!dataPath) throw new Error('storage');
  if (!fileIo.accessSync(dataPath)) return emptyLearningSnapshot();
  const snapshot = JSON.parse(fileIo.readTextSync(dataPath)) as LearningSnapshot;
  validateLearningSnapshot(snapshot);
  return snapshot;
}
export interface LearningView { tasks: LearningTask[]; summary: string; }
export function getLearningView(): LearningView {
  try {
    const s = getLearningSnapshot();
    return { tasks: pendingLearningTasks(s), summary: s.homeworkAt || s.examAt ?
      '显示最近读取的状态；进入学习通可联网更新。' : '尚未同步学习通作业和考试' };
  } catch (_) { return { tasks: [], summary: '学习通缓存无法读取，原文件保留；请反馈此提示。' }; }
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
