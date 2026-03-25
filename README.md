# Kappa

**Describe an application once. Generate everything from it.**

Kappa is a specification language that captures data models, constraints, relationships, authorization rules, and workflows in a compact, unambiguous notation. One `.kappa` file replaces the 6+ files that typically describe the same information in different syntaxes — and any of those files can be generated from it.

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

Six fields. Six decisions made explicit in 7 lines:
- `email` is required (`*`), unique (`@`), and indexed (`~`)
- `name` has a length constraint: 1-100 characters
- `role` is one of exactly three values
- `active` defaults to `true`
- `created` is immutable (`!`) — set once, never changed

---

## The Problem

Building an application means writing the same information over and over:

```
schema.sql          →  CREATE TABLE users (email TEXT NOT NULL UNIQUE ...)
types.ts            →  interface User { email: string; ... }
validators.ts       →  z.object({ email: z.string().email() ... })
api/users/route.ts  →  export async function GET(req) { ... }
components/User.tsx →  <input name="email" required ... />
tests/user.test.ts  →  it('should reject missing email', () => { ... })
```

Six files. One truth. Every repetition is an opportunity for drift, inconsistency, and bugs. Change the email constraint in the schema but forget the validator — now invalid data gets through. Add a field to the type but not the API — now the frontend crashes.

Kappa captures the truth once:

```kappa
email: s*@~
```

Everything else — the schema column, the TypeScript type, the Zod validator, the API endpoint, the form input, the test case — is derivable from those four characters.

---

## How It Works

### 1. Write the spec

A `.kappa` file describes what your application IS — its entities, their fields, their constraints, their relationships, and their behavior.

```kappa
Product {
  id: id*,
  sku: s*@~(8,20),
  name: s*(1,200),
  description: t,
  price: f*(0.01,),
  stock: i(0,)=0,
  status: (draft|active|discontinued),
  images: [s],
  category: Category*,
  created: dt!
}
```

### 2. Parse to AST

The Kappa parser reads `.kappa` files and produces a structured AST (Abstract Syntax Tree). The AST is the portable representation — it captures every decision in a machine-readable format that any code generator can consume.

```
.kappa file → Parser → AST (JSON)
```

The parser is deterministic. Same input → same AST. No AI, no inference, no ambiguity.

### 3. Generate for your target

Code generators read the AST and emit code for a specific technology stack. Each generator is a set of templates that map Kappa concepts to target-specific implementations.

```
AST → Drizzle Generator  → db/schema.ts
AST → Zod Generator      → validators/product.ts
AST → API Generator      → api/products/route.ts
AST → React Generator    → components/ProductForm.tsx
AST → Test Generator     → tests/product.test.ts
```

Each generator is deterministic. Same AST → same output, byte-for-byte. Different target stacks get different generators, but the Kappa spec stays the same.

---

## Dense Notation

The compact syntax for data models. Designed for single-glance readability — every field is 5-7 characters.

### Type Codes

| Code | Type | Example |
|------|------|---------|
| `s` | String (max 255 chars) | `name: s*` |
| `t` | Text (unlimited) | `bio: t` |
| `i` | Integer | `age: i*(18,)` |
| `f` | Float | `price: f*(0.01,)` |
| `b` | Boolean | `active: b` |
| `d` | Date | `birthday: d` |
| `dt` | DateTime | `created: dt` |
| `id` | Identifier (auto PK) | `id: id*` |

### Modifiers

| Modifier | Meaning | Example |
|----------|---------|---------|
| `*` | Required | `email: s*` |
| `?` | Optional (nullable) | `phone: s?` |
| `!` | Immutable | `created: dt!` |
| `~` | Indexed | `username: s*~` |
| `@` | Unique | `email: s*@` |
| `=value` | Default | `active: b=true` |
| `(min,max)` | Constraint | `age: i*(18,120)` |

Modifiers stack: `email: s*@~` means required, unique, indexed.

### References and Enums

```kappa
author: User*                          // Required foreign key
team: Team?                            // Optional foreign key
status: (draft|published|archived)     // Enum
tags: [s]                              // Array of strings
```

---

## Full Syntax

For logic that dense notation can't express — computed fields, authorization, workflows.

```kappa
entity Order {
  items: [OrderItem]
  status: (pending|paid|shipped|cancelled) = "pending"

  // Computed field — derived from data, not stored
  total: Float = fn() =>
    this.items |> sum(item => item.price * item.quantity)

  // Authorization — who can do what
  capability owner {
    scope: fn(user: User) => this.customer == user
    actions: ["read", "update", "cancel"]
  }

  // Workflow — what happens when state changes
  workflow onUpdate {
    when this.status == "paid" then {
      notify(this.customer, "Payment confirmed")
      inventory.reserve(this.items)
    }
  }
}
```

Full syntax includes:
- **Lambda expressions** — `fn(x) => x * 2`
- **Pattern matching** — `match status with { "draft" => ..., "published" => ... }`
- **Pipeline operator** — `items |> filter(x => x.active) |> sum(x => x.price)`
- **Conditionals** — `if x > 0 then "positive" else "non-positive"`
- **Effect types** — `Query<User>`, `Mutate<Order>` (tracks read vs write intent)

Dense and full notation can be mixed in the same file.

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

From this spec, generators produce: database schema with relations, TypeScript types, validation schemas, CRUD API endpoints with authorization middleware, React forms and tables, and test suites. ~40 lines of Kappa → thousands of lines of production code.

---

## Specification

- [Language Specification](spec/language.md) — types, syntax, expressions, workflows, capabilities, type system, standard library
- [Dense Notation Reference](spec/dense-notation.md) — quick reference for the compact syntax

### Formal Grammar (EBNF)

- [Dense notation grammar](spec/grammar-dense.ebnf) — ISO/IEC 14977 EBNF for the compact syntax
- [Full syntax grammar](spec/grammar-full.ebnf) — ISO/IEC 14977 EBNF for the expression-based syntax

Both notations produce the same AST.

### Examples

Dense notation:
- [Blog with users and comments](examples/dense/user-blog.kappa)
- [E-commerce catalog with orders](examples/dense/ecommerce.kappa)
- [Multi-tenant SaaS project manager](examples/dense/saas-multitenant.kappa)

Full syntax (with computed fields, authorization, and workflows):
- [Order with business logic](examples/full/order-with-logic.kappa)

---

## Status

Kappa is a working specification. The language design is stable — the notation, type system, full syntax, and formal grammars are defined and documented. The parser and code generators are under development.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on reporting issues, proposing changes, adding examples, and building generators.

## License

MIT
