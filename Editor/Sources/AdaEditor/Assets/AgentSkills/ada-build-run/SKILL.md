---
name: ada-build-run
description: Build, test, run, stop, and diagnose Ada projects on their supported destination.
allowed-tools: terminal, runtime.pause, runtime.resume, runtime.step_frame, trace.status, profiler.live_snapshot
---

# Ada Build and Run

- Save dirty documents before starting a build or run.
- AdaScript-only projects build in process and may run on macOS or iPadOS. SwiftPM build, test, and run is a macOS workflow in AdaEditor.
- Prefer the narrowest build or test that exercises the changed path, then broaden when the change crosses modules.
- Read structured diagnostics and complete output before editing again. Separate code failures from toolchain, network, storage, or platform failures.
- Stop an existing run before replacing its runtime state. Report the exit or stop reason.
