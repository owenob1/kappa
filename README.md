<div align="center">

# Kappa

**Describe an application once. Generate everything from it.**

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

Kappa is a specification language for application data models, constraints, relationships, authorization, and workflows. One `.kappa` file replaces the 6+ files that typically describe the same information in different syntaxes — and any of those files can be generated from it.

```kappa
User {
  id: id*,
  email: s*@~,
  name: s*(1,100),
  role: (admin|editor|viewer),
  active: b=true,
  created: dt!
}
```

> `email` is required (`*`), unique (`@`), indexed (`~`). `name` is 1-100 characters. `role` is one of three values. `active` defaults to `true`. `created` is immutable (`!`). Six decisions in 7 lines.

---

## Why Kappa

Building an application means expressing the same decisions in multiple syntaxes:

```
schema.sql          →  CREATE TABLE users (email TEXT NOT NULL UNIQUE ...)
types.ts            →  interface User { email: string; ... }
validators.ts       →  z.object({ email: z.string().email() ... })
api/users/route.ts  →  export async function GET(req) { ... }
components/User.tsx →  <input name="email" required ... />
tests/user.test.ts  →  it('should reject missing email', () => { ... })
```

Six files. One truth. Every repetition is an opportunity for drift, inconsistency, and bugs.

Kappa captures the truth once. Everything else is derived.

---

## The Notation

### Dense — for data models

5-7 characters per field. Every decision visible at a glance.

```kappa
Product {
  id: id*,
  sku: s*@~(8,20),
  name: s*(1,200),
  description: t,
  price: f*(0.01,),
  stock: i(0,)=0,
  status: (draft|active|discontinued),
  category: Category*,
  images: [s],
  created: dt!
}
```

<details>
<summary><strong>Type codes &amp; modifiers reference</strong></summary>

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
| `x` | Binary | | | |

Modifiers stack: `s*@~` = required, unique, indexed string.

References: `author: User*` (required FK), `team: Team?` (optional FK)

Enums: `status: (draft|published|archived)`

Arrays: `tags: [s]`, `items: [OrderItem]`

</details>

### Full — for logic

When dense notation isn't enough: computed fields, authorization, workflows, pattern matching.

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

Both notations mix freely in the same file. Both produce the same AST.

---

## How It Works

```
                          ┌─────────────────┐
                          │   .kappa file    │
                          └────────┬────────┘
                                   │
                                   ▼
                          ┌─────────────────┐
                          │     Parser      │  Deterministic
                          └────────┬────────┘
                                   │
                                   ▼
                          ┌─────────────────┐
                          │      AST        │  Portable
                          └───┬────┬────┬───┘
                              │    │    │
              ┌───────────────┤    │    ├───────────────┐
              ▼               ▼    ▼    ▼               ▼
        ┌───────────┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐
        │  Schema   │  │ Types│  │ API  │  │  UI  │  │ Tests│
        │ Generator │  │ Gen  │  │ Gen  │  │ Gen  │  │ Gen  │
        └───────────┘  └──────┘  └──────┘  └──────┘  └──────┘
```

**One parser. Many generators. Zero AI in the pipeline.**

The parser reads `.kappa` files and produces a structured AST. Code generators read the AST and emit target-specific code. Each generator is deterministic — same AST in, same code out.

The parser also works in reverse: input adapters read existing schemas (OpenAPI, SQL DDL, GraphQL SDL, Prisma) and produce Kappa specs from them.

---

## Complete Example

A multi-tenant SaaS task manager in ~40 lines:

```kappa
Organization {
  id: id*,
  name: s*,
  slug: s*@!(3,)
}

Project {
  id: id*,
  org: Organization*,
  name: s*,
  status: (planning|active|archived)=planning,

  capability member {
    scope: fn(user: User) => user.org == this.org
    actions: ["read", "update"]
  }

  capability admin {
    scope: fn(user: User) => user.role == "admin" && user.org == this.org
    actions: ["read", "update", "delete", "archive"]
  }
}

Task {
  id: id*,
  project: Project*,
  title: s*(1,500),
  assignee: User?,
  priority: (low|medium|high|urgent)=medium,
  due: d?,
  completed: b=false,

  urgency_score: Integer = fn() => match this.priority with {
    "urgent" => 4, "high" => 3, "medium" => 2, "low" => 1
  },

  workflow onUpdate {
    when this.completed && !this.was(completed) then {
      notify(this.assignee, "Task completed")
    }
  }
}
```

From this spec, generators produce: database schema with relations, TypeScript types, validation schemas, CRUD API endpoints with authorization middleware, UI forms and tables, and test suites.

---

## Documentation

| Document | Description |
|----------|-------------|
| [Language Specification](spec/language.md) | Complete reference — types, syntax, expressions, workflows, capabilities, type system, standard library |
| [Dense Notation Reference](spec/dense-notation.md) | Quick reference card for the compact syntax |
| [Dense Grammar (EBNF)](spec/grammar-dense.ebnf) | Formal grammar for dense notation (ISO/IEC 14977) |
| [Full Grammar (EBNF)](spec/grammar-full.ebnf) | Formal grammar for full syntax (ISO/IEC 14977) |

### Examples

| Example | Syntax | What it demonstrates |
|---------|--------|---------------------|
| [Blog](examples/dense/user-blog.kappa) | Dense | Users, posts, comments, references, enums |
| [E-commerce](examples/dense/ecommerce.kappa) | Dense | Products, orders, line items, integer-cents pattern |
| [SaaS Project Manager](examples/dense/saas-multitenant.kappa) | Dense | Multi-tenancy, roles, task hierarchy, labels |
| [Order with Logic](examples/full/order-with-logic.kappa) | Full | Computed fields, pattern matching, authorization, workflows |

---

## Status

Kappa is a working specification. The language design is stable — the notation, type system, full syntax, and formal grammars are defined and documented.

The parser and code generators are under development.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on reporting issues, proposing changes, adding examples, and building generators.

## License

[MIT](LICENSE)
