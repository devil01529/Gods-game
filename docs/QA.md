# Verification report — 2026-11-05

Engine: **Godot 4.6.3 stable standard**, official revision `7d41c59c4`. Project version **0.1.0**. Start seed **24017**. Android package `org.worldkeeper.game`, minimum API 24, target API 36, ARM64, debug signed.

## Observed results

| Check actually run | Result |
|---|---|
| Fresh project headless editor import | Passed; no script parse errors in final build |
| `godot --headless --path . --script tests/run_tests.gd` | **36 checks, 0 failures** |
| `godot --headless --path . --script tests/progression.gd` | **Passed**, tick 21,700, 12 survivors, all four eras, observatory and full connected supply year |
| `godot --headless --path . --quit-after 500 -- --input-smoke` | **Passed**; pointer, keyboard and multitouch events through visible UI |
| Same input smoke with `--mobile-ui` | **Passed**; compact person sheet, taller targets, possession/release, orders, build, rain preview/confirmation, save, pause and pinch zoom |
| X11 desktop input smoke, GL Compatibility, Mesa llvmpipe | **Passed**; actual rendered viewport inspected and screenshot captured |
| `godot --headless --path . -- --smoke` | **Passed**; scene integration, selection, orders, possession, construction, terrain edit, save/load and menus |
| Android debug export | **Succeeded**, approximately 28 MB |
| Android `apksigner verify --verbose` | **Passed**, APK v2 and v3 signatures |
| Android manifest inspection using `aapt dump badging` | ARM64; minimum 24; target 36; expected package/version |
| Linux x86-64 release export | **Succeeded** |
| Exported Linux binary, `--headless --quit-after 300 -- --smoke` | **Passed** |
| Windows x86-64 release export | **Succeeded**; execution on Windows not tested |
| Independent second-agent review requested by supplied brief | Authority, seam travel, evacuation, save atomicity and mobile access fixes rechecked; progression fixture independently passed |

Regression coverage includes zero-tick pause and one-tick stepping; stable seed; short seam routing and movement; cargo conservation when possession interrupts delivery; blocked orders; queues; construction reservations/refunds; destructive-power confirmation; death/resurrection; faith regeneration; completed construction and harvests; era gating; exact state hash after saves and subsequent flood continuation; corrupt-primary backup recovery; truce persistence; possession handoff on new orders and lifting; shelter hold; and rejection of malformed RNG, paths, building coordinates and queued commands before state mutation.

## Reproducible River Test fixtures

Run `tests/run_tests.gd` to repeat all four sequences below using only public game commands. Each starts a new seed-24017 world, orders a storehouse at **(−2,−2)**, and advances to tick **500**, before the flood at tick **960**. The test then advances another **1,400** ticks.

| Additional commands at tick 500 | Living people at tick 1900 | Outcome |
|---|---:|---|
| Do nothing | 0 | A recoverable world |
| `evacuate()` | 12 | River Test complete |
| `diplomacy("trade")` | 12 | River Test complete; camp provides grain and rescue boats |
| `place("levee",3,0)` | 12 | River Test complete |

In the UI, these correspond to **Guide → Evacuate**, **Cedar Camp → Trade**, or **Settlement → Stone levee** on the dry eastern edge of the village. The scripted fixtures prove the tuned outcomes; an uncoached first-time mobile playtest has not been performed.

## Performance evidence and limits

The environment exposes three AMD EPYC 9V74 CPU cores and a **software** OpenGL renderer, Mesa 25.0.7 llvmpipe LLVM 19.1.7. The rendered viewport was 1280×800. An early integration sample recorded approximately **134 ms per frame**, including startup/terrain rebuilding, under software rendering. This is not an Android GPU benchmark or a sustained release frame-rate measurement. The headless scene smoke is capped by the engine's 60 fps setting and does not measure visual performance.

**Not run:** physical Android install/play, Android emulator launch, thermals/battery tests, 500-person stress certification, native Windows launch, screen-reader accessibility, store distribution, or full original eight-milestone acceptance. CI is configured but its GitHub-hosted result is separate from these local observations. See DEVELOPMENT.md for simulation simplifications and the next milestone.
