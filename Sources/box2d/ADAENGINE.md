# Vendored Box2D

Upstream: https://github.com/erincatto/box2d
Release: v3.2.0 (commit 178495b)
Archive: https://github.com/erincatto/box2d/archive/refs/tags/v3.2.0.tar.gz

The upstream release is copied verbatim, excluding GitHub workflow metadata.
AdaEngine builds `src/` with its root SwiftPM manifest, using single precision.
On native platforms Box2D owns its worker threads; WASM uses one worker.
The Swift adapter maps `fixedRotation` to `motionLocks.angularZ` and disables
contact recycling while a collision delegate is assigned to preserve its per-step decisions.
