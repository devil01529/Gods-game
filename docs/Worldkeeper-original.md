# Worldkeeper
## PC civilization god-game • Design and build handoff

**Deliverable:** a development plan. **Target:** offline, single-player Windows desktop with mouse and keyboard. **Working title:** Worldkeeper. **Recommended stack:** Godot 4, GDScript, Git. Pin the exact stable engine version and matching export templates at kickoff. Astro and Codex are collaborators in the instructions below; either can execute any prompt.

### What the player actually does

Start at sunrise with twelve settlers on a riverbank. Click one and see what she intends to do, what she carries and where she sleeps. Leave her to choose a job, order her to build the village well, or take control and walk her there. Pull back to the globe and see dusk falling on the other side. A storm is coming. Spend the evening moving grain uphill, order the whole village to evacuate, or move the storm yourself. When you return a generation later, the old flood line and the hilltop granary should still tell that story.

**Reference:** Crytivo’s *The Universim* provides the broad idea of guiding a civilization through ages with god powers. Worldkeeper’s distinguishing feature is the ability to follow one decision from planet to person and back. Use original names, art, interface, writing, progression and assets. Reference: https://www.crytivo.com/the-universim

### Scope and controls

Build one finite, navigable planet. Start with a flat wrapped map for the first playable prototype, then render the same cells on a globe. East and west connect. The poles terminate movement and appear as impassable ice caps. The globe is a view of the live simulation, so a fire started in map view appears in the same place at ground level.

| Control level | Actions | Feedback |
|---|---|---|
| Planet | Pause, step, accelerate time, adjust climate, paint terrain, create or dismiss hazards | Preview affected cells, settlements and projected harm before committing large edits |
| Civilization | Set research, laws, trade, diplomacy, rationing, work hours and emergency priorities | Show which settlements adopted the order and what resource or condition blocks it |
| Settlement | Place, cancel and prioritize buildings, assign crews, set stock targets and evacuation zones | Ghost footprint, required materials, route and expected workers |
| Individual | Inspect, queue or cancel any supported task, move, gather, build, rest, fight, rescue or possess directly | Current order, next order, need and reason for failure; release returns control to AI |

Left click selects, right click orders, wheel zooms, drag pans or rotates, Space pauses, Escape cancels, Tab cycles person/village/world. While possessing, WASD moves and E performs the selected contextual action. Commands resolve in the order possession, explicit order, policy, autonomous job. Dangerous orders require a visible override. An impossible order returns a reason and releases reservations. Sandbox enables free powers, faction switching, spawning, resource editing and resurrection. Challenge uses the same controls with limited miracle energy and real material costs. Let the player continue in sandbox after extinction.

### World rules

