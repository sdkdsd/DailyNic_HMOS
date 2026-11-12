// Host-only loader for pure .ets logic. This is NOT an ArkTS compiler or HarmonyOS runtime.
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, basename } from 'node:path';
import { pathToFileURL } from 'node:url';
const directory = mkdtempSync(join(tmpdir(), 'sust-logic-test-'));
let index = 0;
process.on('exit', () => rmSync(directory, { recursive: true, force: true }));
export const asURL = source => 'data:text/javascript;base64,' + Buffer.from(source).toString('base64');
export async function loadLogic(relativePath, dependencies) {
  const source = await readFile(new URL('../entry/src/main/ets/' + relativePath, import.meta.url), 'utf8');
  const javascript = stripTypeScriptTypes(source, { mode: 'transform' }).replace(/from\s+(['"])([^'"]+)\1/g, (match, quote, specifier) => {
    if (!dependencies[specifier]) throw new Error(`Missing explicit host stub: ${specifier}`);
    return `from ${JSON.stringify(dependencies[specifier])}`;
  });
  const path = join(directory, `${++index}-${basename(relativePath)}.mjs`);
  writeFileSync(path, javascript);
  const url = pathToFileURL(path).href;
  return { url, module: await import(url) };
}
