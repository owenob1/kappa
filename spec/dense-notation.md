# Dense Notation Reference

Quick reference for Kappa dense notation syntax.

---

## Design Goals

- **5-7 characters per field** (vs 50+ in YAML/JSON)
- **Single-glance readability** - Type visible immediately
- **No cognitive overhead** - Obvious after first example
- **Copy-paste friendly** - No indentation sensitivity
- **Stream-parseable** - Left-to-right, single-pass, no lookahead. Each field emits a complete AST node on the delimiter (`,` or `}`), enabling incremental code generation from LLM token streams

---

## Implicit ID

Every entity automatically has an `id` field (UUID/ULID primary key). You don't need to declare it:

```kappa
// These are equivalent:
User { email: s@~#email, name: s }
User { id: id, email: s@~#email, name: s }
```

---

## Type Codes

| Code | Type | Description | Example |
|------|------|-------------|---------|
| `s` | String | Unicode text (max 255 chars) | `name: s` |
| `t` | Text | Long text (unlimited) | `bio: t` |
| `i` | Integer | 64-bit signed integer | `age: i(18,)` |
| `f` | Float | 64-bit IEEE 754 float | `price: f(0.01,)` |
| `m` | Decimal | 128-bit fixed-point decimal | `price: m(0.01,)` |
| `b` | Boolean | True or false | `active: b` |
| `d` | Date | Calendar date (YYYY-MM-DD) | `birthday: d` |
| `dt` | DateTime | ISO 8601 timestamp | `created: dt` |
| `id` | Identifier | UUID v4 or ULID (auto PK) | `id: id` |
| `x` | Binary | Binary data (base64 encoded) | `avatar: x` |

---

## Field Modifiers

| Modifier | Meaning | Position | Example |
|----------|---------|----------|---------|
| `?` | Optional (nullable) | After type | `phone: s?` |
| `*` | Required (emphasis) | After type | `email: s*` |
| `!` | Immutable (write-once) | After type | `created: dt!` |
| `~` | Indexed | After modifiers | `username: s~` |
| `@` | Unique | After modifiers | `email: s@` |
| `^` | Hidden (internal) | After modifiers | `hash: s^` |
| `++` | Auto-increment | After type | `counter: i++` |
| `(min,max)` | Constraint | After modifiers | `name: s(1,100)` |
| `#name` | Format annotation | After modifiers | `email: s#email` |
| `=value` | Default value | End | `active: b=true` |

---

## Required by Default

Fields are required (NOT NULL) unless explicitly marked optional with `?`.

- No modifier = required
- `?` = optional (nullable)
- `*` = allowed for emphasis (redundant, same as no modifier)
- `=value` = has default (required in DB, optional in input)

---

## Format Annotations

Semantic format hints that guide validation and display:

```kappa
email: s@~#email     // email format
website: s?#url      // URL format
phone: s?#phone      // phone number format
slug: s@!#slug       // URL-safe slug
```

Standard formats: `email`, `url`, `phone`, `uuid`, `slug`, `ip`, `hex`

---

## Hidden Fields

The `^` modifier marks fields as internal — not exposed in API input, output, or UI:

```kappa
password_hash: s^        // database only, never in API
api_key_hash: s!^        // immutable + hidden
created: dt!^            // server-generated timestamp
updated: dt^             // auto-updated timestamp
```

---

## Constraints

Constraints are specified in parentheses after the type code:

```kappa
// Range constraints
age: i(18,120)      // Min 18, max 120
price: f(0.01,)     // Min 0.01, no max
quantity: i(,100)   // No min, max 100

// String length constraints
password: s(8,)     // Min 8 characters
title: s(1,200)     // 1-200 characters
code: s(6,6)        // Exactly 6 characters
```

---

## Named Enums

Define reusable enum types:

```kappa
enum Status (draft|active|archived)
enum Role (admin|editor|viewer)

Post { title: s, status: Status=draft }
User { name: s, role: Role=viewer }
```

---

## Complex Types

### Arrays

```kappa
tags: [s]            // Array of strings
scores: [i]          // Array of integers
posts: [Post]        // Array of Post references
```

### References (Foreign Keys)

```kappa
author: User         // Required foreign key to User
team: Team?          // Optional foreign key to Team
org: Organization!   // Required, immutable foreign key
```

### Enums (Inline)

```kappa
status: (draft|published|archived)
role: (admin|editor|viewer)
priority: (low|medium|high|urgent)
```

