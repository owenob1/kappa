<div align="center">

<img src="assets/logo.svg" alt="Kappa" width="120" height="120" />

<h1>Kappa</h1>

**One spec. Every artifact. Zero repetition.**

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

Kappa is a specification language that replaces the 6+ files describing every data model in your application with one.

```kappa
User { id: id*, email: s*@~, name: s*(1,100), role: (admin|editor|viewer), active: b=true, created: dt! }
```

That single line defines everything: the schema column, the TypeScript type, the validation rule, the form input, and the test case — for every field. A parser reads it. Generators produce the code. Nothing is written twice.

---

## The problem

Every application repeats the same decisions in different syntaxes:

```
schema.sql          →  email TEXT NOT NULL UNIQUE
types.ts            →  email: string
validators.ts       →  email: z.string().email()
api/users/route.ts  →  if (!body.email) return 400
components/User.tsx →  <input name="email" required />
tests/user.test.ts  →  it('rejects missing email', ...)
```

Six files. One fact: email is a required, unique string. Change the constraint in the schema, forget the validator — invalid data gets through. Add a field to the type, miss the API — the frontend crashes. Every repetition is a place where drift, inconsistency, and bugs enter.

For AI-assisted development, the cost is worse. An LLM reading your codebase spends 70–80% of its context window on boilerplate — the same information restated in different formats. Fewer tokens for reasoning. More surface for error.

## The solution

Write the decision once. Derive everything else.

```kappa
email: s*@~
```

Four characters. Required (`*`), unique (`@`), indexed (`~`), string (`s`). A parser reads this notation and produces a structured AST. Code generators read the AST and emit target-specific code — Drizzle schemas, Zod validators, API routes, React components, test suites. Each generator is deterministic: same AST in, same code out.

<img src="assets/pipeline.svg" alt="Kappa Pipeline" width="800" />

Input adapters work in reverse: feed in an OpenAPI spec, a SQL schema, or a GraphQL SDL, and the parser produces the Kappa notation from it. Existing codebases don't need to be rewritten — they can be read.

---

## Dense notation

The compact syntax for data models. Every field is 5–7 characters. Every decision is visible at a glance.

```kappa
Product { id: id*, sku: s*@~(8,20), name: s*(1,200), price: f*(0.01,), stock: i(0,)=0, status: (draft|active|discontinued), category: Category*, images: [s], created: dt! }
```

One entity. One line. Ten fields with types, constraints, defaults, references, enums, and an immutable timestamp.

<details>
<summary><strong>Notation reference</strong></summary>

| Code | Type | &nbsp; | Modifier | Meaning |
|------|------|---|----------|---------|
| `s` | String | | `*` | Required |
| `t` | Text (unlimited) | | `?` | Optional |
| `i` | Integer | | `!` | Immutable |
| `f` | Float | | `~` | Indexed |
| `b` | Boolean | | `@` | Unique |
| `d` | Date | | `=val` | Default |
| `dt` | DateTime | | `(min,max)` | Constraint |
| `id` | Identifier | | `++` | Auto-increment |

Modifiers stack: `s*@~` = required, unique, indexed string.

References: `author: User*` (required FK) &nbsp;&nbsp; Enums: `(a|b|c)` &nbsp;&nbsp; Arrays: `[s]`

</details>

## Full syntax

When dense notation isn't enough — computed fields, authorization, workflows, pattern matching — the full syntax handles logic:

```kappa
entity Order {
  items: [OrderItem]
  status: (pending|paid|shipped|cancelled) = "pending"

  total: Float = fn() =>
    this.items |> sum(item => item.price * item.quantity)

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

Both notations mix in the same file. Both produce the same AST. Dense for structure. Full for logic.

---

## What makes Kappa different

**Designed for AI consumption, not just human readability.** Existing schema languages (Prisma, Drizzle, GraphQL SDL) were built for developers to write and tools to process. Kappa was designed backwards from the question: what is the minimum unambiguous input that produces correct output? The dense notation is the answer — a constrained vocabulary where every character carries meaning and no character is decorative.

**Dual syntax to a single AST.** No other schema language offers both an ultra-compact notation for data and an expression language for logic that compile to the same intermediate representation. You choose the syntax that fits the decision, not the one the tool requires.

**Bidirectional.** Most schema tools go one direction: definition → code. Kappa goes both ways. Input adapters read existing schemas (OpenAPI, SQL, GraphQL) and produce Kappa specs. Output generators read Kappa specs and produce target code. Your existing codebase becomes a Kappa spec without rewriting anything.

**Stack-agnostic.** The spec describes what the application IS, not how it's built. The same `.kappa` file generates a Drizzle schema or a Django model or a Go struct. Switching stacks is a generator swap, not a rewrite.

---

## Examples

An entire e-commerce backend in 5 lines:

```kappa
Category { id: id*, name: s*, slug: s*@, parent: Category?, sort_order: i=0 }
Product { id: id*, sku: s*@~(8,20), name: s*(1,200), description: t, price: i*(0,), stock: i*(0,)=0, status: (draft|active|discontinued)=draft, category: Category*, images: [s], created: dt! }
Customer { id: id*, email: s*@~, name: s*, phone: s?, country: s*(2,2)="AU", created: dt! }
Order { id: id*, customer: Customer*, status: (pending|paid|shipped|delivered|cancelled|refunded)=pending, subtotal: i*(0,), tax: i*(0,)=0, total: i*(0,), currency: s*(3,3)="AUD", created: dt!, updated: dt }
OrderLine { id: id*, order: Order*, product: Product*, quantity: i*(1,), unit_price: i*, total: i*, line_number: i++ }
```

More examples across domains:

| Example | Domain | Entities |
|---------|--------|----------|
| [Blog](examples/dense/user-blog.kappa) | Content | Users, posts, comments |
| [E-commerce](examples/dense/ecommerce.kappa) | Commerce | Products, orders, line items |
| [SaaS Project Manager](examples/dense/saas-multitenant.kappa) | Productivity | Multi-tenant orgs, projects, tasks |
| [AI Chat Platform](examples/dense/ai-chat-saas.kappa) | AI/ML | Conversations, messages, tool calls, usage billing |
| [ML Platform](examples/dense/ml-platform.kappa) | AI/ML | Experiments, runs, datasets, model registry |
| [Compiler Pipeline](examples/dense/compiler-pipeline.kappa) | Systems | Source files, AST, symbols, IR, diagnostics |
| [Quantum Lab](examples/dense/quantum-lab.kappa) | Research | Backends, circuits, jobs, results, calibration |
| [Order with Logic](examples/full/order-with-logic.kappa) | Full syntax | Computed fields, authorization, workflows |

---

## Specification

| Document | What it covers |
|----------|---------------|
| [Language Specification](spec/language.md) | Types, syntax, expressions, workflows, capabilities, type system, standard library |
| [Dense Notation Reference](spec/dense-notation.md) | Quick reference for the compact syntax |
| [Dense Grammar (EBNF)](spec/grammar-dense.ebnf) | Formal grammar — ISO/IEC 14977 |
| [Full Grammar (EBNF)](spec/grammar-full.ebnf) | Formal grammar — ISO/IEC 14977 |

---

## Status

Kappa is a working specification. The notation, type system, full syntax, and formal grammars are defined and documented. The parser and code generators are under development.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
