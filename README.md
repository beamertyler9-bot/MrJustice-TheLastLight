# The Adventures of Mr. Justice

An atmospheric adventure of a little lantern hero. Built with **Godot 4.5.1** (Compatibility / GLES3 renderer), targeting Android phones.

## Opening the project

1. Download this repository (on GitHub: **Code → Download ZIP**) and unzip it.
2. In Godot 4.5.1 (desktop or the Android editor), choose **Import** and pick `project.godot`.
3. The first open takes a minute while Godot imports the textures and sounds.

Export settings for Android are in `export_presets.cfg` (package `org.christina.mrjustice.worldpreview`, arm64). The `expanded_world` custom feature tag must stay on.

## Where this source came from

This repository was rebuilt on 2026-11-04 from the v0.36.27 APK, because the original project lived only in the Godot Android editor's private storage. What that means:

- All 163 GDScript files were recovered from their exported token form with their logic and line numbers intact. **Code comments did not survive the export**, so the scripts have none.
- Scenes, meshes, materials, shaders and world data are the exported originals.
- Textures were re-saved as PNG/JPG, sounds decoded to 16-bit WAV, and fonts extracted to TTF. A few SVG files are stored as SVGs wrapping the exported raster image.
- Import settings were reconstructed from the exported files; resource UIDs were kept, so references between files still resolve.

See `CHANGELOG.md` for what changed after recovery.
