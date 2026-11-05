# Worldkeeper — Living Planet 0.2

An offline Android god-game built with **Godot 4.6.3**. Explore one continuous spherical planet, guide every citizen, build settlements, wield destructive and restorative powers, and nurture animals and new generations.

**[Download the Android APK](https://github.com/devil01529/Gods-game/releases/download/v0.2.0-preview/Worldkeeper-planet.apk)** · [Download page](https://github.com/devil01529/Gods-game/releases/tag/v0.2.0-preview)

Open the APK on an **ARM64 Android 7.0+** phone with OpenGL ES 3.0. It installs as **Worldkeeper Planet**, alongside the original base app, keeping the original installation intact. Play in landscape. This is a development preview; native phone performance is still awaiting a physical-device test.

![Living Planet gameplay](docs/screenshot.png)

## What changed from the base APK

- **One spherical world:** 32,768 live cells, an 82-unit planet radius, oceans, rivers, continents and polar caps. Every person, animal, tree and building belongs to that same surface. Drag to orbit and zoom continuously; tap a distant region to descend there. The square terrain patch and floating refuge labels are gone.
- **Original 3D models:** four articulated citizen variants, nine building models, four tree variants, dogs, cats, deer and rescue boats. Characters walk and work with animated limbs. Models are shipped as GLB assets, not sprites or static scenery images. Textured ground, instanced vegetation, flowing water, atmosphere, clouds, fire and smoke replace the base presentation.
- **People obey:** the simulation runs at 10 Hz instead of one-second jumps. Citizens move at 1×. Move finishes with Hold; explicit orders stay in force until released. Queues, interrupted work, construction targets and cargo recovery have regression coverage. Menus pause the world while open and restore your prior pause state.
- **Consequential calamities:** wildfire, deluge, lightning, earthquakes, tornadoes, meteors and drought. Fire burns people, vegetation and buildings; deep water drowns; lightning follows connected water; quake impacts injure or kill and damage structures. Rain extinguishes flames and restores dry soil. Wet ground resists ignition; wind spreads fire. Shields protect people and animals. Rigid debris uses radial gravity and terrain/building collision.
- **Life and intervention:** pets follow owners, roam or stay; animals eat and can die. Healthy adults with food and spare beds can have children. You can pair adults, bless a birth now, delay or cancel an expected birth, pause natural reproduction, guide growth, heal, kill or resurrect.

## Play

**Phone:** drag to orbit, pinch to zoom. **Earth** pulls back to the whole planet; tap a region to zoom in. Tap a person or open **People** to inspect and command them. Select an order and tap its destination. **Resume autonomy** releases direct control; **Possess** opens a movement pad. The lower action row scrolls horizontally.

**Powers** contains restorative and terrain controls. **Disasters** contains destructive powers, each with a footprint and confirmation. Press **Play** if the clock is paused and you want ongoing fire, water and injuries to advance. **Build** places foundations; autonomous builders travel there. A builder with your Hold command will stay put until released. **Life** contains families, pets and reproduction controls. **World** contains research, diplomacy, laws, chronicle and climate. **Menu** contains saves, graphics, contrast, motion and sound settings.

**Desktop:** mouse wheel zooms; drag orbits; Space pauses; Tab changes planet/surface distance; Escape closes or cancels. WASD moves a possessed person and E gathers timber. Time rates are 1×, 4×, 8× and 16×. One day lasts eight minutes at 1×.

The five objectives are to meet a person, give an order, build a storehouse, welcome a new generation and construct an observatory. The River Test still brings a flood on day three. Survive by evacuation, a levee/riverbank intervention or rescue boats negotiated from Cedar Camp.

## Build and test

Install **Godot 4.6.3 standard**, with matching export templates. Blender is only needed to regenerate models; the checked-in GLB files are ready to run.

```sh
godot --headless --path . --editor --import --quit
godot --path .
godot --headless --path . --script tests/run_tests.gd
godot --headless --path . --script tests/progression.gd
godot --headless --path . --script tests/physics_integration.gd
godot --headless --path . --quit-after 600 -- --input-smoke --mobile-ui
godot --headless --path . -- --smoke
```

Test markers are `PROGRESSION_PASS`, `PHYSICS_PASS`, `INPUT_SMOKE_PASS` and `UI_SMOKE_PASS`. CI checks these markers as well as process status; GDScript assertions alone do not terminate a running scene.

To export Android, install JDK 21, Android platform-tools, `build-tools;36.0.0` and `platforms;android-36`; set `JAVA_HOME` and `ANDROID_HOME` and configure the local debug keystore in Godot's editor settings:

```sh
python3 tools/configure_android.py
mkdir -p builds
godot --headless --path . --export-debug Android builds/Worldkeeper-planet.apk
```

Linux and Windows export presets are also included. Model source is reproducible with `blender -b -t 2 -P tools/create_models.py`. Signing keys and machine SDK paths are not committed. The published preview uses the tested local APK; CI exports are separately signed development artifacts.

## Boundaries

These are deterministic **game physics**, with local water-level transfer, moisture, fire spread, electric connectivity, collision and radial debris gravity. This is not a scientific atmospheric or fluid solver. Wildlife, farming, households, relationships, trade and combat are intentionally simplified. There are no tactical armies, galaxy colonization, full genetics, marriage/social dialogue systems, or feature parity with The Universim. Planet details use distance-based visibility for mobile rendering. Version 2 saves are separate from the base APK's version 1 saves.

[QA results](docs/QA.md) · [Development notes](docs/DEVELOPMENT.md) · [Models and licenses](docs/CREDITS.md) · [Original brief](docs/Worldkeeper-original.md)
