/** Verify parser against all dense notation examples. */

import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { parse } from './index.js';
import { StreamingParser } from './stream.js';

const examplesDir = join(new URL('.', import.meta.url).pathname, '../../../examples/dense');
const files = readdirSync(examplesDir).filter(f => f.endsWith('.kappa'));

let passed = 0;
let failed = 0;

for (const file of files) {
  const path = join(examplesDir, file);
  const src = readFileSync(path, 'utf-8');

  try {
    const result = parse(src);

    if (result.diagnostics.length > 0) {
      console.error(`FAIL ${file}: ${result.diagnostics.length} diagnostic(s)`);
      for (const d of result.diagnostics) {
        console.error(`  ${d.line}:${d.column} ${d.message}`);
      }
      failed++;
      continue;
    }

    const entityCount = result.entities.length;
    const fieldCount = result.entities.reduce((sum, e) => sum + e.fields.length, 0);
    console.log(`PASS ${file}: ${entityCount} entities, ${fieldCount} fields`);

    // verify streaming parser produces identical results
    const stream = new StreamingParser();
    const streamFields: string[] = [];
    stream.onField((f, eName) => streamFields.push(`${eName}.${f.name}`));
    stream.write(src);
    stream.end();

    if (streamFields.length !== fieldCount) {
      console.error(`  STREAM MISMATCH: expected ${fieldCount} fields, got ${streamFields.length}`);
      failed++;
      continue;
    }

    passed++;
  } catch (e) {
    console.error(`FAIL ${file}: ${(e as Error).message}`);
    failed++;
  }
}

console.log(`\n${passed} passed, ${failed} failed out of ${files.length} files`);

// --- spot check: parse a single entity and dump AST ---
console.log('\n--- Spot check ---');
const spotResult = parse('User { id: id*, email: s*@~, name: s*(1,100), role: (admin|editor|viewer)=viewer, active: b=true, created: dt! }');
console.log(JSON.stringify(spotResult.entities[0], null, 2));

process.exit(failed > 0 ? 1 : 0);
