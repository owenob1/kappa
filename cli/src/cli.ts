#!/usr/bin/env node
/** Kappa language CLI. */

import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { parse } from '@kappa-lang/parser';
import { format } from './format.js';

const VERSION = '0.1.0';

const HELP = `kappa — Kappa language CLI

Usage:
  kappa parse <file>           Parse and output AST as JSON
  kappa validate <file...>     Validate .kappa files
  kappa fmt <file...> [--write]  Format .kappa files

Options:
  --help, -h     Show this help
  --version, -v  Show version

Examples:
  kappa parse schema.kappa
  kappa validate src/*.kappa
  kappa fmt schema.kappa --write
`;

function readSource(file: string): { path: string; source: string } {
  const p = resolve(file);
  try {
    return { path: p, source: readFileSync(p, 'utf-8') };
  } catch {
    console.error(`error: cannot read '${file}'`);
    process.exit(1);
  }
}

function cmdParse(files: string[]) {
  if (files.length === 0) {
    console.error('error: missing file argument');
    process.exit(1);
  }
  const { source } = readSource(files[0]);
  const result = parse(source);
  console.log(JSON.stringify(result, null, 2));
  process.exit(result.diagnostics.length > 0 ? 1 : 0);
}

function cmdValidate(files: string[]) {
  if (files.length === 0) {
    console.error('error: missing file argument');
    process.exit(1);
  }
  let errors = 0;
  for (const file of files) {
    const { source } = readSource(file);
    const result = parse(source);
    if (result.diagnostics.length === 0) {
      const n = result.entities.length;
      const e = result.enumDeclarations.length;
      const parts = [`${n} entit${n === 1 ? 'y' : 'ies'}`];
      if (e > 0) parts.push(`${e} enum${e === 1 ? '' : 's'}`);
      console.log(`  ok  ${file}  (${parts.join(', ')})`);
    } else {
      for (const d of result.diagnostics) {
        console.error(`  ${file}:${d.line}:${d.column}: ${d.message}`);
      }
      errors += result.diagnostics.length;
    }
  }
  if (errors > 0) {
    console.error(`\n${errors} error${errors === 1 ? '' : 's'}`);
  }
  process.exit(errors > 0 ? 1 : 0);
}

function cmdFmt(files: string[], write: boolean) {
  if (files.length === 0) {
    console.error('error: missing file argument');
    process.exit(1);
  }
  let failed = false;
  for (const file of files) {
    const { path, source } = readSource(file);
    const result = parse(source);
    if (result.diagnostics.length > 0) {
      for (const d of result.diagnostics) {
        console.error(`  ${file}:${d.line}:${d.column}: ${d.message}`);
      }
      console.error(`  cannot format '${file}' — parse errors`);
      failed = true;
      continue;
    }
    const formatted = format(result);
    if (write) {
      if (formatted === source) {
        console.log(`  unchanged  ${file}`);
      } else {
        writeFileSync(path, formatted);
        console.log(`  formatted  ${file}`);
      }
    } else {
      process.stdout.write(formatted);
    }
  }
  process.exit(failed ? 1 : 0);
}

function main() {
  const args = process.argv.slice(2);

  if (args.length === 0 || args.includes('--help') || args.includes('-h')) {
    console.log(HELP);
    process.exit(0);
  }

  if (args.includes('--version') || args.includes('-v')) {
    console.log(`kappa ${VERSION}`);
    process.exit(0);
  }

  const command = args[0];
  const rest = args.slice(1);
  const flags = rest.filter(a => a.startsWith('-'));
  const files = rest.filter(a => !a.startsWith('-'));

  switch (command) {
    case 'parse':
      cmdParse(files);
      break;
    case 'validate':
      cmdValidate(files);
      break;
    case 'fmt':
    case 'format':
      cmdFmt(files, flags.includes('--write') || flags.includes('-w'));
      break;
    default:
      console.error(`unknown command: '${command}'\n`);
      console.log(HELP);
      process.exit(1);
  }
}

main();
