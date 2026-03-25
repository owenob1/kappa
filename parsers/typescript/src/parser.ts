/** Recursive descent parser for Kappa dense notation. */

import { Lexer, TokenType } from './lexer.js';
import {
  TYPE_CODES,
  type TypeCode,
  type KappaFile,
  type Entity,
  type Field,
  type FieldType,
  type Constraint,
  type DefaultValue,
  type Diagnostic,
} from './ast.js';

export type FieldCallback = (field: Field, entityName: string) => void;
export type EntityCallback = (entity: Entity) => void;

export interface ParseOptions {
  /** Called when a field is fully parsed (fires on comma/closing brace). */
  onField?: FieldCallback;
  /** Called when an entity is fully parsed (fires on closing brace). */
  onEntity?: EntityCallback;
}

export class Parser {
  private lex: Lexer;
  private diag: Diagnostic[] = [];
  private onField?: FieldCallback;
  private onEntity?: EntityCallback;

  constructor(source: string, opts?: ParseOptions) {
    this.lex = new Lexer(source);
    this.onField = opts?.onField;
    this.onEntity = opts?.onEntity;
  }

  parse(): KappaFile {
    const entities: Entity[] = [];
    while (!this.lex.check(TokenType.EOF)) {
      try {
        const ent = this.entity();
        entities.push(ent);
        this.onEntity?.(ent);
      } catch (e) {
        this.diagnostic(e);
        this.recoverEntity();
      }
    }
    return { kind: 'file', entities, diagnostics: this.diag };
  }

  // --- entity ---

  private entity(): Entity {
    const name = this.lex.expect(TokenType.Ident).value;
    this.lex.expect(TokenType.LBrace);
    const fields = this.fieldList(name);
    this.lex.expect(TokenType.RBrace);
    return { kind: 'entity', name, fields };
  }

  private fieldList(entityName: string): Field[] {
    const fields: Field[] = [];
    if (this.lex.check(TokenType.RBrace)) return fields;

    const f = this.field(entityName);
    if (f) fields.push(f);

    while (this.lex.check(TokenType.Comma)) {
      this.lex.next(); // consume comma
      if (this.lex.check(TokenType.RBrace)) break; // trailing comma
      const f2 = this.field(entityName);
      if (f2) fields.push(f2);
    }
    return fields;
  }

  // --- field ---

  private field(entityName: string): Field | null {
    try {
      const name = this.lex.expect(TokenType.Ident).value;
      this.lex.expect(TokenType.Colon);
      const type = this.fieldType();
      const mods = this.modifiers();
      const def = this.defaultValue();

      const f: Field = {
        kind: 'field',
        name,
        type,
        required: mods.required,
        optional: mods.optional,
        immutable: mods.immutable,
        indexed: mods.indexed,
        unique: mods.unique,
        autoIncrement: mods.autoIncrement,
      };
      if (mods.constraint) f.constraint = mods.constraint;
      if (def !== undefined) f.default = def;

      this.onField?.(f, entityName);
      return f;
    } catch (e) {
      this.diagnostic(e);
      this.recoverField();
      return null;
    }
  }

  // --- field type ---

  private fieldType(): FieldType {
    const tok = this.lex.peek();

    if (tok.type === TokenType.LBracket) return this.arrayType();
    if (tok.type === TokenType.LParen) return this.enumType();

    if (tok.type === TokenType.Ident) {
      this.lex.next();
      if (TYPE_CODES.has(tok.value)) {
        return { kind: 'primitive', code: tok.value as TypeCode };
      }
      return { kind: 'reference', entity: tok.value };
    }

    throw this.lex.error(`Expected field type, got ${TokenType[tok.type]}`, tok);
  }

  private arrayType(): FieldType {
    this.lex.expect(TokenType.LBracket);
    const el = this.fieldType();
    this.lex.expect(TokenType.RBracket);
    return { kind: 'array', elementType: el };
  }

  private enumType(): FieldType {
    this.lex.expect(TokenType.LParen);
    const values: string[] = [this.lex.expect(TokenType.Ident).value];
    while (this.lex.check(TokenType.Pipe)) {
      this.lex.next();
      values.push(this.lex.expect(TokenType.Ident).value);
    }
    this.lex.expect(TokenType.RParen);
    return { kind: 'enum', values };
  }

  // --- modifiers ---

  private modifiers() {
    let required = false;
    let optional = false;
    let immutable = false;
    let indexed = false;
    let unique = false;
    let autoIncrement = false;
    let constraint: Constraint | undefined;

    loop: while (true) {
      switch (this.lex.peek().type) {
        case TokenType.Star:     this.lex.next(); required = true; break;
        case TokenType.Question: this.lex.next(); optional = true; break;
        case TokenType.Bang:     this.lex.next(); immutable = true; break;
        case TokenType.Tilde:    this.lex.next(); indexed = true; break;
        case TokenType.At:       this.lex.next(); unique = true; break;
        case TokenType.PlusPlus: this.lex.next(); autoIncrement = true; break;
        case TokenType.LParen:   constraint = this.constraint(); break;
        default: break loop;
      }
    }
    return { required, optional, immutable, indexed, unique, autoIncrement, constraint };
  }

  private constraint(): Constraint {
    this.lex.expect(TokenType.LParen);
    let min: number | undefined;
    let max: number | undefined;

    if (this.lex.check(TokenType.Number)) {
      min = parseFloat(this.lex.next().value);
    }

    if (this.lex.check(TokenType.Comma)) {
      this.lex.next(); // comma
      if (this.lex.check(TokenType.Number)) {
        max = parseFloat(this.lex.next().value);
      }
    } else {
      // (n) without comma = exact value
      max = min;
    }

    this.lex.expect(TokenType.RParen);

    const c: Constraint = {};
    if (min !== undefined) c.min = min;
    if (max !== undefined) c.max = max;
    return c;
  }

  // --- default ---

  private defaultValue(): DefaultValue | undefined {
    if (!this.lex.check(TokenType.Equals)) return undefined;
    this.lex.next(); // consume =

    const tok = this.lex.next();
    switch (tok.type) {
      case TokenType.String: return tok.value;
      case TokenType.Number: return parseFloat(tok.value);
      case TokenType.Ident:
        if (tok.value === 'true') return true;
        if (tok.value === 'false') return false;
        if (tok.value === 'null') return null;
        return tok.value;
      default:
        throw this.lex.error(`Expected default value, got ${TokenType[tok.type]}`, tok);
    }
  }

  // --- error handling ---

  private diagnostic(e: unknown): void {
    const msg = e instanceof Error ? e.message : String(e);
    const tok = this.lex.peek();
    this.diag.push({ message: msg, line: tok.line, column: tok.column, offset: tok.offset });
  }

  private recoverField(): void {
    while (true) {
      const t = this.lex.peek().type;
      if (t === TokenType.Comma || t === TokenType.RBrace || t === TokenType.EOF) return;
      this.lex.next();
    }
  }

  private recoverEntity(): void {
    let depth = 0;
    while (true) {
      const t = this.lex.peek().type;
      if (t === TokenType.EOF) return;
      if (t === TokenType.LBrace) depth++;
      if (t === TokenType.RBrace) {
        this.lex.next();
        if (depth <= 1) return;
        depth--;
        continue;
      }
      this.lex.next();
    }
  }
}
