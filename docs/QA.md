# Living Planet 0.2 — observed verification

Godot **4.6.3 stable**, `7d41c59c4`. Default seed **24017**. Tests executed in the managed Linux environment on 2026-11-05.

| Check | Observed result |
|---|---|
| Authoritative simulation regression suite | **75 checks, 0 failures** |
| All-era construction/research fixture | **Passed**, 12 survivors; explicit extra timber and year-boundary counter fixtures |
| Rigid physics integration | **Passed**: radial gravity, spherical terrain collision, debris and pause freeze |
| Desktop pointer/menu integration | **Passed**: spherical picking, commands, possession/release, construction, rain preview, save and family policy |
| Compact Android layout with injected touch/key events | **Passed**: same flows, real contrast changes, pinch, drag and pause |
| Scene integration smoke | **Passed**: globe, models, people, commands, persistence, menus, animals and families |
| Rendered X11 GL Compatibility showcase | Rendered surface, globe, wildfire, rain, flooding, lightning, quake and tornado scenes; images inspected during development |
| Independent review | Six reproduced command, shield, persistence and contrast issues fixed; reviewer reran 68 checks before seven further tests were added |

The 75 checks cover deterministic setup and save continuation, pause and tick behavior, spherical projection, immediate 1× movement, 1×/16× batching equivalence, persistent orders, queued and blocked work, cargo conservation, construction/refunds, terrain/building collision, lethal calamities, rain/fire interaction, wet-ground ignition prevention, connected-water conduction, shields for humans and animals, water transfer accounting, drought relief, pets, births and intervention, malformed-save rejection, backup recovery, truce persistence, structural fire damage, healing and safe evacuation.

The reproduction fixture uses real birth logic, stable parent IDs and a due birth; it explicitly advances the clock to test the boundary. The progression fixture supplies timber and advances a year counter near its boundary. These are accelerated verification fixtures, not claims of a complete unaided multi-year playthrough.

Rendering used Mesa 25.0.7 llvmpipe software OpenGL, not an Android GPU. Images show an actual rendered game viewport, not mockups. No sustained mobile FPS, thermals or battery claim is made. **Physical Android installation and playtest, native Windows execution, 500-person stress certification, full scientific fluids and store publication were not run.** The APK is a debug-signed preview.

See README for exact commands. GitHub-hosted CI and APK signature verification are separate build observations; the release page attaches the tested APK directly rather than making players extract a workflow ZIP.

## Packaged APK

`Worldkeeper-planet.apk` was exported from game source commit `f2bae62f81dbbd664be1d6d925cdaff6d2013143`. Android package inspection confirms `org.worldkeeper.planet`, version 0.2.0 / code 2, ARM64, minimum SDK 24 and target SDK 36. `apksigner verify --verbose` passed APK v2 and v3 signature verification. SHA-256: `91cefafa54b3a9bde1d7f9b6910a19535036c2e459f34cdf32830ed885dcfeb4`.

The signed APK and checksum are held on the separate `codex/living-planet-apk` distribution branch; no private signing key is stored there. The release job publishes that verified binary only after source CI checks and exports succeed. Keeping the public distribution APK separate from the source branch avoids adding it to the code-review diff.
