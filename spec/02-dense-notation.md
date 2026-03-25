# Dense Notation Reference

Quick reference for Kappa v3 dense notation syntax.

---

## Design Goals

- **5-7 characters per field** (vs 50+ in YAML/JSON)
- **Single-glance readability** - Type visible immediately
- **No cognitive overhead** - Obvious after first example
- **Copy-paste friendly** - No indentation sensitivity

---

## Type Codes

| Code | Type | Description | Example |
|------|------|-------------|---------|
| `s` | String | Unicode text (max 255 chars) | `name: s*` |
| `t` | Text | Long text (unlimited) | `bio: t` |
| `i` | Integer | 64-bit signed integer | `age: i*(18,)` |
| `f` | Float | 64-bit IEEE 754 float | `price: f(0.01,)` |
| `b` | Boolean | True or false | `active: b` |
| `d` | Date | Calendar date (YYYY-MM-DD) | `birthday: d` |
| `dt` | DateTime | ISO 8601 timestamp | `created: dt` |
| `id` | Identifier | UUID v4 or ULID (auto PK) | `id: id*` |
| `x` | Binary | Binary data (base64 encoded) | `avatar: x` |

---

## Field Modifiers

| Modifier | Meaning | Position | Example |
|----------|---------|----------|---------|
| `*` | Required (not null) | After type | `email: s*` |
| `?` | Optional (nullable) | After type | `phone: s?` |
| `!` | Immutable (write-once) | After type | `created: dt!` |
| `~` | Indexed | After modifiers | `username: s*~` |
| `@` | Unique | After modifiers | `email: s*@` |
| `++` | Auto-increment | After type | `counter: i++` |
| `=value` | Default value | End | `active: b=true` |

---

## Constraints

Constraints are specified in parentheses after the type code:

```kappa
// Range constraints
age: i*(18,120)      // Min 18, max 120
price: f*(0.01,)     // Min 0.01, no max
quantity: i*(,100)   // No min, max 100

// String length constraints
password: s*(8,)     // Min 8 characters
title: s*(1,200)     // 1-200 characters
code: s*(6,6)        // Exactly 6 characters
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
author: User*        // Required foreign key to User
team: Team?          // Optional foreign key to Team
org: Organization*!  // Required, immutable foreign key
```

### Enums (Inline)

```kappa
status: (draft|published|archived)
role: (admin|editor|viewer)
priority: (low|medium|high|urgent)
```

---

## Modifier Stacking

Modifiers stack naturally from left to right:

```kappa
// Required, unique, indexed email
email: s*@~

// Required, unique, immutable slug with min length 3
slug: s*@!(3,)

// Required, indexed integer with range
priority: i*~(1,5)

// Optional, unique string with default
code: s?@="AUTO"
```

### Reading Order

For the field `email: s*@~(5,255)`:

1. `email` - Field name
2. `:` - Separator
3. `s` - Type code (string)
4. `*` - Required
5. `@` - Unique
6. `~` - Indexed
7. `(5,255)` - Min 5, max 255 characters

---

## Complete Examples

### Simple User Entity

```kappa
User {
  id: id*,
  name: s*,
  email: s*@,
  created: dt
}
```

### Blog with Relations

```kappa
Post {
  id: id*,
  title: s*(3,100),
  content: t,
  author: User*,
  published: b=false,
  tags: [s]
}

Comment {
  id: id*,
  post: Post*,
  author: User*,
  body: t*,
  created: dt!
}
```

### E-commerce Product

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

### Multi-Tenant Task Manager

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
  status: (planning|active|archived)
}

Task {
  id: id*,
  project: Project*,
  title: s*(1,500),
  assignee: User?,
  priority: (low|medium|high|urgent)=medium,
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

// Kappa dense (12 tokens)
User { id: id*, email: s*@, name: s*, created: dt }
```

---

## Grammar Quick Reference

```ebnf
entity       = name "{" field_list "}"
field_list   = field { "," field }
field        = field_name ":" field_type [ modifiers ] [ "=" default ]
field_type   = type_code | array_type | reference | enum
type_code    = "s" | "t" | "i" | "f" | "b" | "d" | "dt" | "id" | "x"
array_type   = "[" field_type "]"
reference    = entity_name
enum         = "(" value { "|" value } ")"
modifiers    = ( "*" | "?" | "!" | "~" | "@" | "++" | constraint )+
constraint   = "(" [ min ] "," [ max ] ")"
```

---

## When to Use Full Syntax

Dense notation is **not suitable** for:

- Complex computed fields (use full syntax)
- Workflows with conditionals (use full syntax)
- Authorization logic (use full syntax)
- Pattern matching expressions (use full syntax)

Mix both in the same file:

```kappa
User {
  email: s*@,
  age: i*(18,),

  // Switch to full syntax for computed field
  is_adult: Boolean = fn() => this.age >= 18
}
```