- **Clock.** Prototype tuning: one day lasts eight real minutes at 1×, ten days form a season and four seasons form a year. Local solar time depends on longitude. Darkness changes work shifts, visibility and raid detection. A night shift needs lighting and daytime rest. Pausing stops every simulation timer while still allowing orders.
- **People and production.** Each person has a home, health, hunger, fatigue, inventory and job. Food moves physically from farm to storehouse to household. Workers reserve jobs and materials before travel. Children mature into workers as years pass; elders can transmit skills. Empty beds, food reserves and safety govern household growth. The inspector explains shortages in plain language, e.g. “Grain is available, but the bridge to the mill is flooded.”
- **Climate.** Separate daily weather from long-term climate. Track regional temperature, water and vegetation. Compute weather from latitude, altitude, season and seeded variation. Update a separate planetary heat trend each season from accumulated emissions minus carbon uptake. Heat shifts drought frequency and growing conditions over several years. Show recent weather and the multi-year trend separately. Reforestation, clean energy or a divine climate adjustment create different recovery paths.
- **Evolution.** Progress requires both knowledge and a demonstrated capability. Settlement unlocks farming after the first harvest; irrigation and a sustained surplus unlock towns. Town workshops and regular trade unlock industry. Powered research and a working regional grid unlock the planetary era. The final project is an orbital observatory that reveals incoming hazards earlier. Offer alternatives at each major gate, e.g. a trading port or an inland caravan market. Show the exact remaining requirement.
- **Enemies.** A neighboring faction needs food, territory and safe routes. Shortage can produce a trade request, a threat and finally a raid. Scouts can detect an approaching party. Tribute, alliance, evacuation, militia or divine intervention are valid responses. Raiders need supplies, can retreat and remember broken agreements. Give the god authority over every faction in sandbox.
- **Disasters.** Floods propagate to connected low ground and can cut roads; fire spreads across dry vegetation with wind; drought drains wells and suppresses yields; quakes damage vulnerable structures near a fault. Each needs a forecast or risk overlay, onset, visible impact and recovery work. A disaster ends even when the player ignores it. Keep the damaged world and displaced residents in play.
- **Powers.** Start with rain, lift a person and restore soil. Add raise/lower ground, shield, heal, ignite, change wind and shift temperature. Rain extinguishes fire but can flood a valley. Raising a levee can protect one village and divert water toward another. Preview the footprint and show the actual outcome in the chronicle. Challenge energy regenerates slowly with a fixed baseline even after a catastrophe.
- **Long-term objective.** Complete the observatory and keep two settlements supplied through one full year to finish the stewardship scenario. Sandbox has no end date. The chronicle links each major event to its map location, affected people, player orders and recovery.

### First playable scenario: The River Test

Use a fixed seed, twelve named adults, six days of starting grain, one lowland settlement, an uphill refuge and one neighboring camp. Day one teaches inspection, placing a storehouse, moving one worker and releasing control. On day two scouts report heavy rain upstream. On day three water floods the low road. The camp offers grain in exchange for timber; strained relations can turn that encounter into a raid. The scenario succeeds when at least eight settlers survive and regain a working food route. Also support a recoverable failed run. Replay the same seed and demonstrate three solutions: evacuate, negotiate for supplies, or reshape the riverbank. Script the storm and camp opportunity; simulate the water, deliveries and survival.

### Architecture and verification contract

Keep authoritative world state separate from Godot scenes. Use stable IDs for cells, people, factions, inventories, orders and events. A fixed-step simulation consumes validated commands stamped with tick, actor, target and parameters. Views subscribe to events. Split random streams for weather, citizens and factions. Use a seeded grid with elevation, biome, wetness, occupancy and adjacency. Keep geography stable when switching projections. Resolve movement, reservations and inventory transfers atomically; an interrupted delivery drops or returns its cargo exactly once.

Store rules for buildings, powers, eras and hazards in versioned data definitions. Persist clock, IDs, RNG states, terrain changes, tasks, cargo, reservations, relationships and pending events. Write saves to a temporary file, validate, then rotate the previous good save. A fixed-seed run resumed mid-flood must match an uninterrupted run on the same engine build. Near the camera render individual citizens; distant settlements use cheaper visuals first. Only introduce aggregate simulation after profiling and proving conservation of population and resources across transitions.

Start with a 128 × 64 world and 100 active citizens. Treat 30 fps at 1080p as an initial target, record the benchmark PC and frame times, then set the release budget using measured results. At final QA test 500 citizens, three settlements and overlapping fire and raid events. Include scalable UI, remappable inputs, separate audio sliders, reduced camera motion, high-contrast overlays and hazard shapes readable without color.

### Prompts for Codex and Astro

Give the complete file to both tools. Start with the standing prompt, then paste one numbered prompt at a time. Assign one implementer per milestone; the other reviews the resulting changes. Start each new session with the milestone number, current commit and last handoff. Advance only when its gate passes.

**Standing prompt — paste at project start**

> Use the attached Worldkeeper plan as the product specification. Inspect the repository and its instructions first. Preserve existing work and pin the engine version. Implement only the requested milestone, through normal game inputs. A visible button alone does not count. Use original placeholder art and licensed dependencies; record provenance. Keep simulation rules testable without rendering. Run available checks and a desktop smoke test. State exactly what you ran, what passed, and what still requires a human playtest. Return changed files, launch instructions, commit identifier if available and the next milestone. Never mark an unrun check as passed.

