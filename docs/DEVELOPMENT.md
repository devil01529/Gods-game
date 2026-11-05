# Development handoff

## Product decisions

The user's direct Android requirement supersedes the attached brief's Windows-only target. The engine is pinned to Godot 4.6.3 standard and matching templates. This repository delivers the River Test as an original stylized 3D game, using GL Compatibility for wider Android support. The supplied document's production decision prioritizes the first playable before larger worlds or final art; this remains the next production boundary.

## Implemented and exercised

- Fixed-step clock, pause, step, 1×/4×/16×, seed entry, wrapped geography, impassable poles, short seam pathfinding **and actual seam traversal**.
- Twelve named citizens, needs, job roles, travel, harvest cargo, building crews, resource reservations, cancellation refunds, explicit and queued orders, possession/release, lift, healing, destructive powers and resurrection.
- River Test forecasts, day-three flood, persistent evacuation hold, real casualties, camp trade with rescue boats, levee/raised-bank protection, recovery, restart and five objectives.
- Local procedural 3D scene, instanced forest, original buildings, crops, water shader, birds, campfire smoke, rainfall, rafts, selected-person ring, brush footprint, live terrain globe overview and overlays.
- Touch panning, pinch zoom, scrollable action bars, mobile person sheet, possession movement pad, always-accessible Guide, high/battery graphics, reduced camera motion, contrast, optional synthesized ambience and volume.
- Four era gates and nine building rules. Demonstrated harvest, market/workshop/trade, powered knowledge and observatory can be reached through normal simulation commands.
- Versioned lossless saves including RNG state, reservations, cargo and tasks; temporary-file write, backup rotation, strict pre-mutation validation and recovery.
- Relation changes, truces retained through save/load, abstract supply raids and defenders. Sandbox stock editing, faction choice for new citizens, and continued play after extinction.

## Simplifications to retain in release descriptions

This does not certify every acceptance gate of the original eight milestones. In particular:

- Food shares a settlement stock after delivery rather than full per-household inventories and item-by-item logistics. Individual home IDs exist; marriage, children, inheritance and generational skill transmission do not.
- Flooding follows one water level, with a tuned levee/raised-bank condition. It is not a connected-cell hydrology solver. Trade rescue boats are aid/exposure reduction, not a fleet logistics simulation.
- The globe reprojects the terrain cells and responds to edits; it does not render all people and buildings or provide continuous globe-to-person zoom. Lighting uses a shared local daylight cycle; the inspector calculates longitude-specific solar time, but there are not simultaneous regional light sources.
- Fire spreads to neighboring vegetation and expires; earthquakes damage nearby structures; weather and seasonal heat are separate. There is no complete drought/well-water model, atmospheric circulation, flood sediment, or adaptation economy.
- Diplomacy and raids are event/resource simulations. Guard orders can repel raids, but enemies are not tactical units with supplies and retreat behavior. Existing camp tents do not contain a full simulated rival population; sandbox can create and command citizens of either faction.
- Research uses four explicit gates, not the reference game's technology tree. The observatory is a stewardship objective; space travel and colonization are absent.
- No final 500-person profiling certification, remappable bindings, store release signing or physical Android device certification. Renderer targets are goals, not performance guarantees.

## Next milestones, in order

1. Have a new player complete the first flood on a physical Android phone without coaching. Check touch target size, safe-area cutouts, heat, battery and frame pacing; adjust quality presets from measurements.
2. Replace the global flood-level shortcut with deterministic connected water propagation and bridge/road damage. Add true material reservations and physical transfers among local inventories.
3. Make globe/local projections continuously share selection, units and daylight, with regional overlays and population LOD.
4. Add families, population growth, neighboring faction agents, trade routes and research alternatives. Track each settlement's inventories and yearly supply independently.
5. Expand disaster forecasting, drought, carbon accounting, accessibility/remapping, profiling and release signing. Upgrade original art against measured mobile budgets.

## Technical map

- `scripts/simulation.gd`: authoritative state, fixed tick, commands, scenario and persistence.
- `scripts/rules.gd`: versioned building and power data.
- `scripts/world_view.gd`: projection, terrain, instancing, models and effects.
- `scripts/main.gd`: game UI, touch/desktop input and integration smoke hooks.
- `tests/run_tests.gd`: deterministic and regression checks; scenario fixtures.
- `tests/progression.gd`: all-era/observatory/year fixture using public game commands.
- `.github/workflows/build.yml`: import, tests, Android/desktop exports and downloadable artifacts.

Save format version: 1. A debug APK is installable but must not be presented as a signed Play Store release. Reuse the same signing key for subsequent installs if save continuity matters.
