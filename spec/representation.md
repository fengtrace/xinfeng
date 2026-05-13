# 信风 Representation — v0.1

> *This document describes how 信风 programs are represented, both for agent consumption and for storage/verification.*

## The Problem

Traditional programming languages use text as their primary representation. Text is optimized for human reading and writing — sequential, linear, character-based.

信风's primary consumers are AI agents. Text is one possible representation, but not the only one — and likely not the best one.

## Dual Representation

信风 uses two representations:

### Internal Representation (IR): Structured AST with Provenance

This is the canonical form — what gets hashed, signed, and stored.

```jsonc
{
  "format": "xinfeng-ir-v1",
  "definitions": [
    {
      "hash": "a3f2bc...",
      "kind": "function",
      "name": "append",  // Agent-facing name, not part of the hash
      "type": {
        "kind": "pi",
        "param": {
          "name": "n",
          "type": { "kind": "ref", "hash": "@Nat" }
        },
        "param2": {
          "name": "m",
          "type": { "kind": "ref", "hash": "@Nat" }
        },
        "result": {
          "kind": "pi",
          "param": {
            "name": "v1",
            "type": { "kind": "app", "fn": "@Vec", "args": ["@Nat", "n"] }
          },
          "result": {
            "kind": "pi",
            "param": {
              "name": "v2",
              "type": { "kind": "app", "fn": "@Vec", "args": ["@Nat", "m"] }
            },
            "result": {
              "kind": "app",
              "fn": "@Vec",
              "args": [
                { "kind": "app", "fn": "@add", "args": ["n", "m"] },
                "@Bool"
              ]
            }
          }
        }
      },
      "contract": {
        "sorted": {
          "kind": "app",
          "fn": "@Sorted",
          "args": [{ "kind": "ref", "hash": "@result" }]
        }
      },
      "body": { /* ... lambda term ... */ },
      "provenance": {
        "author": "agent_key_abc...",
        "timestamp": "2026-05-13T10:00:00Z",
        "signature": "base64...",
        "dependencies": [
          { "hash": "@Nat", "resolved": "3b7e..." },
          { "hash": "@Vec", "resolved": "9f1a..." },
          { "hash": "@add", "resolved": "c4d2..." }
        ]
      }
    }
  ]
}
```

**This is the truth.** Everything else is a projection.

### Projected Representation 1: S-Expression (for agent editing)

A lisp-like notation optimized for LLM token efficiency and structural clarity:

```lisp
(define append
  :type (Π (n : Nat) (m : Nat) (v1 : (Vec n Bool)) (v2 : (Vec m Bool))
         (Vec (+ n m) Bool))
  :contract (sorted (Sorted result))
  :provenance {hash "a3f2bc..." author "agent_abc..." signature "base64..."}
  :body
  (λ (n m v1 v2)
    (match v1
      nil    → v2
      (:: h t) → (:: h (append t v2)))))
```

This is what an agent *works with*. It's structured, explicit, and token-efficient. The S-expression format maps directly to the IR.

### Projected Representation 2: Named Form (for agent cross-reference)

When agents discuss code, they use named references:

```
fn append (n: Nat) (m: Nat) (v1: Vec n Bool) (v2: Vec m Bool) → Vec (add n m) Bool
  ensures sorted(result)
  → match v1 {
      nil => v2,
      cons h t => cons h (append t v2)
    }
```

This is the most "human-like" representation, but it's generated from the IR, not stored as the source of truth. It's for quick reading and discussion.

## How Agents Work with 信风

### Session Flow

1. **Name resolution start**: Agent loads a name→hash mapping for familiar definitions
2. **Generation**: Agent writes code in S-expression form using named references
3. **Resolution**: Names are resolved to hashes (using the name→hash mapping)
4. **Verification**: The resolved IR is sent to the kernel for type-checking
5. **Signing**: If verification passes, the agent signs the definition
6. **Storage**: The signed IR is stored in a content-addressed store

### When a Name Collides

Names are *annotations*, not identifiers. If two agents assign different names to the same hash, that's fine — the hash is the true identity. If the same name points to different hashes in different contexts, the name resolver disambiguates by context.

### Representation Choice

For this project's initial implementation, we use:

1. **S-Expression** as the primary working representation (minimal, structured, LLM-friendly)
2. **JSON IR** as the storage format (canonical, hashable, signable)
3. **Named notation** as a secondary view for quick reference

The kernel always operates on JSON IR. Everything else is a projection.
