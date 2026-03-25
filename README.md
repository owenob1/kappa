<div align="center">

<img src="assets/logo.svg" alt="Kappa" width="120" height="120" />

<h1>Kappa</h1>

**A specification language for describing applications in the fewest possible tokens.**

<sub><i>Kappa captures data models, constraints, relationships, authorization, and workflows in a notation so compact that an entire entity fits on one line — and so precise that a parser can generate a full application from it. Write the spec once. Generate schemas, types, validators, APIs, UI, and tests from it. Nothing is repeated. Nothing drifts.</i></sub>

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Spec: Stable](https://img.shields.io/badge/Spec-Stable-green.svg)](spec/language.md)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

<a href="spec/language.md">Specification</a>
<span>&nbsp;&nbsp;&bull;&nbsp;&nbsp;</span>
<a href="spec/dense-notation.md">Dense Notation</a>
<span>&nbsp;&nbsp;&bull;&nbsp;&nbsp;</span>
<a href="examples/">Examples</a>
<span>&nbsp;&nbsp;&bull;&nbsp;&nbsp;</span>
<a href="CONTRIBUTING.md">Contributing</a>

---

</div>

```kappa
User { id: id*, email: s*@~, name: s*(1,100), role: (admin|editor|viewer), active: b=true, created: dt! }
```

One line. Six fields. Required (`*`), unique (`@`), indexed (`~`), constrained (`1,100`), defaulted (`=true`), immutable (`!`). A parser reads this and generates the database column, the TypeScript type, the validation rule, the form input, and the test case for every field.

---

## Why

Every application describes the same information 6+ times — schema, types, validators, API, UI, tests. Each copy is a place where things go wrong. Kappa eliminates the copies.

For AI-assisted development, the cost is compounded: an LLM spends most of its context window reading boilerplate. Kappa was designed for minimum input, maximum correctness — a constrained vocabulary where every character carries meaning and nothing is decorative.

## How

```
.kappa file → Parser → AST → Generators → target code
```

<img src="assets/pipeline.svg" alt="Kappa Pipeline" width="800" />

The parser is deterministic. The generators are deterministic. Input adapters read existing schemas (OpenAPI, SQL, GraphQL) and produce Kappa. Output generators read Kappa and produce code for any stack. Same spec, different targets.

**Streaming parse.** The dense notation parses incrementally, token by token — no buffering, no lookahead. Each field emits a complete AST node on the comma delimiter. When an LLM streams Kappa output, code generation begins before the spec is fully written. The schema column for `email` can be generated while the model is still producing the next field.

## Dense notation

The compact syntax. One entity per line.

```kappa
Product { id: id*, sku: s*@~(8,20), name: s*(1,200), price: f*(0.01,), stock: i(0,)=0, status: (draft|active|discontinued), category: Category*, created: dt! }
```

<details>
<summary><strong>Reference</strong></summary>

| Code | Type | &nbsp; | Modifier | Meaning |
|------|------|---|----------|---------|
| `s` | String | | `*` | Required |
| `t` | Text | | `?` | Optional |
| `i` | Integer | | `!` | Immutable |
| `f` | Float | | `~` | Indexed |
| `b` | Boolean | | `@` | Unique |
| `d` | Date | | `=val` | Default |
| `dt` | DateTime | | `(min,max)` | Constraint |
| `id` | Identifier | | `++` | Auto-increment |

References: `author: User*` &nbsp; Enums: `(a|b|c)` &nbsp; Arrays: `[s]`

</details>

## Full syntax

For logic that dense notation can't express — computed fields, authorization, workflows:

```kappa
entity Order {
  items: [OrderItem]
  status: (pending|paid|shipped|cancelled) = "pending"

  total: Float = fn() => this.items |> sum(item => item.price * item.quantity)

  capability owner {
    scope: fn(user: User) => this.customer == user
    actions: ["read", "update", "cancel"]
  }

  workflow onUpdate {
    when this.status == "paid" then {
      notify(this.customer, "Payment confirmed")
      inventory.reserve(this.items)
    }
  }
}
```

Both syntaxes mix in the same file. Both produce the same AST.

---

## Examples

| Example | Domain |
|---------|--------|
| [Blog](examples/dense/user-blog.kappa) | Users, posts, comments |
| [E-commerce](examples/dense/ecommerce.kappa) | Products, orders, line items |
| [SaaS Project Manager](examples/dense/saas-multitenant.kappa) | Multi-tenant orgs, projects, tasks |
| [AI Chat Platform](examples/dense/ai-chat-saas.kappa) | Conversations, messages, tool calls, billing |
| [ML Platform](examples/dense/ml-platform.kappa) | Experiments, runs, datasets, model registry |
| [Compiler Pipeline](examples/dense/compiler-pipeline.kappa) | Source files, AST, symbols, IR, diagnostics |
| [Quantum Lab](examples/dense/quantum-lab.kappa) | Backends, circuits, jobs, calibration |
| [Order with Logic](examples/full/order-with-logic.kappa) | Computed fields, authorization, workflows |
| [Streaming Parse](examples/streaming/incremental-parse.md) | Token-by-token incremental parsing from LLM output |

## Specification

- [Language Specification](spec/language.md) — complete reference
- [Dense Notation Reference](spec/dense-notation.md) — quick reference
- [Dense Grammar (EBNF)](spec/grammar-dense.ebnf) — formal grammar
- [Full Grammar (EBNF)](spec/grammar-full.ebnf) — formal grammar

## Status

Working specification. Parser and generators under development.

## License

[MIT](LICENSE)
