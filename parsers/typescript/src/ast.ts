/** AST node types for Kappa dense notation. */

export type TypeCode = 's' | 't' | 'i' | 'f' | 'b' | 'd' | 'dt' | 'id' | 'x';

export const TYPE_CODES: ReadonlySet<string> = new Set([
  's', 't', 'i', 'f', 'b', 'd', 'dt', 'id', 'x',
]);

export interface PrimitiveType {
  kind: 'primitive';
  code: TypeCode;
}

export interface ArrayType {
  kind: 'array';
  elementType: FieldType;
}

export interface ReferenceType {
  kind: 'reference';
  entity: string;
}

export interface EnumType {
  kind: 'enum';
  values: string[];
}

export type FieldType = PrimitiveType | ArrayType | ReferenceType | EnumType;

export interface Constraint {
  min?: number;
  max?: number;
}

export type DefaultValue = string | number | boolean | null;

export interface Field {
  kind: 'field';
  name: string;
  type: FieldType;
  required: boolean;
  optional: boolean;
  immutable: boolean;
  indexed: boolean;
  unique: boolean;
  autoIncrement: boolean;
  constraint?: Constraint;
  default?: DefaultValue;
}

export interface Entity {
  kind: 'entity';
  name: string;
  fields: Field[];
}

export interface KappaFile {
  kind: 'file';
  entities: Entity[];
  diagnostics: Diagnostic[];
}

export interface Diagnostic {
  message: string;
  line: number;
  column: number;
  offset: number;
}
