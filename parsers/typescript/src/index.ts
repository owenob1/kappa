/** Kappa dense notation parser — public API. */

export type {
  TypeCode,
  PrimitiveType,
  ArrayType,
  ReferenceType,
  EnumType,
  FieldType,
  Constraint,
  DefaultValue,
  Field,
  Entity,
  KappaFile,
  Diagnostic,
} from './ast.js';

export { TYPE_CODES } from './ast.js';
export { Parser } from './parser.js';
export type { ParseOptions, FieldCallback, EntityCallback } from './parser.js';
export { StreamingParser } from './stream.js';
export type { FieldHandler, EntityHandler, ErrorHandler } from './stream.js';

import { Parser } from './parser.js';
import type { KappaFile } from './ast.js';

/** Parse a Kappa dense notation string into an AST. */
export function parse(input: string): KappaFile {
  return new Parser(input).parse();
}
