# Kappa

A compact notation for describing application data models, constraints, relationships, authorization, and workflows.

---

## Example

```kappa
User {
  id: id*,
  email: s*@~,
  name: s*(1,100),
  role: (admin|editor|viewer),
  active: b=true,
  created: dt!
}

Post {
  id: id*,
  title: s*(3,200),
  content: t*,
  author: User*,
  status: (draft|published|archived),
  tags: [s],
  created: dt!
}
```

## Why

Building an application requires the same information repeated in different forms — database schemas, type definitions, validation rules, API endpoints, UI components, tests. Each repetition is an opportunity for drift, inconsistency, and bugs.

Kappa captures that information once, in a notation designed to make every decision visible:

| Kappa | Meaning |
|-------|---------|
| `s*` | Required string |
| `s?` | Optional string |
| `s*@` | Required, unique |
| `s*@~` | Required, unique, indexed |
| `s*(3,200)` | Required, 3-200 characters |
| `i*(0,)` | Required integer, minimum 0 |
| `dt!` | Immutable timestamp |
| `b=true` | Boolean, defaults to true |
| `User*` | Required reference to User |
| `(a\|b\|c)` | Enum: one of a, b, or c |
| `[s]` | Array of strings |

## Dense Notation

For data models — fields, types, constraints, relationships:

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

## Full Syntax

For logic that dense notation can't express — computed fields, authorization, workflows:

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

Both notations can be mixed in the same file.

## Specification

- [Language Specification](spec/language.md) — types, syntax, expressions, workflows, capabilities, type system
- [Dense Notation Reference](spec/dense-notation.md) — quick reference for the compact syntax

## License

MIT
