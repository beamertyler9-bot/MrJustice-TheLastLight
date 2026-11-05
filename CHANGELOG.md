# Changelog

## 0.48.0 — New magic circle designs (2026-11-05)

- **Magic circles:** replaced all twelve circle designs with the new elemental set: a clean
  double ring with diamond points around a glowing element symbol (a flame, a snowflake, a
  thundercloud, a sprout, a four-point star, a crescent moon, a water drop, gusts of wind,
  mountains, an anvil, a spiral and an hourglass). Each one animates on a 16-frame loop.
  They still appear in the same places: at the hand, growing while you charge, on the ground
  under area spells and at Mr. Justice's feet for wards, heals and teleports.

## 0.47.0 — Magic circles (2026-11-05)

- **Magic circles:** every spell now opens an animated magic circle where it is cast, drawn
  from twelve hand-made circle designs, one for each element (flame, frost, storm, grove,
  light, shadow, water, wind, earth, metal, void and time).
  - **At the hand:** a circle flares open in front of Mr. Justice's hand (or lantern) as the
    spell leaves it, facing the direction he casts.
  - **While charging:** hold-to-charge spells (Fireball, Lantern Beam and the others) open
    the circle as soon as you start holding. It follows your aim and grows and brightens as the
    charge builds, then bursts when you let go.
  - **On the ground:** area spells (bursts, fields, rains, strikes, traps and walls) also draw
    a circle on the ground under the target, sized to the area. Lasting fields keep theirs for
    as long as they last.
  - **At his feet:** wards, heals, teleports and summons draw the circle beneath Mr. Justice.
  - The Railgun keeps its own triangle of charging seals.
- The circle shader is warmed up behind the loading screen, so the first cast does not hitch.

## 0.46.0 — Spell-by-spell rework (2026-11-04)

- **Phoenix Dive:** a real firebird with a blazing body, a head with a golden beak, two great
  flapping wings of flame and long tail plumes. It is fired from your hand, explodes, and
  leaves the ground burning for four seconds.
- **Fireball:** now fires straight at what you aim at, and gravity gradually pulls it down.
  Charging makes it faster, bigger and longer-ranged. The dotted path shows where it will hit.
- **Storm:**
  - Thunder Lance (and every storm beam) crackles with forking lightning along the beam.
  - Thunderclap is a massive bolt of lightning out of the sky.
  - Thunderstorm summons a dark thundercloud over the target that rains lightning.
- **Lantern Beam:** Mr. Justice no longer raises his hand while charging it (it comes from
  his lantern).
- **Beams:** solid columns of light, no longer see-through. Levitation draws a thin thread
  instead of a blast.
- **Judgement Pillar:** the pillar of light lasts five seconds and burns everything in it the
  whole time.
- **Wind and frost:**
  - Gust is a cone of rushing wind streaks.
  - Frost Breath blows a billowing cloud of frost and ice forward.
  - Glacier Spike bursts a massive jagged spike of ice, ringed by smaller ones, up out of
    the ground.
  - Blizzard is a freezing cloud that rains hail and slows enemies.
- **Water:**
  - Tide Splash is a tidal wave that rolls out in front of you and crashes.
  - Torrent Beam is a jet of real water.
  - Whirlpool swirls down into a vortex.
  - Geyser erupts for longer with a splashing crown on top.
- **Earth:**
  - Earthquake splits the ground open in a glowing fissure, with rocks heaving along it, for
    massive damage.
  - Landslide drops 12 boulders over a longer time.
- **Railgun:** while charging, a magic circle opens in front of your hand, then three more
  lock into a triangle and the array spins faster and faster. On release a colossal beam
  fires with lightning crackling around it, and the circles blast down the barrel.
- **Null Lance (and all void beams):** black at the heart with a burning edge.
- **Time magic is clock-themed:**
  - Every time spell has a real clock face with ticks, a bezel and moving hands.
  - Hourglass Rain and Stasis Field show a giant clock with turning gears.
  - Rewind shows a clock behind Mr. Justice with its hands running backwards.

## 0.45.0 — Spells look like their names (2026-11-04)

- New per-spell signature visuals (`scripts/spell_motifs.gd`, `motif` field), built from the
  shared magic shaders:
  - **Tornado:** a spinning funnel with debris swirling up it.
  - **Updraft:** a rising column of air.
  - **Geyser:** a water column that erupts and rains spray.
  - **Whirlpool:** rings spiralling into a pool of water.
  - **Earthquake:** rocks heaving out of the ground in pulses.
  - **Ring of Fire:** a circle of flames.
  - **Static Field / Stasis Field:** a dome of crackling plasma or golden clockwork.
  - **Overgrowth / Vine Snare:** a thicket of thorns sprouting up.
  - **Healing Rain:** droplets falling on you.
  - **Bloom Mend / Radiant Mend:** petals spiralling up around you.
  - **Eclipse / Black Hole:** a black sun with a burning corona.
  - **Magnet Pull:** field lines drawing inward.
  - **Frost Nova:** a ring of ice shards bursting outward.
  - **Gale Ring:** expanding rings of wind.
  - **Wards:** a shell of the element around you, such as orbiting rock plates for Stone
    Skin, steel for Steel Guard and embers for Cinder Ward.
  - **Phoenix Dive:** a fireball with flapping wings of flame.
- Projectile shapes match their names:
  - Rock Throw, Pebble Spray, Boulder Crash and Landslide throw actual rocks.
  - Ember Darts and every bolt, lance, shard and comet spell fly as streaks, not balls.
  - Petal Storm throws pink petals.
- Renamed "Shade Bolt" to **Shade Moth** and "Storm Crown" to **Thunderstorm**, so the names
  describe what you see.
- Big projectiles (fireballs, meteors) no longer swell large enough to fill the screen at
  launch.

## 0.44.0 — Magic feel fixes (2026-11-04)

- **Water looks like water.**
  - The core is a sloshing, see-through drop with a bright reflective rim, rippling caustics
    and hard sky glints.
  - Water projectiles trail real droplets, and impacts throw droplets that arc and fall.
  - The crescent ribbons are gone, and water glows much less.
- **Aim while charging.** Hold the cast button and drag the same finger (or move the mouse)
  to aim. The reticle and a "drag to aim" hint show while charging.
- **Arm up while charging.** Mr. Justice raises his casting arm, palm out, with the ball of
  the element growing in it.
- **Instant charged release.** Charged spells fire from the hand (or lantern) the moment you
  let go, with no book flourish in between.
- **Crowns sit properly.** Orbiting spells (Frozen Orbit, Petal Storm, Cyclone Blades, Blade
  Wheel, Second Hands, Rift Pearls, Riptide Discs) now form a level crown circling just above
  Mr. Justice's head. The crown follows him, has no streaks between pieces, and fires from it.
- **Teleports go where you face.** Zephyr Dash, Shadow Step and Blink move Mr. Justice the way
  he is facing. A ribbon of the spell's energy streams out of his back, from where he left to
  where he lands, and pulls back into him as it fades.

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
