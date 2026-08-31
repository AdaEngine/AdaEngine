# AdaEngine Architecture Decision Records

This directory records accepted architectural decisions for AdaEngine. An ADR
describes the intended design even when its implementation is still planned.

## Status values

- **Proposed**: under discussion and not yet binding.
- **Accepted**: the design is the source of truth for implementation work.
- **Superseded**: replaced by a newer ADR.
- **Rejected**: considered but deliberately not selected.

## Ada Script decisions

| ADR | Status | Implementation | Decision |
| --- | --- | --- | --- |
| [ADR-0001](0001-ada-script-annotation-modules.md) | Accepted | Partial | Annotation-driven modules, imports, and discovery without `main()` |
| [ADR-0002](0002-ada-script-ecs-query-api.md) | Accepted | Partial | Iterator-based ECS queries, canonical filter syntax, and inferred access |
| [ADR-0003](0003-ada-script-components-and-resources.md) | Accepted | Planned | Ada Script-defined components and resources backed by generated Swift types |
| [ADR-0004](0004-ada-script-world-capabilities.md) | Accepted | Planned | Capability-scoped world access and deferred structural changes |
| [ADR-0005](0005-scriptable-objects-and-coding.md) | Accepted | Planned | Scriptable object lifecycle, registration, and scene coding |
| [ADR-0006](0006-ada-script-adaui-integration.md) | Accepted | Planned | Native AdaUI view graphs, state, bindings, snapshots, and event routing for Ada Script |
