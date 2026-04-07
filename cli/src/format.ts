/** Serialize a KappaFile AST back to canonical dense notation. */

import type { Entity, Field, FieldType, KappaFile, EnumDeclaration } from '@kappa-lang/parser';

function fmtType(t: FieldType): string {
  switch (t.kind) {
    case 'primitive': return t.code;
    case 'reference': return t.entity;
    case 'enum': return `(${t.values.join('|')})`;
    case 'array': return `[${fmtType(t.elementType)}]`;
  }
}

function fmtNum(n: number): string {
  return Number.isInteger(n) ? String(n) : String(n);
}

function fmtField(f: Field): string {
  let s = `${f.name}: ${fmtType(f.type)}`;

  // Canonical modifier order: ? ! @ ~ ^ ++ (constraint) #format =default
  if (f.optional) s += '?';
  if (f.immutable) s += '!';
  if (f.unique) s += '@';
  if (f.indexed) s += '~';
  if (f.hidden) s += '^';
  if (f.autoIncrement) s += '++';

  if (f.constraint) {
    const min = f.constraint.min != null ? fmtNum(f.constraint.min) : '';
    const max = f.constraint.max != null ? fmtNum(f.constraint.max) : '';
    s += `(${min},${max})`;
  }

  if (f.format) s += `#${f.format}`;

  if (f.default !== undefined && f.default !== null) {
    const d = f.default;
    if (typeof d === 'boolean') s += `=${d}`;
    else if (typeof d === 'number') s += `=${fmtNum(d)}`;
    else if (typeof d === 'string') s += `="${d.replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`;
  } else if (f.default === null) {
    s += '=null';
  }

  return s;
}

function fmtEntity(e: Entity): string {
  const fields = e.fields.map(fmtField).join(', ');
  let s = `${e.name} { ${fields} }`;
  for (const uc of e.uniqueConstraints) {
    s += ` @unique(${uc.join(', ')})`;
  }
  return s;
}

function fmtEnumDecl(d: EnumDeclaration): string {
  return `enum ${d.name} (${d.values.join('|')})`;
}

export function format(file: KappaFile): string {
  const parts: string[] = [];
  for (const e of file.enumDeclarations) {
    parts.push(fmtEnumDecl(e));
  }
  for (const e of file.entities) {
    parts.push(fmtEntity(e));
  }
  return parts.join('\n') + '\n';
}
