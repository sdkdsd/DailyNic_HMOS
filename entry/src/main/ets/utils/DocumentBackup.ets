import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';

export function readBackupUri(uri: string): string {
  // Preserve the picker-granted URI; stripping it to a path loses document access.
  const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
  try {
    const size = fileIo.statSync(file.fd).size;
    if (size <= 0 || size > 5 * 1024 * 1024) throw new Error('备份须为非空且不超过 5 MiB 的 JSON 文件');
    const buffer = new ArrayBuffer(size);
    if (fileIo.readSync(file.fd, buffer) !== size) throw new Error('备份读取不完整，请重新选择文件');
    return util.TextDecoder.create('utf-8', { fatal: true }).decodeWithStream(new Uint8Array(buffer));
  } finally {
    fileIo.closeSync(file);
  }
}

export function writeBackupUri(uri: string, text: string): void {
  const bytes = new util.TextEncoder().encodeInto(text);
  const file = fileIo.openSync(uri, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
  try {
    if (fileIo.writeSync(file.fd, bytes.buffer) !== bytes.byteLength) throw new Error('备份未完整写入，请重新导出');
    fileIo.fsyncSync(file.fd);
  } finally {
    fileIo.closeSync(file);
  }
}
