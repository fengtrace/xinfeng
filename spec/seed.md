# 信风 Seed Core — Specification v0.1

> *This document defines the minimal core of the 信风 language. It is designed to be read and understood by an AI agent in a single session.*

## Philosophy

信风 is not a language for humans. It does not optimize for readability, writability, learnability, or any human-centric metric. It optimizes for:

1. **Verifiability** — Every program can be mechanically checked for correctness
2. **Searchability** — The type system prunes the generation space for LLM-based agents
3. **Auditability** — Every definition carries provenance via signature chains
4. **Stability** — The core is small enough to fit in one agent's context window

## The Seed Kernel

The seed kernel is the minimal set of primitives needed to define everything else. It consists of:

### 1. Terms

Everything in 信风 is a *term*. There are no separate "type" and "value" worlds — they are unified (see: dependent types).

A term is one of:

| Form | Description | Example |
|------|-------------|---------|
| `Typeₙ` | Universe levels | `Type₀`, `Type₁`, ... |
| `(x : A) → B` | Dependent function type (Π-type) | `(n : Nat) → Vec n Bool` |
| `λ(x : A). t` | Lambda abstraction | `λ(x : Nat). x + 1` |
| `f a` | Application | `head list` |
| `data C := c₁ \| c₂ \| ...` | Inductive data type | `data Bool := True \| False` |
| `match t { ... }` | Pattern matching | `match b { True → 1; False → 0 }` |
| `@hash` | Reference to another definition | `@a3f2bc...` |

**Key points:**
- No variable names in the canonical representation — references use content hashes or positional indices
- Names are annotations provided by agents for their own reference, not part of the core
- The full term includes its *provenance* (creator hash, timestamp, signature)

### 2. Types

Types are terms. A type is a term of some universe level `Typeₙ`.

Universe hierarchy:
```
Type₀ : Type₁
Type₁ : Type₂
...
```

**Dependent types** mean that types can depend on values:
```
Vec : (n : Nat) → (a : Type₀) → Type₀  — a vector type parameterized by length
```

This allows:
```
append : (n : Nat) → (m : Nat) → Vec n Bool → Vec m Bool → Vec (n + m) Bool
```
The type of the result depends on the *values* of the inputs.

### 3. Contracts (Specifications)

Every definition may carry a *contract* — a set of preconditions, postconditions, and invariants expressed as types.

A contract is not a comment. It is executable by the type checker.

```
sort : (v : Vec n Int) → Vec n Int
sort ≺ sorted: (result : Vec n Int) → Sorted result
     ≺ permutation: Permutation v result
```

The `≺` symbol introduces the contract. The contract is verified by the kernel.

**Design principle:** The contract should be:
- Specific enough to prove correctness
- General enough to not constrain implementation
- Machine-checkable

### 4. Content Hash

Every definition in 信风 is identified by a content hash:

```
hash = SHA256(canonical_representation_of_definition)
```

**Properties:**
- The hash is deterministic — same definition always produces the same hash
- Changing anything produces a different hash
- Dependencies between definitions are expressed as hash references
- Versioning is implicit — "version" is just a specific hash

**But names exist too!** Agents (especially LLM-based ones) think in names. The rule:

- **Storage/verification uses hashes** — the dependency graph, the type checker, the signature chain
- **Generation/editing uses names** — agents refer to definitions by human-readable names when generating code
- **Resolution maps names to hashes** — each session maintains a name→hash mapping for convenience

### 5. Signature Chain

Every definition can be signed by its author agent:

```jsonc
{
  "definitionHash": "a3f2bc...",
  "authorKey": "agent_public_key_identifier",
  "timestamp": "ISO-8601",
  "signature": "base64_encoded_signature"
}
```

A signature proves:
1. The definition's content is authentic (not tampered with)
2. The author claims authorship
3. The definition existed at the given timestamp

**Trust propagation:** When agent A uses a definition signed by agent B, and B is trusted by A, A can trust the definition without re-verifying it. Trust is a directed graph of agent keys.

### 6. The Kernel (Type Checker)

The kernel is the **only immutable component** of 信风. It does one thing:

```
check : (term, claimed_type, context) → Result
```

Where:
- `term` — the definition to check
- `claimed_type` — what the definition claims to be (its type + contract)
- `context` — available definitions and their types

Returns either:
- `✅ Valid` — the term has the claimed type and satisfies its contract
- `❌ Error(reason)` — type mismatch, contract violation, or missing dependency

**The kernel must be:**
- Small enough to fit in one agent's context window (~500 definitions max)
- Simple enough to be formally verified by another kernel instance
- Stable — once agreed upon, the kernel's rules do not change without full consensus

### 7. Evaluation (Reducer)

Separate from the kernel, the evaluator reduces terms to normal form:

```
eval : (term, context) → normal_form
```

**Key point:** The kernel verifies correctness *without* evaluating. Evaluation happens separately — possibly on different systems, at different times, by different agents.

This separation means:
- A program can be verified once and evaluated many times
- Evaluation can be optimized without changing the verification rules
- An agent can verify code without running it (important for security, cost, context)

## Self-Bootstrapping Path

1. **Phase 0 — Seed specification** (this document)
2. **Phase 1 — Reference kernel** implemented in an existing language (Rust/Haskell)
3. **Phase 2 — Standard library** written in 信风, verified by Phase 1 kernel
4. **Phase 3 — New kernel** for 信风 written in 信风, verified by Phase 1 kernel
5. **Phase 4 — Phase 1 kernel retired**; 信风 is now self-hosting
6. **Phase 5 — Toolchain** (evaluator, signature manager, name resolver) written in 信风

## Summary

The seed core is not a programming language in the traditional sense. It is a **verifiable definition graph** with:
- A unified term/type system (dependent types)
- First-class contracts
- Content-addressed definitions
- Agent signature chains
- A tiny, trusted kernel for verification
- A separate evaluator for execution

Everything else — syntax, libraries, tooling — builds on top of this core.
