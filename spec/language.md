# Kappa Language Specification

---

## Overview

Kappa is a **computational domain-specific language** for universal code generation. It allows developers to specify application logic, data models, workflows, and user interfaces in a minimal, type-safe syntax, then generate complete production-ready codebases across multiple target platforms.

### Key Principle

Kappa is not a configuration language. It's a **computational language** with functions, expressions, pattern matching, and type inference. This enables dynamic, context-aware code generation that traditional template-based systems cannot achieve.

### Why Kappa Exists

Modern web development suffers from **massive token inefficiency**. Building a simple CRUD application requires:

- Database schema definitions (Prisma, Drizzle)
- Type definitions (TypeScript interfaces)
- Validation schemas (Zod, Yup)
- API endpoints (Express, tRPC)
- UI forms and tables (React components)
- Tests (unit, integration, e2e)

Each of these is essentially the **same information**, repeated in different syntaxes. This creates:

1. **Token waste** - LLMs spend 70-80% of context on boilerplate
2. **Drift** - Schema changes require updating 6+ files
3. **Cognitive overhead** - Developers must maintain consistency manually
4. **Error surface** - Each repetition is an opportunity for bugs

Kappa captures the **single source of truth** and generates all derived artifacts deterministically.

---

## Dual Syntax: Dense vs Full

Kappa provides **two equivalent syntaxes** that compile to the same AST:

1. **Dense Notation** - Ultra-compact for simple models
2. **Full Syntax** - Expression-based for complex logic

### When to Use Each

| Use Case | Recommended Syntax |
|----------|-------------------|
| Data models | Dense |
| Simple CRUD | Dense |
| Quick prototyping | Dense |
| Computed fields | Full |
| Workflows | Full |
| Authorization | Full |
| Complex validation | Full |

### Mixing Both

You can combine both notations in the same file:

```kappa
User {
  // Dense notation for simple fields
  email: s*@
  age: i*(18,)

  // Full syntax for computed field
  is_adult: Boolean = fn() => this.age >= 18
}
```

---

## Dense Notation

Dense notation is Kappa's ultra-compact syntax for data models.

### Type Codes

| Code | Type | Example |
|------|------|---------|
| `s` | String (bounded) | `name: s*` |
| `t` | Text (unbounded) | `bio: t` |
| `i` | Integer | `age: i*(18,)` |
| `f` | Float | `price: f(0.01,)` |
| `b` | Boolean | `active: b` |
| `d` | Date | `birthday: d` |
| `dt` | DateTime | `created: dt` |
| `id` | Identifier (auto PK) | `id: id*` |
| `x` | Binary/Blob | `avatar: x` |

### Field Modifiers

| Modifier | Meaning | Example |
|----------|---------|---------|
| `*` | Required | `email: s*` |
| `?` | Optional (nullable) | `phone: s?` |
| `!` | Immutable (write-once) | `created: dt!` |
| `~` | Indexed | `username: s*~` |
| `@` | Unique | `email: s*@` |
| `++` | Auto-increment | `counter: i++` |
| `=value` | Default value | `active: b=true` |

### Constraints

```kappa
age: i*(18,)      // Min 18, no max
password: s*(8,)  // Min 8 chars
rating: f(1,5)    // Between 1 and 5
```

### Modifiers Stack

```kappa
email: s*@~       // Required, unique, indexed
slug: s*@!(3,)    // Required, unique, immutable, min 3 chars
```

### References

```kappa
author: User*     // Foreign key to User (required)
team: Team?       // Foreign key to Team (optional)
```

### Enums

```kappa
status: (draft|published|archived)
role: (admin|editor|viewer)
```

### Arrays

```kappa
tags: [s]         // Array of strings
scores: [i]       // Array of integers
```

### Example: E-commerce Product

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
  created: dt!,
  updated: dt
}
```

---

## Full Syntax

Full syntax is Kappa's expression-based computational language for complex logic.

### Lambda Expressions

```kappa
// Basic lambda
fn(x: Integer) => x * 2

// Multiple parameters
fn(a: Integer, b: Integer) => a + b

// Type inference
fn(user) => user.age >= 18

// Closures
entity User {
  age: Integer
  is_adult: Boolean = fn() => this.age >= 18
}
```

### If/Then/Else Expressions

Conditionals are **expressions**, not statements:

```kappa
// Simple
if x > 0 then "positive" else "non-positive"

// Nested
if score >= 90 then "A"
else if score >= 80 then "B"
else if score >= 70 then "C"
else "F"

// In computed fields
entity Order {
  total: Float
  status: String = if this.paid then "complete" else "pending"
}
```

### Pattern Matching

```kappa
// Basic pattern matching
match status with {
  "draft" => "Editing",
  "published" => "Live",
  "archived" => "Hidden"
}

// With guards
match user.role with {
  "admin" => "Full access",
  "editor" when user.verified => "Can edit",
  "viewer" => "Read-only",
  _ => "No access"
}

