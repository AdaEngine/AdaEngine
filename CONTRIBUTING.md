# Contributing to AdaEngine

Thanks for considering a contribution. We welcome fixes, features, docs, and examples.

## Requirements

- Swift 6.2 toolchain
- Xcode 26.3 (macOS) or Visual Studio Code with the Swift extension
- Git

## Getting started

1. Fork the repo and clone your fork.
2. Create a topic branch from `main`.
3. Make your changes with focused commits.

## Build and test

```bash
swift build
```

```bash
swift test --parallel
```

SwiftLint runs as a SwiftPM plugin on supported platforms. If you have SwiftLint installed locally, you can also run:

```bash
swiftlint --config .swiftlint.yml
```

## Code style and conventions

- Follow SwiftLint rules and keep imports minimal.
- Prefer structured concurrency with `async`/`await` and `@Sendable` closures.
- Use `@MainActor` for UI and platform-facing code.
- Avoid global mutable state; prefer actors or atomics when sharing data.

## Documentation

- Update DocC pages for user-facing changes.
- Keep examples short and focused.

## Submitting a pull request

1. Ensure tests pass and new behavior is covered by tests when practical.
2. Write a clear PR description with context and a brief summary of changes.
3. Link relevant issues or discussions.

If a change is large or user-visible, consider opening an issue first to align on scope.

## AI-assisted contributions

Using AI tools is allowed, but the author remains responsible for correctness and quality. When AI is used:

1. Verify code style and conventions match this project.
2. Evaluate any performance impact from AI-generated changes.
3. Review all AI-generated code and text for hallucinations, contradictions, and broken logic.
4. Do not share private data, secrets, or proprietary code unless policy explicitly allows it.
5. Validate licenses and provenance of generated code or suggested dependencies.
6. Confirm APIs exist and usage matches real types and symbols in the codebase.
7. Run relevant tests and linting (at minimum SwiftLint and the affected tests).
8. Add or update tests when behavior changes.
9. Avoid broad refactors suggested by AI unless there is a clear, agreed-upon reason.
10. If AI meaningfully contributed, mention it in the PR description for transparency.
