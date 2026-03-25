# Contributing to Kappa

## How to Contribute

### Report issues

If you find a problem with the spec — an ambiguity in the grammar, an inconsistency between dense and full syntax, or a pattern that can't be expressed — open an issue with:

1. What you tried to express
2. What the spec says should happen
3. What you expected instead

### Propose changes

For changes to the language specification:

1. Open an issue describing the change and why it's needed
2. Reference the relevant grammar rules in `spec/grammar-dense.ebnf` or `spec/grammar-full.ebnf`
3. Include a before/after example showing the change in practice

### Add examples

New `.kappa` example files are welcome. Place them in:

- `examples/dense/` — for dense notation examples
- `examples/full/` — for full syntax examples

Each example should:
- Start with a comment explaining what it models
- Be self-contained (don't reference entities defined elsewhere)
- Demonstrate a real-world use case, not an abstract test case

### Build a generator

Kappa generators transform the AST into target-specific code. If you build one:

1. Open an issue to discuss the target (e.g., "Drizzle ORM generator")
2. Document which Kappa features your generator supports
3. Include test cases showing Kappa input → generated output

## Guidelines

- Keep the notation compact. If a new feature can't be expressed in under 10 characters of dense notation, it may not belong in dense notation.
- Dense and full syntax must produce the same AST for equivalent inputs.
- Every grammar change must include valid and invalid examples.
- The grammar files (`*.ebnf`) are the source of truth. The markdown spec files are human-readable descriptions of the grammar.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
