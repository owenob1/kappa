# Kappa

A specification language that forces decisions to be explicit before implementation.

## What Kappa Is

Kappa is a notation for describing what an application IS — its data models, relationships, constraints, authorization rules, and workflows — in a syntax too precise to be vague about.

## Dense Notation

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

6 fields. 6 decisions made explicit: email is required, unique, and indexed. Name has length bounds. Role is one of three values. Active defaults to true. Created is immutable.

## Full Syntax

For logic that can't be expressed in dense notation:

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

## Documentation

- [Language Specification](spec/01-language.md)
- [Dense Notation Reference](spec/02-dense-notation.md)

## Usage

Write the spec. Read the spec. Build from the spec.
