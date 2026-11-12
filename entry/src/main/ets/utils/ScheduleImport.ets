import type { exportedData } from '../constants/ScheduleSources';
import { validateExportedData } from '../constants/ScheduleSources';
import { appendBackup } from './ScheduleStorage';

// Reading/previewing a document must never persist data.
export function previewScheduleImport(text: string): exportedData {
  const data = JSON.parse(text) as exportedData;
  const error = validateExportedData(data);
  if (error !== '') throw new Error(error);
  return data;
}

// Revalidate on explicit confirmation: campus settings may have changed while previewing.
export function confirmScheduleImport(data: exportedData): number {
  const error = validateExportedData(data);
  if (error !== '') throw new Error(error);
  return appendBackup(data.semesters);
}