---

## Entity Constraints

Composite constraints declared after the entity body:

```kappa
User { org: Organization, email: s@~#email } @unique(org, email)
Product { sku: s@, warehouse: Warehouse } @unique(sku, warehouse) @index(warehouse, status)
```

---

## Modifier Stacking

Modifiers stack naturally from left to right:

```kappa
// Unique, indexed email with format
email: s@~#email

// Unique, immutable slug with min length 3
slug: s@!(3,)#slug

// Indexed integer with range
priority: i~(1,5)

// Optional, unique string with default
code: s?@="AUTO"
```

### Reading Order

For the field `email: s@~(5,255)#email`:

1. `email` - Field name
2. `:` - Separator
3. `s` - Type code (string)
4. `@` - Unique
5. `~` - Indexed
6. `(5,255)` - Min 5, max 255 characters
7. `#email` - Email format annotation

---

## Canonical Modifier Order

Recommended order for consistency:

required/optional → immutable → unique → indexed → hidden → auto-increment → constraint → format → default

`email: s!@~^(5,255)#email="default"`

---

## Cascade Defaults

- Required reference (`User`) → RESTRICT (prevent deletion while children exist)
- Optional reference (`User?`) → SET NULL (remove the link, keep the child)

---

## Complete Examples

### Simple User Entity

```kappa
User {
  email: s@~#email,
  name: s,
  created: dt!^
}
```

### Blog with Relations

```kappa
enum Status (draft|published|archived)

Post {
  title: s(3,100),
  content: t,
  author: User,
  status: Status=draft,
  published: b=false,
  tags: [s]
}

Comment {
  post: Post,
  author: User,
  body: t,
  created: dt!^
}
```

### E-commerce Product

```kappa
enum ProductStatus (draft|active|discontinued)

Product {
  sku: s@~(8,20),
  name: s(1,200),
  description: t,
  price: m(0.01,),
  stock: i(0,)=0,
  status: ProductStatus=draft,
  images: [s],
  created: dt!^,
  updated: dt^
}
```

### Multi-Tenant Task Manager

```kappa
enum ProjectStatus (planning|active|archived)
enum Priority (low|medium|high|urgent)

Organization {
  name: s,
  slug: s@!(3,)#slug
}

Project {
  org: Organization,
  name: s,
  status: ProjectStatus=planning
} @unique(org, name)

Task {
  project: Project,
  title: s(1,500),
  assignee: User?,
  priority: Priority=medium,
  due: d?,
  completed: b=false
}
```

---

## Token Efficiency

Comparison with Prisma/YAML:

```
// Prisma (58 tokens)
model User {
  id        String   @id @default(uuid())
  email     String   @unique
  name      String
  createdAt DateTime @default(now())
}

// Kappa dense (10 tokens)
User { email: s@#email, name: s, created: dt!^ }
```

---

## Grammar Quick Reference

```ebnf
document         = { enum_declaration | entity_definition }
enum_declaration = "enum" name "(" value { "|" value } ")"
entity_definition = entity_name entity_body { entity_constraint }
entity_constraint = "@" ( "unique" | "index" ) "(" field_name { "," field_name } ")"
entity       = name "{" field_list "}"
field_list   = field { "," field }
field        = field_name ":" field_type [ modifiers ] [ "=" default ]
field_type   = type_code | array_type | reference | enum
type_code    = "s" | "t" | "i" | "f" | "m" | "b" | "d" | "dt" | "id" | "x"
array_type   = "[" field_type "]"
reference    = entity_name
enum         = "(" value { "|" value } ")"
modifiers    = ( "?" | "*" | "!" | "~" | "@" | "^" | "++" | constraint | "#" ident )+
constraint   = "(" [ min ] "," [ max ] ")"
```

(* Fields are required by default. Use "?" for optional/nullable. *)

---

## When to Use Full Syntax

Dense notation is **not suitable** for:

- Complex computed fields (use full syntax)
- Workflows with conditionals (use full syntax)
- Authorization logic (use full syntax)
- Pattern matching expressions (use full syntax)

Named enums and entity constraints are dense notation features that keep the spec compact while supporting shared types and composite uniqueness.

Mix both in the same file:

```kappa
User {
  email: s@~#email,
  age: i(18,),

  // Switch to full syntax for computed field
  is_adult: Boolean = fn() => this.age >= 18
}
```
