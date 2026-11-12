// Original implementation for this fork: homework/exam list metadata only.
export const LEARNING_HOMEWORK_URL: string = 'https://mooc1-api.chaoxing.com/work/stu-work';
export const LEARNING_EXAM_URL: string = 'https://mooc1-api.chaoxing.com/exam-ans/exam/phone/examcode';
export interface LearningRow { id: string; title: string; course: string; status: string; remaining: string; }
export interface LearningPage { kind: string; rows: LearningRow[]; readError?: string; }
export interface LearningTask {
  id: string; kind: string; title: string; course: string; status: string;
  active: boolean; dueAt: number; observedAt: number;
}
export interface LearningSnapshot { version: number; tasks: LearningTask[]; homeworkAt: number; examAt: number; }

export function learningNavigationAllowed(address: string): boolean {
  return /^https:\/\/(?:i|passport2|mooc1-api|mooc1|mooc2-ans|mooc1-2)\.chaoxing\.com(?::443)?(?:\/|$)/.test(address);
}
export function learningTime(stamp: number): string {
  const d = new Date(stamp + 8 * 3600000);
  const pad = (n: number): string => String(n).padStart(2, '0');
  return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())} ${pad(d.getUTCHours())}:${pad(d.getUTCMinutes())}`;
}
function boundedText(text: string, max: number): boolean {
  return typeof text === 'string' && text.length <= max && !/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/.test(text);
}
// Relative page deadlines are approximate, not exact due dates.
export function learningDeadline(text: string, capturedAt: number): number {
  const cleaned = text.replace(/\s/g, '').replace(/^剩余(?:时间)?[：:]?/, '');
  if (['', '不限', '无截止时间', '已截止', '已结束', '--'].includes(cleaned)) return 0;
  if (!/^(?:\d+天)?(?:\d+小时)?(?:\d+分钟)?$/.test(cleaned)) throw new Error('deadline');
  const days = Number(/(\d+)天/.exec(cleaned)?.[1] ?? 0);
  const hours = Number(/(\d+)小时/.exec(cleaned)?.[1] ?? 0);
  const minutes = Number(/(\d+)分钟/.exec(cleaned)?.[1] ?? 0);
  if (days > 730 || hours > 23 || minutes > 59) throw new Error('deadline');
  return capturedAt + ((days * 24 + hours) * 60 + minutes) * 60000;
}
function activeStatus(kind: string, status: string): boolean {
  const pending = kind === 'homework' ? ['未提交', '未交', '待提交'] : ['未开始', '未考试', '待考试', '待考', '进行中', '考试中'];
  const closed = ['已提交', '待批阅', '已批阅', '已完成', '已结束', '已截止', '已考', '缺考'];
  if (pending.includes(status)) return true;
  if (closed.includes(status)) return false;
  throw new Error('status');
}
export function parseLearningPage(page: LearningPage, capturedAt: number): LearningTask[] {
  if (!page || page.readError || !['homework', 'exam'].includes(page.kind) || !Array.isArray(page.rows) ||
    !page.rows.length || page.rows.length > 2000 || !Number.isFinite(capturedAt) || capturedAt <= 0) throw new Error('page');
  const result: LearningTask[] = [];
  const ids: string[] = [];
  for (const row of page.rows) {
    if (!row || typeof row.id !== 'string' || !/^[1-9]\d{0,24}$/.test(row.id) ||
      !boundedText(row.title, 300) || !row.title.trim() || !boundedText(row.course, 300) ||
      !boundedText(row.status, 30) || !boundedText(row.remaining, 100)) throw new Error('row');
    const id = `${page.kind}:${row.id}`;
    if (ids.includes(id)) throw new Error('duplicate');
    ids.push(id);
    const status = row.status.trim();
    result.push({ id, kind: page.kind, title: row.title.trim(), course: row.course.trim(), status,
      active: activeStatus(page.kind, status), dueAt: learningDeadline(row.remaining, capturedAt), observedAt: capturedAt });
  }
  return result;
}
export function emptyLearningSnapshot(): LearningSnapshot { return { version: 1, tasks: [], homeworkAt: 0, examAt: 0 }; }
export function validateLearningSnapshot(snapshot: LearningSnapshot): void {
  if (!snapshot || snapshot.version !== 1 || !Array.isArray(snapshot.tasks) || snapshot.tasks.length > 10000 ||
    !Number.isFinite(snapshot.homeworkAt) || snapshot.homeworkAt < 0 || !Number.isFinite(snapshot.examAt) || snapshot.examAt < 0) throw new Error('cache');
  const ids: string[] = [];
  for (const t of snapshot.tasks) {
    if (!t || !['homework', 'exam'].includes(t.kind) || typeof t.id !== 'string' ||
      !new RegExp('^' + t.kind + ':[1-9]\\d{0,24}$').test(t.id) || ids.includes(t.id) ||
      !boundedText(t.title, 300) || !t.title.trim() || !boundedText(t.course, 300) ||
      !boundedText(t.status, 30) || typeof t.active !== 'boolean' || t.active !== activeStatus(t.kind, t.status) ||
      !Number.isFinite(t.dueAt) || t.dueAt < 0 || !Number.isFinite(t.observedAt) || t.observedAt <= 0) throw new Error('cache');
    ids.push(t.id);
  }
}
// Missing rows may be on another page. Absence NEVER means completion/deletion.
export function mergeLearningPage(previous: LearningSnapshot, page: LearningPage, capturedAt: number): LearningSnapshot {
  validateLearningSnapshot(previous);
  const incoming = parseLearningPage(page, capturedAt);
  const tasks: LearningTask[] = previous.tasks.filter((old: LearningTask) => !incoming.some((t: LearningTask) => t.id === old.id));
  const result: LearningSnapshot = { version: 1, tasks: tasks.concat(incoming),
    homeworkAt: page.kind === 'homework' ? capturedAt : previous.homeworkAt,
    examAt: page.kind === 'exam' ? capturedAt : previous.examAt };
  validateLearningSnapshot(result);
  return result;
}
export function pendingLearningTasks(snapshot: LearningSnapshot): LearningTask[] {
  return snapshot.tasks.filter((t: LearningTask) => t.active).sort((a: LearningTask, b: LearningTask) =>
    (a.dueAt || Number.MAX_SAFE_INTEGER) - (b.dueAt || Number.MAX_SAFE_INTEGER));
}
