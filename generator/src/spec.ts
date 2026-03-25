/** Parser specification — shared data driving all language emitters. */

export interface TokenDef {
  name: string;
  literal?: string;
}

export interface TypeCodeDef {
  code: string;
  fullName: string;
}

export interface ModifierDef {
  token: string;
  field: string;
}

export const tokens: TokenDef[] = [
  { name: 'Ident' },
  { name: 'Number' },
  { name: 'String' },
  { name: 'LBrace', literal: '{' },
  { name: 'RBrace', literal: '}' },
  { name: 'LParen', literal: '(' },
  { name: 'RParen', literal: ')' },
  { name: 'LBracket', literal: '[' },
  { name: 'RBracket', literal: ']' },
  { name: 'Colon', literal: ':' },
  { name: 'Comma', literal: ',' },
  { name: 'Pipe', literal: '|' },
  { name: 'Star', literal: '*' },
  { name: 'Question', literal: '?' },
  { name: 'Bang', literal: '!' },
  { name: 'Tilde', literal: '~' },
  { name: 'At', literal: '@' },
  { name: 'Caret', literal: '^' },
  { name: 'Hash', literal: '#' },
  { name: 'PlusPlus', literal: '++' },
  { name: 'Equals', literal: '=' },
  { name: 'EOF' },
];

export const typeCodes: TypeCodeDef[] = [
  { code: 's', fullName: 'String' },
  { code: 't', fullName: 'Text' },
  { code: 'i', fullName: 'Integer' },
  { code: 'f', fullName: 'Float' },
  { code: 'm', fullName: 'Decimal' },
  { code: 'b', fullName: 'Boolean' },
  { code: 'd', fullName: 'Date' },
  { code: 'dt', fullName: 'DateTime' },
  { code: 'id', fullName: 'Identifier' },
  { code: 'x', fullName: 'Binary' },
];

export const modifiers: ModifierDef[] = [
  { token: 'Star', field: 'required' },
  { token: 'Question', field: 'optional' },
  { token: 'Bang', field: 'immutable' },
  { token: 'Tilde', field: 'indexed' },
  { token: 'At', field: 'unique' },
  { token: 'Caret', field: 'hidden' },
  { token: 'PlusPlus', field: 'autoIncrement' },
];

/** Standard format annotations */
export const formats: string[] = [
  'email', 'url', 'phone', 'uuid', 'slug', 'ip', 'hex',
];