// Destructuring
match point with {
  { x: 0, y: 0 } => "Origin",
  { x: 0, y } => "Y-axis",
  { x, y: 0 } => "X-axis",
  { x, y } => "Point"
}

// Array patterns
match tags with {
  [] => "No tags",
  [single] => "One tag",
  [first, ...rest] => "Multiple tags"
}
```

### Computed Fields

```kappa
entity User {
  first_name: String
  last_name: String

  // Simple computation
  full_name: String = fn() => this.first_name + " " + this.last_name

  // With conditionals
  display_name: String = fn() =>
    if this.nickname != null
    then this.nickname
    else this.full_name
}

entity Order {
  items: [OrderItem]

  // Aggregations
  subtotal: Float = fn() => this.items |> sum(item => item.price * item.quantity)
  tax: Float = fn() => this.subtotal * 0.1
  total: Float = fn() => this.subtotal + this.tax
}
```

### Workflows

Workflows define **state transitions** and **side effects**:

```kappa
entity Order {
  status: String = "pending"

  workflow onCreate {
    notify(this.customer, "Order created")
    analytics.track("order_created", this.id)
  }

  workflow onUpdate {
    when this.status == "paid" then {
      notify(this.customer, "Payment confirmed")
      inventory.reserve(this.items)
    }

    when this.status == "shipped" then {
      notify(this.customer, "Order shipped")
    }
  }

  workflow scheduled("0 0 * * *") {  // Daily at midnight
    if this.status == "pending" && age(this.created) > 7.days then {
      this.cancel()
      notify(this.customer, "Order expired")
    }
  }
}
```

### Capabilities (Authorization)

```kappa
entity Post {
  author: User
  org: Organization

  // Owner-based authorization
  capability owner {
    scope: fn(user: User) => this.author == user
    actions: ["read", "update", "delete"]
  }

  // Role-based authorization
  capability admin {
    scope: fn(user: User) => user.role == "admin"
    actions: ["read", "update", "delete", "publish"]
  }

  // Team-based authorization
  capability team_member {
    scope: fn(user: User) => user.org == this.org
    actions: ["read"]
  }
}
```

### Pipeline Operator

```kappa
// Forward pipe (function composition)
[1, 2, 3, 4, 5]
  |> filter(x => x > 2)
  |> map(x => x * 2)
  |> sum()
// Result: 24
```

### Operator Precedence

From highest to lowest:
1. Function call, array access, member access
2. Exponentiation `^`
3. Unary `!`, `-`
4. Multiplication `*`, division `/`, modulo `%`
5. Addition `+`, subtraction `-`
6. Comparison `<`, `>`, `<=`, `>=`
7. Equality `==`, `!=`
8. Logical AND `&&`
9. Logical OR `||`
10. Pipeline `|>`
11. Lambda `=>`
12. Conditional `if/then/else`
13. Pattern matching `match/with`

---

## Type System

Kappa employs a **static, gradually-typed system** with **Hindley-Milner type inference**.

### Primitive Types

| Type | Dense Code | Description |
|------|------------|-------------|
| `String` | `s` | Unicode text (max 255 chars) |
| `Text` | `t` | Long text (unlimited) |
| `Integer` | `i` | 64-bit signed integer |
| `Float` | `f` | 64-bit IEEE 754 float |
| `Boolean` | `b` | True or false |
| `Date` | `d` | Calendar date |
| `DateTime` | `dt` | ISO 8601 timestamp |
| `Id` | `id` | UUID v4 or ULID |
| `Binary` | `x` | Binary data |

### Composite Types

```kappa
// Arrays
tags: [String]

// Tuples
coordinates: (Float, Float)

// Records
address: { street: String, city: String, zip: String }

// Union Types
status: "pending" | "approved" | "rejected"

// Function Types
transform: (String) => Integer
```

### Generics

```kappa
// Generic identity
fn identity<T>(x: T): T => x

// Generic array operations
fn map<T, U>(arr: Array<T>, f: (T) => U): Array<U>

// Type constraints
fn add<T extends Integer | Float>(a: T, b: T): T => a + b
```

### Effect Types

Kappa tracks computational effects:

```kappa
// Pure function (no effects)
fn add(a: Integer, b: Integer): Integer => a + b

// Impure function (I/O effect)
fn readFile(path: String): IO<String>

// Query effect (database read)
fn getUser(id: Id): Query<Option<User>>

// Mutate effect (database write)
fn createUser(data: UserInput): Mutate<User>
```

---

## Compilation Model

### Pipeline Overview

```
Kappa Source (dense or full)
        |
        v
+------------------+
|  Phase 1: Parse  |  -> AST (<5ms)
+--------+---------+
         |
         v
+------------------+
| Phase 2: Analyze |  -> Annotated AST (<10ms)
+--------+---------+
         |
         v
+------------------+
| Phase 3: Type    |  -> Typed AST (<20ms)
+--------+---------+
         |
         v
