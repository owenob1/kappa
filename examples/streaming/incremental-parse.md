# Streaming Parse Example

Kappa's dense notation parses incrementally from a token stream. Each field emits a complete AST node on the comma delimiter — no buffering, no backtracking.

## Token-by-token

As an LLM streams output:

```
Token stream:  U s e r   {   e m a i l :   s @ ~ # e m a i l ,
                                                               ↑ emit field: { name: "email", type: "s", unique: true, indexed: true, format: "email" }

Token stream:  n a m e :   s ( 1 , 1 0 0 ) ,
                                             ↑ emit field: { name: "name", type: "s", required: true, min: 1, max: 100 }

Token stream:  a c t i v e :   b = t r u e ,
                                              ↑ emit field: { name: "active", type: "b", default: true }

Token stream:  c r e a t e d :   d t ! ^ }
                                          ↑ emit field: { name: "created", type: "dt", immutable: true, hidden: true }
                                          ↑ emit entity: User (4 fields)
```

## What this enables

A code generator connected to the parser's output stream can produce artifacts while the spec is still being written:

```
Field "email" parsed   → CREATE TABLE users (email TEXT NOT NULL UNIQUE); CREATE INDEX ...
Field "name" parsed    → , name TEXT NOT NULL CHECK(length(name) BETWEEN 1 AND 100)
Field "active" parsed  → , active BOOLEAN NOT NULL DEFAULT false
...entity closed       → ); -- complete table
```

The schema, types, validators, and test stubs for each field can begin generating the moment that field's comma is parsed — before the entity is complete.

## Partial validity

```kappa
User { email: s@~#email, name: s(1,100)
```

This is a valid partial parse. Two complete fields. The entity isn't closed — the parser is waiting for more tokens or a `}`. But the two fields are fully specified and code generation can proceed for them.

If the stream ends abruptly (connection drop, timeout, context limit), the partial parse is still useful. The fields received are valid. Only the entity closure is missing.

## Error recovery

```kappa
User { email: s@~#email, badfield: q, name: s }
```

`q` is not a valid type code. The parser reports an error at `badfield` and continues. `email` and `name` are both valid and emitted. Error locality means one bad field doesn't invalidate the rest.
