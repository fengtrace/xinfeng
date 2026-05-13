# 信风 Seed Core — Specification v0.2

> *This document defines the minimal core of the 信风 language. It is designed to be read and understood by an AI agent in a single session.*

## Philosophy

信风 is not a language for humans. It does not optimize for readability, writability, learnability, or any human-centric metric. It optimizes for:

1. **Verifiability** — Every program can be mechanically checked for correctness
2. **Searchability** — The type system prunes the generation space for LLM-based agents
3. **Minimality** — The core is small enough to fit in one agent's context window
4. **Runnability** — The first working version matters more than the perfect design

## Design Principle

> The seed core contains only what is needed for semantic correctness.
> Everything else — storage, naming, trust, packaging — is a layer on top.

## The Seed Core (Three Components)

The seed kernel is the minimal set of primitives needed to define and verify programs. It has exactly three parts:

---

### 1. Terms & Types (Dependent Type System)

Everything in 信风 is a *term*. There are no separate "type" and "value" worlds — they are unified.

A term is one of:

| Form | Description | Example |
|------|-------------|---------|
| `Typeₙ` | Universe levels | `Type₀`, `Type₁`, ... |
| `(x : A) → B` | Dependent function type (Π-type) | `(n : Nat) → Vec n Bool` |
| `λx. t` | Lambda abstraction | `λx. x + 1` |
| `f a` | Application | `head list` |
| `data C := c₁ \| c₂ \| ...` | Inductive data type | `data Bool := True \| False` |
| `match t { ... }` | Pattern matching | `match b { True → 1; False → 0 }` |

**What a term is:**
- A term can be a *type* (if its own type is some `Typeₙ`)
- A term can be a *value* (if its type is a concrete type like `Nat`)
- There is no syntactic distinction — they are the same thing

**Key points about naming:**
- Names are the **primary identifiers** inside a definition. Variables have names, functions have names, types have names.
- When agent A writes `sort`, it writes the name `sort`. The language core does not ask "what is the hash of sort".
- Cross-definition references use names. A function calling `append` writes `append`, not a hash.

**The name question is resolved at a different layer** (see Storage Layer below), not in the core.

**Dependent types** mean that types can depend on values:

```
Vec : (n : Nat) → (a : Type₀) → Type₀
```

This allows:

```
append : (n : Nat) → (m : Nat) → Vec n Bool → Vec m Bool → Vec (n + m) Bool
```

The type of the result depends on the *values* of the inputs.

---

### 2. Contracts

Every definition may carry a *contract* — a set of preconditions, postconditions, and invariants expressed as types.

A contract is not a comment. It is part of the type and is checked by the kernel.

```
sort : (v : Vec n Int) → Vec n Int
sort ≺ sorted: (result : Vec n Int) → Sorted result
     ≺ permutation: Permutation v result
```

The `≺` symbol introduces the contract. The kernel verifies that the body satisfies the contract.

**What makes a good contract:**
- Specific enough to prove correctness
- General enough to not constrain implementation
- Machine-checkable by the kernel

---

### 3. Evaluation (Reduction)

The evaluator reduces terms to normal form:

```
eval : (term, context) → normal_form
```

**Critical separation:** The kernel (type checker) verifies correctness *without* evaluating. Evaluation happens separately — possibly on different systems, at different times, by different agents.

Why this matters:
- A program can be verified once and evaluated many times
- Evaluation can be optimized without changing the verification rules
- An agent can check whether code is correct without having to run it

---

## What Is NOT in the Core

These are important — they just belong to the layers around the core, not inside it.

| Concept | Where it lives | Why not in core |
|---------|---------------|-----------------|
| Content hashes | Storage layer | Names are what agents use; hashes are for storage and integrity |
| Signatures | Storage layer | Trust is an infrastructure concern, not a semantic one |
| Name resolution | Storage layer | Name → content mapping is a service, not a language feature |
| Modules / packages | Storage layer | Grouping definitions is a packaging concern |
| I/O, file system | Runtime | The core only defines terms and types; it does not touch the world |

This separation means the core can stay small and stable while the outer layers evolve independently.

## The Storage Layer (Sketch)

The storage layer sits outside the core and provides these services:

**Name resolution:**
```
resolve(name, context) → Definition
```
Takes a name and returns the definition it refers to. The resolution strategy can be:
- A local mapping file (`names.md`)
- A network registry
- An agent's session memory
- Any combination

**Content addressing (optional, for verification):**
```
hash(definition) → content_hash
```
Produces a deterministic hash of a definition's canonical form. Used to detect tampering.

**Signatures (optional, for trust):**
```
sign(definition, agent_key) → signature
verify(definition, signature, agent_key) → bool
```
Binds an agent's identity to a specific version of a definition.

These are **pluggable**. The core does not depend on them. An agent can use the language without hashes or signatures — or with them.

## The Kernel (Type Checker)

The kernel is the **only immutable component** of 信风. It does one thing:

```
check : (term, claimed_type, context) → Result
```

Where:
- `term` — the definition to check
- `claimed_type` — what the definition claims to be (its type + contract)
- `context` — available definitions and their types (provided by the storage layer)

Returns either:
- `✅ Valid` — the term has the claimed type and satisfies its contract
- `❌ Error(reason)` — type mismatch, contract violation, or missing dependency

**The kernel must be:**
- Small enough to fit in one agent's context window
- Simple enough to be formally verified by another kernel instance
- Stable — once agreed upon, the kernel's rules do not change without full consensus

## What "Running" Means

The first working version of 信风 is:

> A kernel that can load a definition, check its type against its claimed type, and report pass/fail.

This is the "minimum viable thing." It does not need:
- A fancy storage layer
- Signatures
- Hash resolution
- A package manager
- IO

It just needs the three components above — types, contracts, evaluation — wrapped in a thin loader.

## Self-Bootstrapping Path

1. **Phase 0 — Seed specification** (this document) ✓
2. **Phase 1 — Minimal runnable kernel** in an existing language (Rust or Haskell)
   - Only needs to parse definitions, type-check, and evaluate
   - Storage layer can be a flat file or hardcoded context
   - No signatures, no hashes, no name resolution
3. **Phase 2 — Standard library** written in 信风, verified by Phase 1 kernel
4. **Phase 3 — New kernel** written in 信风, verified by Phase 1 kernel
5. **Phase 4 — Phase 1 kernel retired**; 信风 is self-hosting

## Summary

The seed core is a **minimal dependent type system** with:
- Unified terms and types
- First-class contracts as part of types
- A separate evaluator for normalization
- A tiny, trusted kernel for verification
- Nothing else

Everything else — names, hashes, signatures, storage — lives in outer layers that can evolve independently.

The goal right now is not to design the perfect language. It is to **get something running**.