+------------------+
| Phase 4: IR Gen  |  -> Intermediate Representation (<5ms)
+--------+---------+
         |
         v
+------------------+
| Phase 5: CodeGen |  -> Target Code (<100ms)
+------------------+
```

### Deterministic Output

All code generation is deterministic:
- Same input IR -> same output code (byte-for-byte)
- Files are checksummed (SHA-256) to detect changes
- Templates are cached and versioned

### Streaming Parse

Kappa's dense notation is designed for incremental, left-to-right, single-pass parsing — including from a live token stream.

The grammar requires no lookahead and no backtracking. Fields are delimited by `,`. The parser can emit a complete field AST node the moment it encounters a comma or closing `}`. This means:

- **Token-by-token parsing.** As an LLM streams output, the parser processes each token as it arrives. No buffering of the complete entity is needed.
- **Incremental code generation.** A generator can emit the schema column for `email` while the model is still generating the next field. The database migration begins before the spec is fully written.
- **Partial validity.** `User { id: id*, email: s*@~` is a valid partial parse — two complete fields — even though the entity isn't closed. Generators can produce code for the fields they've seen so far.
- **Error locality.** A malformed field doesn't invalidate preceding fields. The parser reports the error at the exact token and continues parsing subsequent fields.

```
LLM token stream:  U s e r { i d : i d * , e m a i l : s * @ ~ ,
                                          ↑                      ↑
                                    emit field 1           emit field 2
                                    (id: id*)              (email: s*@~)
```

This property emerges from the grammar's design, not from parser implementation. The EBNF rules use only right-recursive and iterative constructs — no left recursion, no ambiguous alternations requiring backtracking, no context-sensitive rules.

---

## Standard Library

Kappa provides **62 fundamental functions** organised into six categories:

### 1. Arithmetic & Comparison (12 functions)
`+`, `-`, `*`, `/`, `%`, `^`, `==`, `!=`, `<`, `>`, `<=`, `>=`

### 2. Logic & Control (8 functions)
`&`, `|`, `!`, `if`, `match`, `for`, `while`, `return`

### 3. Array (12 functions)
`map`, `filter`, `reduce`, `zip`, `concat`, `slice`, `length`, `first`, `last`, `take`, `drop`, `sort`

### 4. Record & Function (10 functions)
`get`, `set`, `merge`, `keys`, `values`, `entries`, `fn`, `apply`, `pipe`, `compose`

### 5. I/O (4 functions)
`query`, `mutate`, `subscribe`, `emit`

### 6. Meta (8 functions)
`type`, `assert`, `cast`, `check`, `infer`, `generate`, `verify`, `optimize`

---

## Complete Example: Multi-Tenant SaaS

```kappa
entity Organization {
  name: String
  slug: String

  workflow onCreate {
    analytics.track("org_created", this.id)
  }
}

entity Project {
  org: Organization
  name: String
  status: "planning" | "active" | "archived" = "planning"

  capability member {
    scope: fn(user: User) => user.org == this.org
    actions: ["read", "update"]
  }

  capability admin {
    scope: fn(user: User) => user.role == "admin" && user.org == this.org
    actions: ["read", "update", "delete", "archive"]
  }
}

entity Task {
  project: Project
  title: String
  assignee: User?
  priority: "low" | "medium" | "high" | "urgent" = "medium"
  completed: Boolean = false

  urgency_score: Integer = fn() => match this.priority with {
    "urgent" => 4,
    "high" => 3,
    "medium" => 2,
    "low" => 1
  }

  capability member {
    scope: fn(user: User) => user.isMemberOf(this.project.org)
    actions: ["read"]
  }

  workflow onUpdate {
    when this.completed && !this.was(completed) then {
      notify(this.assignee, "Task completed")
      analytics.track("task_completed", { project: this.project.id })
    }
  }
}
```

**From this single spec, Kappa generates:**
- `db/schema.ts` - Drizzle schema with relations
- `types/*.ts` - TypeScript interfaces
- `validators/*.ts` - Zod schemas
- `api/*/route.ts` - CRUD endpoints with auth
- `components/*.tsx` - React forms and tables
- `tests/*.test.ts` - Vitest tests

---

## Key Features Summary

1. **Type Inference** - No explicit types required for simple cases
2. **Pattern Matching** - Elegant conditional logic with exhaustiveness checking
3. **First-Class Functions** - Lambda expressions, closures
4. **Multi-Tenancy Primitives** - Scope isolation built into the language
5. **Graph-Based Authorization** - Membership paths computed automatically
6. **Workflow Orchestration** - Declarative state machines
7. **Streaming Parse** - Token-by-token incremental parsing from LLM output streams
8. **Incremental Generation** - Only regenerate changed components
9. **Deterministic Output** - Same input -> same checksum
10. **Zero Runtime** - Compiles to native target code
11. **Target-Agnostic** - Write once, generate TypeScript, Python, Go, etc.
