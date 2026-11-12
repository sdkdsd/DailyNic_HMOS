import * as ExamStorage from './ExamStorage';
import { examTimestamps } from './CampusTime';

function normalizedExam(exam: ExamStorage.examAttribute): ExamStorage.examAttribute {
  if (typeof exam.name !== 'string' || !exam.name.trim()) throw new Error('请填写考试名称');
  const copy = JSON.parse(JSON.stringify(exam)) as ExamStorage.examAttribute;
  const times = examTimestamps(copy.date);
  copy.beginTimeStamp = times[0];
  copy.endTimeStamp = times[1];
  if (copy.importance === undefined) copy.importance = 5;
  return copy;
}

export function areExamAttributesEqual(a: ExamStorage.examAttribute, b: ExamStorage.examAttribute): boolean {
  // 基本类型直接比较
  if (a.id !== b.id) return false;
  if (a.type !== b.type) return false;
  if (a.name !== b.name) return false;
  if (a.date !== b.date) return false;
  if (a.classroom !== b.classroom) return false;
  if (a.building !== b.building) return false;
  if (a.campus !== b.campus) return false;
  if (a.info !== b.info) return false;
  if (a.importance !== b.importance) return false;
  // 所有字段都相同
  return true;
}

class examManager {
  allExamInfo: ExamStorage.examAttribute[] = [];

  readStoredExam() {
    this.allExamInfo = ExamStorage.getExams().map((exam: ExamStorage.examAttribute): ExamStorage.examAttribute => {
      try { return normalizedExam(exam); } catch (_) {
        // Keep malformed legacy entries editable, but never schedule them as valid exams.
        const copy = JSON.parse(JSON.stringify(exam)) as ExamStorage.examAttribute;
        copy.beginTimeStamp = 0;
        copy.endTimeStamp = 0;
        return copy;
      }
    });
  }

  storeExam(data: ExamStorage.examAttribute[]) {
    const normalized = data.map(normalizedExam);
    this.persist(normalized);
  }

  private persist(data: ExamStorage.examAttribute[]): void {
    data.sort((a, b) => {
      if (a.importance !== b.importance) {
        return b.importance - a.importance;
      }
      return a.beginTimeStamp - b.beginTimeStamp;
    });
    ExamStorage.setExams(data);
    this.allExamInfo = data;
  }

  addExam(newExam: ExamStorage.examAttribute) {
    this.persist(this.allExamInfo.concat([normalizedExam(newExam)]));
  }

  replaceExam(oldExam: ExamStorage.examAttribute, newExam: ExamStorage.examAttribute): void {
    const replacement = normalizedExam(newExam);
    const index = this.allExamInfo.findIndex((exam: ExamStorage.examAttribute) => areExamAttributesEqual(exam, oldExam));
    if (index < 0) throw new Error('原考试不存在，请刷新后重试');
    const next = this.allExamInfo.slice();
    next[index] = replacement;
    this.persist(next);
  }

  deleteExam(deletedExam: ExamStorage.examAttribute) {
    const next = this.allExamInfo.slice();
    for (let i = next.length - 1; i >= 0; i--)
      if (areExamAttributesEqual(deletedExam, next[i])) {
        next.splice(i, 1);
        break;
      }
    this.persist(next);
  }
}

export default new examManager();
