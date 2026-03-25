/** Kappa parser generator — one run produces parsers for all target languages. */

import { writeFileSync, mkdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { emitTypeScript } from './emit-typescript.js';
import { emitPython } from './emit-python.js';
import { emitRust } from './emit-rust.js';
import { emitGo } from './emit-go.js';
import { emitJava } from './emit-java.js';

const root = join(new URL('.', import.meta.url).pathname, '../../parsers');

const targets: { name: string; dir: string; emit: () => Record<string, string> }[] = [
  { name: 'TypeScript', dir: 'typescript-gen/src', emit: emitTypeScript },
  { name: 'Python',     dir: 'python',             emit: emitPython },
  { name: 'Rust',       dir: 'rust/src',            emit: emitRust },
  { name: 'Go',         dir: 'go',                  emit: emitGo },
  { name: 'Java',       dir: 'java/src/main/java/dev/kappa', emit: emitJava },
];

let totalFiles = 0;

for (const target of targets) {
  console.log(`\n── ${target.name} ──`);
  const files = target.emit();
  const outDir = join(root, target.dir);
  mkdirSync(outDir, { recursive: true });

  for (const [filename, content] of Object.entries(files)) {
    const path = join(outDir, filename);
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, content);
    const lines = content.split('\n').length;
    console.log(`  ${filename} (${lines} lines)`);
    totalFiles++;
  }
}

console.log(`\nGenerated ${totalFiles} files for ${targets.length} languages.`);
