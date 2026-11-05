# Original models, assets and licenses

- All Worldkeeper game code, planet generation, UI, icon, environment, shaders, animation, effects, synthesized sounds and mesh models were authored for this repository. No assets were extracted from The Universim or another game.
- **21 original GLB models**: four citizen variants with separate moving limbs, nine building types, four tree variants, dog, cat, deer and rescue boat. The Blender generator is `tools/create_models.py`; ready-to-use files are in `assets/models`. Models are vertex painted and batched by part to reduce draw calls. Blender 4.3.2 was used to generate them.
- `assets/textures/meadow.png` is an original deterministic procedural grayscale detail texture, generated with NumPy/Pillow. Grass meshes, atmosphere, water, fire, smoke, electricity and tornado visuals are procedural original assets.
- **Inter**, Inter Project Authors: https://github.com/google/fonts/tree/main/ofl/inter. SIL Open Font License 1.1, retained at `assets/fonts/Inter-OFL.txt`.
- **Cormorant Garamond**, Christian Thalmann and contributors: https://github.com/google/fonts/tree/main/ofl/cormorantgaramond. SIL Open Font License 1.1, retained at `assets/fonts/Display-OFL.txt`.
- Godot Engine **4.6.3**, MIT: https://godotengine.org/license/. Matching official export templates carry the engine's third-party notices.
- Broad genre reference: Crytivo's **The Universim**, official Steam listing https://store.steampowered.com/app/352720/The_Universim/. Worldkeeper does not claim the reference game's technology tree, galaxy, content or complete feature set.
