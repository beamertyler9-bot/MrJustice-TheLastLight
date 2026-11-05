# Changelog

## 0.40.0 — Lock-on, forest smoothness and spell effects (2026-11-04)

### Lock-on that sticks
- Lock-on now stays through hand aiming (beam and grapple), dodging and spell casting. It
  only drops when the target dies, gets more than 30 m away, or stays hidden for 1.5 s.
- Aiming while locked keeps the target under the reticle and tilts the view to its height.
- The hero keeps facing the target through rolls and casts; while the grapple is pulling,
  the lock pauses instead of clearing.
- The camera eases between lock-on framing and the aim view instead of cutting.
- The beam turns toward a locked target faster (4.2 rad/s, was 2.8).

### Entering forests
- Shader warm-up behind the loading screen (`scripts/shader_warmup.gd`): every tree, ground
  cover and spell material is drawn once while loading, so the phone's GPU driver compiles
  them up front instead of stalling the first time you walk into a forest or cast.
- Coarser mesh detail on lower settings (LOD threshold Low 4 px, Balanced 2.5 px, High 1 px).
- Measured walking 260 m into the densest nearby forest: 2 frames over 35 ms of CPU time in
  30 seconds, so world streaming itself isn't the cause.

### Spell effects
- Every impact now pops a white-hot eight-ray contact star and a shockwave ring that races
  outward, both gone in about a quarter of a second.
- Glows are three stepped toon bands with a slowly turning four-point sparkle (were flat discs).
- Spell strokes, beams and trails get a translucent glow fringe outside a thin ink line.
- Sparks and embers burn white-hot on camera-facing facets and twinkle individually.
- Charging the beam swells a glow in Mr. Justice's palm that pulses when fully charged.

## 0.39.0 — Smoothness pass (2026-11-04)

Measured running through the start area (desktop CPU; phones are slower but the ratios hold):
average frame 13.8 -> 9.9 ms, worst frame 370 -> 33 ms, frames over 50 ms 5 -> 0.

### Hitches removed
- Distant-house batch rebuilds bind incrementally within 1.5 ms per frame and keep the
  16 MB housing-vistas library cached (was a 280-370 ms freeze when approaching towns).
- Building a distant house only decides that house's visibility; the full pass runs once per
  batch (was re-checking every distant house after each one).
- New house templates merge with whole-array operations instead of per-corner SurfaceTool calls
  (was 50-70 ms the first time each house style appeared).

### Lighter every frame
- HUD redraws at half rate during play, and at full rate whenever a finger is on the screen.
- Interaction prompt search runs 10 times a second instead of every physics tick.
- World streaming budget 1.5 ms per frame on phones.
- Cape cloth steps at 30 Hz with 2 solver passes on Low/Balanced (High unchanged).

### GPU
- Adaptive resolution (`scripts/frame_governor.gd`): when the GPU is the bottleneck the 3D
  view renders at a lower internal resolution (down to 50%) and climbs back when there is
  headroom. Ceilings: Low 65%, Balanced 80%, High 100%.
- Balanced: small props draw to 65 m (was 85) and shadows to 24 m (was 30).
- Low quality holds a steady 30 fps.

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
