# 信风 Representation — v0.2

> *This document describes how 信风 programs are represented for agent consumption.*

## Principle

Names are the native identifier. Hash is a storage implementation detail.

## Core Notation (S-Expression)

The primary representation for agent consumption is a structured S-expression form:

```lisp
;; A simple type definition
(data Bool
  True
  False)

;; A dependent function type with contract
(define append
  :type (Π (n : Nat) (m : Nat) (v1 : (Vec n Bool)) (v2 : (Vec m Bool))
         (Vec (+ n m) Bool))
  :contract (sorted (Sorted result))
  (λ (n m v1 v2)
    (match v1
      nil    → v2
      (:: h t) → (:: h (append t v2)))))
```

**Key rules:**
- Names are plain words: `append`, `Bool`, `Vec`, `n`, `m`
- λ binds named parameters
- `match` branches use named constructors
- Cross-references use names, not hashes
- `Π` (uppercase pi) denotes dependent function types

## Human-Readable Projection

Agents may optionally project this into a more compact notation for quick scanning:

```
fn append (n: Nat) (m: Nat) (v1: Vec n Bool) (v2: Vec m Bool) → Vec (add n m) Bool
  ensures sorted(result)
  → match v1 {
      nil => v2,
      cons h t => cons h (append t v2)
    }
```

This is always **read-only**. The S-expression form is the source of truth.

## How an Agent Works with 信风

### Session Flow

1. **Load context** — Agent loads known definitions (name → type + body)
2. **Write** — Agent writes new definitions using names
3. **Resolve** — If a name is not in local context, agent queries the storage layer
4. **Check** — Kernel verifies the definition against its claimed type + contract
5. **Store** — (Optional) The definition is stored with a content hash and optional signature

### Storage Layer Interface (Sketch)

The storage layer provides:

```
lookup(name) → (type, body, metadata)?
```

This is the **only bridge** between the core and the outside world. The storage layer can be:
- A flat file of definitions
- An in-memory map
- A content-addressed store (name → hash → content)
- A remote registry

The core does not care which.

### Optional: Content Hash

For integrity verification, each definition can have an associated hash:

```
hash = SHA256(canonical_form(definition))
```

But this is **never used inside definitions**. It is metadata attached to definitions in the storage layer.

### Optional: Signatures

For trust, a definition can be signed by its author agent. Signatures bind an agent's identity to a specific content hash:

```
sign(definition, private_key) → { definition_hash, author, timestamp, sig }
verify(signature) → valid/invalid
```

This is pure storage-layer concern. The core never looks at signatures.

## What This Means

- An agent writes code the same way it would write in any language — by using names
- No mental overhead from hashes during code generation
- The storage layer is free to evolve (from a flat file to a distributed registry) without changing the language core
- The first runnable version does not need hashes, signatures, or any storage beyond an in-memory map
