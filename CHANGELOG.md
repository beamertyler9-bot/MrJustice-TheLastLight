# Changelog

## 0.38.0 — Lighting, camera and game-feel pass (2026-11-04)

### Camera
- Smoothed follow pivot that lags vertically while airborne, so jumps no longer jerk the view
  (vertical camera travel over a run-and-jump test: 6.6 -> 5.6).
- Orbit responds instantly to input; only the follow is smoothed, so turning no longer cuts
  corners or changes the camera distance.
- Collision distance snaps in when something blocks the view and eases back out, removing pops.
- Slight look-ahead toward the direction of travel.
- Gentle auto-follow: after 1.4 s without camera input, the camera swings in behind a running
  hero (never while aiming, in the bag view, or when running toward the camera).
- Noise-based shake with a little roll, plus directional kicks on hits given and taken.
  All of it respects the existing Camera Shake setting.

### Game feel (`scripts/game_feel.gd`)
- Hit stop: 55 ms on melee hits, 95 ms on the combo finisher, 130 ms on a defeating blow,
  75 ms when hurt, and a lighter, damage-scaled freeze on spell hits. Real-time timed and
  never active outside gameplay.
- Phone vibration on hits, spell release, hard landings and damage (Android; follows the
  Camera Shake setting).
- Squash-and-stretch pop on enemies when struck (skipped on defeating blows).
- Hard landings add camera trauma.

### Lighting
- Golden hour: warmer, punchier low sun, violet-tinted ambient, and fog that glows toward the sun.
- Night: cooler moonlit ambient and softer shadows.
- The hero's lantern is subtle in daylight (no more midday spotlight on the ground) and blooms
  at night and indoors.
- High quality: soft glow so spell cores, flames and the lantern bloom slightly.

## 0.37.0 — Remaster pass (2026-11-04)

Measured in the Bellcrown/Brindlewick start area with the default (Balanced) quality.

### Performance
- **Hero batching.** Mr. Justice's ~260 rigid pieces render as one skinned mesh per material
  plus a single shadow-only mesh (`scripts/rigid_skin_batches.gd`). Joints drive bones every
  frame after animation, so his hand-authored procedural animation is unchanged.
  Hero draw calls: ~132 -> ~40 (shadows ~60 -> 1).
- **Distant forests.** Impostor-forest cells grouped at 768 m instead of 192 m, with a
  1,400 m range. ~1,400 -> ~110 draw calls for the horizon, same picture.
- **Far castle silhouette** flattened to one mesh per material (134 -> ~10 draws).
- **Shadows.** Balanced quality uses one orthogonal cascade with a 2048 atlas (was two PSSM
  splits), halving the shadow pass. High keeps two cascades.
- **Textures.** 3D textures import as VRAM-compressed with mipmaps (ETC2/ASTC on phones);
  raw 1024 px ImageTexture resources re-encoded as ETC2 with mipmaps. UI art, palettes and
  small textures stay lossless. GPU texture memory 302 MB -> 126 MB (desktop measurement;
  lower on phones).
- **Magic shaders** no longer read the screen texture (saves a full-screen copy per frame).
- Result: engine draw calls at spawn 1,306 -> 823; looking back across town 1,510 -> 901;
  town-centre view 2,004 -> 554 visible draws. Scene nodes 14.9k -> 11.0k.

### Magic visuals
- All spell shaders rebuilt in the game's cel-shaded language (`shaders/magic/toon_magic.gdshaderinc`):
  ink outline, flat body, hot core, anti-aliased band edges. Replaces faint additive glows that
  washed out on sunlit ground.
- Cartoon fire, inked sigils, two-tone halos, lobed smoke puffs, banded void rifts; solid spell
  objects use world-style banded lighting with a coloured rim.
- Spell walls are stacked, irregular blocks with a crenellated cap that pop up with an overshoot
  and sink away when they expire. Bolder lightning and beams.

### Townsfolk
- Motion-captured idles (two variations), talking with gestures, and walking, retargeted from
  Human Basic Motions FREE onto the townsfolk rig (see `assets/animation/residents/CREDITS.md`).
- Residents alternate idles, talk while greeting the player, and walk with playback speed
  matched to the clip's stride. Softer blends between states.

### Project
- Source recovered from the v0.36.27 APK (see README). Comments did not survive export.
