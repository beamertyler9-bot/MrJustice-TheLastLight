# Changelog

## 0.43.0 — The magic overhaul (2026-11-04)

### A whole new spellbook
- All previous spells are replaced by a new catalog of 84 (`scripts/spell_catalog.gd`): every
  element has **2 basic spells and 5 advanced spells**. The spells within each element use
  different kinds of magic (bolts, beams, cones, rains, fields, orbitals, walls, wards,
  summons, steps, strikes from the sky).
- **Starting spells:**
  - **Fireball:** hold to charge, then it is thrown in an arc. Charging makes it bigger,
    hotter and go further, and a dotted arc shows where it will land.
  - **Skybolt:** lightning cracks down out of the sky onto your target, forking and
    flickering.
  - **Lantern Beam:** hold to charge, then a Kamehameha-style beam pours out of Mr. Justice's
    lantern.
  - **Levitation:** lifts objects, rocks and creatures.
- New spell mechanics:
  - Hold-to-charge for any spell. While charging, a ball of the element grows in the hand, or
    in the lantern for lantern spells, and the camera moves over the shoulder. The cast
    button shows a charge ring.
  - Spells can come from the lantern.
  - A new "strike" form: lightning bolts from storm magic, a pillar of light from light
    magic, a giant falling icicle from frost magic.
  - Arcing throws land where you aim.
- The spell library labels spells as Basic or Advanced and shows which can be charged. Your
  own custom spells are kept; old saves get the new starter spells in their quick slots.

### Elements look like themselves
- Each element's spells use its own core, shapes, particles and impact (fire churns,
  lightning crackles, water wobbles, earth is rock with magma cracks, frost is ice, and so on).

### Also
- **Double jump:** jump again in the air for a second burst of height, and Mr. Justice does
  a front flip.
- **Dev menu → Magic → Infinite mana:** an on/off toggle; spells cost nothing while it is on.

## 0.42.0 — Every element looks like itself (2026-11-04)

- **Fireball is a ball of fire.** The phoenix-wing shape is gone. A churning sphere of
  fire licks outward, flame tongues stream back off it in the direction it is flying, a wake
  of fire trails behind, and embers spill off it. On impact it blooms into a fiery
  explosion.
- **Each element has its own core** (`shaders/magic/element_core.gdshader`), shaded in the
  shared energy tones but with a surface only that element has:
  - fire: churning, licking flame
  - frost: icy body with bright facet cracks
  - storm: crackling plasma with jumping filaments
  - grove: a seed with growing light veins
  - light: a radiant sun with sweeping rays
  - shadow: an ink drop lit only at its rim
  - water: a wobbling clear drop with caustics
  - wind: a translucent swirl
  - earth: a lumpy boulder with magma cracks
  - metal: polished bands
  - void: a dark hole with a hot rim
  - time: a golden clock face with ticking hands
- Spell projectiles keep their element shapes (ice blades, lightning, leaves, moths, water
  sheets, wind crescents, stones, blades, broken orbits, clock arcs) around that core.
- Impacts burst open as an expanding ball of the element, under the shared contact star and
  shockwave, so every hit is recognisable at a glance.
- Smaller, calmer glow cards, and no more striped dashes along spell trails.

## 0.41.0 — Liftable rocks, one magic style, Kamehameha beams (2026-11-04)

### Pick up rocks
- The "Mine stone" rocks around the world (up to 2.8 m across) can now be picked up: with no
  pickaxe in hand, hold B (E on keyboard) next to one. A tap still explains mining, and with a
  pickaxe equipped, B mines as before.
- Levitation spells can grab them too: aim at a rock and it comes loose.
- Big rocks are heavy (2-11 kg; the basic Levitation spell's limit is 12), slow you a little
  while carried, can be thrown, and stay where you leave them across saves.

### One style for all magic
- Every magic shader now shares one energy look (`toon_magic.gdshaderinc`): a white-hot centre,
  the accent colour, the element colour, then a translucent stepped glow. Black ink outlines
  on energy are gone; magic reads as light on any ground.
- Strokes, trails and ribbons, flames, sigils, void rifts, glows, impact stars and shockwaves,
  and the rim glow of solid spell objects all use it. The "ink" material style is still
  available as a deliberate choice.

### Kamehameha beams
- New beam renderer (`kame_beam.gd`, `kame_beam`/`kame_glow` shaders) for Mr. Justice's hand
  beam and every beam spell:
  - It bursts from the hands and reaches the target in 0.12 s, holds, then thins away.
  - The column is solid from any angle, including from behind the shoulder.
  - Bulges travel down its length, streaks race along it, and an aura sheath spirals around it.
  - A muzzle orb sits at the hands, a pulsing head orb at the front, and sparks race alongside.
- Charging the hand beam builds a swirling energy ball in the palm with sparks spiralling in.
  It throbs and the view hums when fully charged.
- Charged hand beams are thicker, hold for about a second, add a short hit stop and a strong
  rumble, and land with the contact star, shockwave and glow.
- Spell beams use their spell's colours; chain links and tethers are thin versions of the
  same beam.

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
