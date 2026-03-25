/** Tokenizer for Kappa dense notation. */

export enum TokenType {
  Ident,
  Number,
  String,
  LBrace,
  RBrace,
  LParen,
  RParen,
  LBracket,
  RBracket,
  Colon,
  Comma,
  Pipe,
  Star,
  Question,
  Bang,
  Tilde,
  At,
  PlusPlus,
  Equals,
  EOF,
}

export interface Token {
  type: TokenType;
  value: string;
  line: number;
  column: number;
  offset: number;
}

export class Lexer {
  private src: string;
  private pos = 0;
  private line = 1;
  private col = 1;
  private peeked: Token | null = null;

  constructor(source: string) {
    this.src = source;
  }

  peek(): Token {
    if (this.peeked === null) {
      this.peeked = this.scan();
    }
    return this.peeked;
  }

  next(): Token {
    if (this.peeked !== null) {
      const t = this.peeked;
      this.peeked = null;
      return t;
    }
    return this.scan();
  }

  check(type: TokenType): boolean {
    return this.peek().type === type;
  }

  expect(type: TokenType): Token {
    const t = this.next();
    if (t.type !== type) {
      throw this.error(
        `Expected ${TokenType[type]} but got ${TokenType[t.type]} ("${t.value}")`,
        t,
      );
    }
    return t;
  }

  error(msg: string, tok?: Token): Error {
    const t = tok ?? this.peek();
    return new Error(`${msg} at ${t.line}:${t.column}`);
  }

  // --- internals ---

  private scan(): Token {
    this.skipWS();
    if (this.pos >= this.src.length) {
      return this.tok(TokenType.EOF, '', this.pos);
    }

    const start = this.pos;
    const ch = this.src[this.pos];

    // single-char punctuation
    const single: Record<string, TokenType> = {
      '{': TokenType.LBrace,
      '}': TokenType.RBrace,
      '(': TokenType.LParen,
      ')': TokenType.RParen,
      '[': TokenType.LBracket,
      ']': TokenType.RBracket,
      ':': TokenType.Colon,
      ',': TokenType.Comma,
      '|': TokenType.Pipe,
      '*': TokenType.Star,
      '?': TokenType.Question,
      '!': TokenType.Bang,
      '~': TokenType.Tilde,
      '@': TokenType.At,
      '=': TokenType.Equals,
    };
    if (ch in single) {
      this.advance();
      return this.tok(single[ch], ch, start);
    }

    // ++
    if (ch === '+' && this.at(1) === '+') {
      this.advance();
      this.advance();
      return this.tok(TokenType.PlusPlus, '++', start);
    }

    // number (or negative number)
    if (isDigit(ch) || (ch === '-' && isDigit(this.at(1)))) {
      return this.scanNumber(start);
    }

    // string
    if (ch === '"' || ch === "'") {
      return this.scanString(start);
    }

    // identifier
    if (isIdentStart(ch)) {
      return this.scanIdent(start);
    }

    this.advance();
    throw new Error(`Unexpected character '${ch}' at ${this.line}:${this.col - 1}`);
  }

  private tok(type: TokenType, value: string, offset: number): Token {
    // compute line/col at the token start
    let line = 1;
    let col = 1;
    for (let i = 0; i < offset; i++) {
      if (this.src[i] === '\n') {
        line++;
        col = 1;
      } else {
        col++;
      }
    }
    return { type, value, line, column: col, offset };
  }

  private at(ahead: number): string {
    const idx = this.pos + ahead;
    return idx < this.src.length ? this.src[idx] : '\0';
  }

  private advance(): void {
    if (this.src[this.pos] === '\n') {
      this.line++;
      this.col = 1;
    } else {
      this.col++;
    }
    this.pos++;
  }

  private skipWS(): void {
    while (this.pos < this.src.length) {
      const ch = this.src[this.pos];
      if (ch === ' ' || ch === '\t' || ch === '\r' || ch === '\n') {
        this.advance();
        continue;
      }
      // line comment
      if (ch === '/' && this.at(1) === '/') {
        this.advance();
        this.advance();
        while (this.pos < this.src.length && this.src[this.pos] !== '\n') {
          this.advance();
        }
        continue;
      }
      // block comment
      if (ch === '/' && this.at(1) === '*') {
        this.advance();
        this.advance();
        while (this.pos < this.src.length) {
          if (this.src[this.pos] === '*' && this.at(1) === '/') {
            this.advance();
            this.advance();
            break;
          }
          this.advance();
        }
        continue;
      }
      break;
    }
  }

  private scanIdent(start: number): Token {
    while (this.pos < this.src.length && isIdentChar(this.src[this.pos])) {
      this.advance();
    }
    return this.tok(TokenType.Ident, this.src.slice(start, this.pos), start);
  }

  private scanNumber(start: number): Token {
    if (this.src[this.pos] === '-') this.advance();
    while (this.pos < this.src.length && isDigit(this.src[this.pos])) {
      this.advance();
    }
    if (this.pos < this.src.length && this.src[this.pos] === '.' && isDigit(this.at(1))) {
      this.advance(); // .
      while (this.pos < this.src.length && isDigit(this.src[this.pos])) {
        this.advance();
      }
    }
    return this.tok(TokenType.Number, this.src.slice(start, this.pos), start);
  }

  private scanString(start: number): Token {
    const quote = this.src[this.pos];
    this.advance(); // opening quote
    const cStart = this.pos;
    while (this.pos < this.src.length && this.src[this.pos] !== quote) {
      if (this.src[this.pos] === '\\') this.advance(); // skip escape
      this.advance();
    }
    const content = this.src.slice(cStart, this.pos);
    if (this.pos < this.src.length) this.advance(); // closing quote
    return this.tok(TokenType.String, content, start);
  }
}

function isDigit(ch: string | undefined): boolean {
  return ch !== undefined && ch >= '0' && ch <= '9';
}

function isIdentStart(ch: string): boolean {
  return (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch === '_';
}

function isIdentChar(ch: string): boolean {
  return isIdentStart(ch) || isDigit(ch);
}