| Milestone | Copy-ready implementation prompt | Acceptance gate |
|---|---|---|
| 0 • Boot | Create the Godot project, input map, deterministic clock, seed picker, test runner and Windows export preset. Add a short README with exact editor, play, test and export commands. | Fresh checkout opens; new game starts; pausing and stepping advance exactly zero and one tick respectively. |
| 1 • Living map | Generate the wrapped world with land, fresh water, forest and ice. Implement local sunlight, settlement camera, cell inspection and pathfinding. Provide a developer seed with a traversable map seam. | Two sites half a world apart have opposite daylight. A worker route crosses the seam by the short path. Same seed yields the same terrain hash. |
| 2 • People and authority | Implement households, food, sleep, hauling, construction, stockpiles and reservations. Connect selection, queued orders, possession and release. Add reasons for blocked orders. | A settlement can feed itself for three days. Possess a hauler mid-delivery, redirect them, then release. No cargo duplication or stuck jobs. |
| 3 • First playable | Build The River Test with spreading water, refuge, trade-or-raid behavior, rain and terrain powers. Add a minimal HUD, forecast, casualty report and scenario restart. Tune the fixture until all three solutions are achievable. | Supply three reproducible command sequences and their results. Ignoring the warning produces a materially different outcome. |
| 4 • Whole planet and persistence | Add the globe renderer with continuous zoom to local play, synchronized selection and region overlays. Add versioned save/load, autosave, backup recovery and replay hashing. | Place a levee near the seam, inspect it in both views, save during flooding and reload. Cell identity, terrain, cargo and subsequent simulation hash agree. |
| 5 • Generations and ages | Add aging, skill transfer, settlement founding, the era gates, technology choices and observatory victory. Create accelerated test fixtures, and expose all gate requirements to the player. | Start with twelve people and progress through every era using normal commands. Verify a coastal and inland trade route to industry and victory. |
| 6 • Climate and calamities | Add seasonal water and heat trends, emissions, habitat recovery, fire, drought and earthquakes. Integrate forecasting, adaptation buildings, god powers and linked chronicle events. | Compare two identical seeds over ten simulated years with divergent energy policies. Show trend divergence, seasonal variation, building damage and successful recovery. |
| 7 • Rivals and divine sandbox | Extend the camp into persistent factions with scouting, diplomacy, raids, truces and memory. Complete divine controls, free editing and faction switching. Apply one order validation path everywhere. | Resolve one threat by treaty and one by defense. Switch factions, inspect both outcomes and confirm ceasefire survives a save/load. |
| 8 • Desktop release candidate | Profile the stress fixture, fix bottlenecks, run accessibility and save-recovery checks, and export a Windows build. Package controls, credits and reproducible QA results. | On the recorded test PC launch outside the editor, complete the River Test, reload a save and reach the objective. Report measured frame times and unresolved defects. |

**Review prompt — give to the second tool after each milestone**

> Review milestone [number] at [commit] against its acceptance gate. Reproduce the player path from a fresh start and from a save where available. Check a blocked command, a cancelled order and pause/resume. Compare simulation outcomes, inspect the diff and report reproducible failures in priority order with seed, steps, expected and actual result. Make no edits during review.

**Repair prompt**

> Fix the confirmed milestone [number] failure below. First reproduce it using the supplied seed and steps. Add the smallest regression check that catches it, repair the cause, rerun the gate and report evidence. Avoid unrelated changes. Failure report: [paste report].

**Handoff prompt**

> Summarize the current build for the next agent: engine version, current commit, completed gate, exact launch and test commands, known failures, seed or save fixtures and the next numbered prompt. Distinguish observed results from design targets.

**Production decision:** finish milestone 3 before investing in final art, extra civilizations or large maps. Watch a new player handle the first flood without coaching. If they cannot tell who is in danger, why the road failed, or how to intervene, improve those interactions before scaling the world.
