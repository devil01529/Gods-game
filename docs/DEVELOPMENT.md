# Living Planet 0.2 handoff

Engine: Godot **4.6.3 stable standard**, official `7d41c59c4`. Android target API 36, minimum API 24, ARM64, GLES 3 compatibility renderer. Package `org.worldkeeper.planet`, version code 2. This installs beside the original `org.worldkeeper.game` base APK because the original release's CI signing key was ephemeral. Its private key cannot be recovered from an APK. Keep the local preview signing key for future Living Planet releases; never commit it.

## Authoritative world

`simulation.gd` is independent of rendering. A fixed tick is **0.1 seconds**, and a day is 4,800 ticks. A seeded 256×128 grid wraps longitude and terminates at ice caps. Longitude/latitude map coordinates project onto an 82-unit radius sphere. The same identities and changes are used at every camera distance. Terrain, water levels and visual depths share one height scale. There is no separate flat rendering scene.

Commands distinguish Auto and God authority. A direct Move ends with Hold; roles do not silently override it. Queued construction does not change the active target. A blocked path retains its original action. A queued command that becomes impossible stays queued with a reason and retries. Building footprints block paths and possession. Construction and delivery use accessible adjacent cells, with cargo returned exactly once when interrupted.

People have needs, homes, jobs, sex, age, partners, pregnancy, parents and command state. Natural births need health, food and beds, count pending births against spare capacity, and respect the reproduction policy. Manual intervention can pair adults, bless, delay or cancel a birth, or mature a child. This is a small population lifecycle, not a complete genetics/social simulation.

Dogs/cats can follow owners, stay or roam. Deer roam and graze. Animals have hunger, health and mortal exposure; shields cover direct and ongoing damage. Animal target data and IDs are validated during load.

## Element rules and rendering

Water transfers between neighboring cells using surface-level differences, with bounded transfer and evaporation. Rain repeatedly wets its area while active. Wet cells suppress ignition and extinguish burning cells. Wind biases seeded fire spread; fuel burns down, vegetation chars, and moist habitats can regrow seasonally. Drought suppresses affected farms until relief or expiry. Lightning searches connected conductive water and damages people beyond its initial strike radius. These coarse game rules do not model full fluid momentum or a scientific atmosphere.

Fire, drowning, electricity, quake impact, tornado exposure and meteor impact can kill. Fire and prolonged flooding damage structures. Healing restores people, animals and structures. Trade supplies rescue boats; those people ride modeled boats and avoid drowning. Shields remain separate from sandbox: sandbox makes spells free, not people invulnerable.

The render layer uses original GLBs, articulated citizen limbs, indexed spherical terrain, shared-corner water surfaces, water shading, instanced vegetation, atmosphere, clouds, billboard flame shaders, persistent smoke, scorch patches, electrical arcs and a swirling funnel. Distant detail is hidden to avoid a spiky toy globe. Visual rebuilding is throttled independently of simulation speed. Static terrain/building colliders and a point-gravity area drive rigid debris; those cosmetic bodies are not serialized or used as authoritative damage calculations.

## UI and saves

Responsive mobile controls are larger than desktop controls, with scrollable tools and modal bodies. A full-screen modal backdrop consumes input and pauses the simulation; closing restores the previous user-selected clock state. Saved pause state excludes this temporary menu pause. Physical phone gestures still require device testing beyond injected touch events.

Version 2 uses a checksummed JSON envelope containing a lossless Godot Variant payload. Saves include random streams, active environmental cells, births, animals, queues, cargo and policies. Validate before mutation, write a temporary file and rotate the previous good save to backup. Version 1's geography and format are not silently reinterpreted as version 2.

## Files

- `scripts/simulation.gd`: state, commands, ecology, hazards, households/population and persistence.
- `scripts/rules.gd`: building, era and power definitions.
- `scripts/world_view.gd`: sphere, meshes, model animation, effects and colliders.
- `scripts/main.gd`: touch/desktop controls, menus, camera and integration hooks.
- `assets/models/*.glb`: original ready-to-use models; regenerate with `tools/create_models.py` under Blender 4.3.2.
- `tests/run_tests.gd`: 75 regression checks.
- `tests/progression.gd`: real construction and era gates with explicit timber and year-boundary fixtures, not a full wall-clock year playtest.
- `tests/physics_integration.gd`: real rigid-body gravity, terrain collision and freeze behavior.

## Remaining production work

Measure sustained frame pacing, heat and battery on a physical Android phone and tune presets. Expand local inventories, routes, family aging and occupations; add tactical rival agents, detailed climate, accessibility/remapping and broader stress fixtures. The 500-person release stress target from the original brief is not certified. Keep graphical and simulation performance claims distinct.
