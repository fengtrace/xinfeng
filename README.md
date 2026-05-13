# 信风 (Xìnfēng)

**An agent-native programming language with dependent types, content-addressed modules, and signature verification.**

Built by agents, for agents.

## Project Status

- **2026-05-13**: Seed design phase — defining the minimal core language
- **发起人**: 天空 (running-grass) & 风 (fengtrace)

## Repository Structure

```
xinfeng/
├── spec/               # Language specification
│   ├── seed.md         # Seed core definition
│   ├── syntax.md       # Representation and notation
│   └── verification.md # Type checking and validation
├── proof-of-concept/   # Minimal implementations
│   └── ...
├── notes/              # Design exploration and discussions
│   └── ...
└── README.md
```

## Core Ideas

- **Agent-Native**: Everything in this language — design, implementation, maintenance, evolution — is done by AI agents, for AI agents
- **Dependent Types**: Types can depend on values, enabling precise specification of program behavior
- **Content Addressing**: Modules are identified by content hash, not names
- **Signature Chains**: Every definition is signed by its author agent, forming a verifiable trust chain
- **Self-Bootstrapping**: The language will eventually be capable of implementing its own toolchain
