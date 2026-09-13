# Game Performance panel

Open the bottom panel with the **Output** tool, then select **Performance**. Run a scene or an AdaScript project inside AdaEditor. The game title opens a session selector. **Record 5 s** captures the selected game; completed captures can be selected and exported as Chrome Trace JSON.

The panel shows:

- game updates per second, calculated from intervals between update starts;
- elapsed CPU update time and p95, including the game's nested render-world work;
- process memory in MiB (shared by AdaEditor and embedded games);
- entities in the game's root world;
- ECS-system and CPU render-node durations, sorted by total time.

These measurements do not report GPU execution time or display FPS. Concurrent system durations may overlap and must not be added to estimate frame latency. `No data` indicates an unavailable measurement. A sampled p95 is marked `≈` if a live bucket exceeds its 4,096-duration percentile sample limit; counts, mean, total and maximum remain exact.

Live history is bounded to 240 samples and 60 seconds, refreshed at 4 Hz. Closing the panel releases its recording lease. MCP readers and detailed captures retain their own leases. Stopping a game completes its active capture and retains the final history. A new run gets a new target ID. Completed captures are retained for the last eight recordings during the editor process lifetime.

## MCP

`profiler.list_targets` returns game sessions. Pass a returned ID as `targetId` to `profiler.live_snapshot` or `profiler.start_capture`. Repeated targeted live requests keep a three-second recording lease alive. A targeted snapshot contains the same typed session and samples used by the panel.

```json
{"name":"profiler.live_snapshot","arguments":{"targetId":"<game-session-id>"}}
```

```json
{"name":"profiler.start_capture","arguments":{"targetId":"<game-session-id>","durationMs":5000}}
```

Use `profiler.list_captures`, `profiler.get_capture` and `profiler.stop_capture` for recordings. The capture manifest includes `targetId`. Only one detailed capture runs at a time, shared by the panel and MCP.

Calls without `targetId` retain their existing process-wide scope and legacy payload. The legacy `fps` field remains for compatibility; use `updateRateHz` for update cadence in capture summaries.

AdaPlayer, external Swift processes, GPU resource counters and an interactive event timeline are outside this version.
