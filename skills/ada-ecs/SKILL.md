---
name: ada-ecs
description: AdaEngine ECS work covering World/Entities/Components, queries, systems, scheduler, resources, events, and ECS macros. Use when changing AdaECS behavior or ECS DSL macros.
---

# Ada ECS

## Overview
Handle ECS changes in AdaECS and ECS macros. Keep concurrency rules, scheduling order, and data layout consistent with existing patterns.

## Key Areas
- `Sources/AdaECS/World`, `Sources/AdaECS/Entity`, `Sources/AdaECS/Component`, `Sources/AdaECS/Query`
- `Sources/AdaECS/System`, `Sources/AdaECS/Scheduler`, `Sources/AdaECS/Commands`, `Sources/AdaECS/Events`
- `Sources/AdaEngineMacros` for `@Component`, `@Bundle`, `@System`, `@PlainSystem`
- `Tests/AdaECSTests` for behavior coverage

## Workflow
1. Decide if the change is core ECS behavior or macro/DSL behavior.
2. For core changes, update the minimal module area and keep archetype and query invariants stable.
3. For macro changes, update `Sources/AdaEngineMacros` and validate the generated APIs align with existing DSL conventions.
4. Add or update tests in `Tests/AdaECSTests` for new behavior.

## Guardrails
- Avoid global mutable state; use actor isolation or atomics as established in `World`.
- Keep `@unchecked Sendable` uses justified and minimal.
- Preserve scheduler ordering and dependencies unless explicitly requested.

## Testing
- Run `swift test --parallel --filter AdaECSTests` for ECS changes.
