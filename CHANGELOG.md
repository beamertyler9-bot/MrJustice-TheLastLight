# Changelog

## 0.77.0 — Enemies as one consistent character (2026-11-11)

- **37 enemies rebuilt as single, continuous creatures.** They used to be separate
  shapes (body, head, brows, muzzle, plates) pushed into each other, with hard creases
  where they met and parts tinted differently. Now every set of parts that moves together
  is one smooth skin:
  - The parts are filled in as one solid and gently blended, so they flow into each
    other (necks into heads, shoulders into bodies, muzzles into faces).
  - Each part's colour carries over and blends softly at the joins.
  - One shared material (the creature's own texture and finish) covers the whole body.
  - Eyes, teeth, claws, horns, spikes, bars and glowing cores stay crisp, exactly as
    before. So do thin details too fine to blend.
  - Joints, animations, attacks and weak points are unchanged.
- **Rebuilt:**
  - **Originals:** wild boar, moss guardian, rootling sentinel, frost brute.
  - **Bosses:** the mine boss, stonejaw wyrm, grand confectioner, stormhorn matriarch,
    glass anubid, pale watcher and blackthorn regent.
  - **Regional enemies:** the other 26.
- **Kept as built (on purpose):**
  - **Crisp, faceted designs:** cliffwarden, shard sentinel, geode mimic, wrapper mimic,
    glass skitter. Blending them made them lumpy.
  - **Signature thin details that blending would lose:** the thorn wolf's thorny vines,
    the cinder wisp's mask, the root reaper's ribcage.
  - **Machines and bandits:** the dissonant machines, the dungeon boss and the scrappers.
- **Performance:** each rebuilt part is simplified to a budget set by its size. The
  biggest models got lighter (mine boss 13.7k to 8.1k triangles, frost brute 19k to
  14.5k); smaller ones gained a little (thistle jackal 4.4k to 5.9k). Draw calls are
  the same or fewer (one skin plus one detail piece per part).
- The rebuild tool is in tools/creature_remesh.gd.

## 0.76.1 — Holding fish by the tail (2026-11-11)

- **Mr. Justice holds a fish by the base of its tail**, in his fist, with the fish
  hanging head-down, at a size you can actually see.
- **Fix:** in 0.76 a fish held in the hand didn't show. Each fish is now one piece with
  one material, like every other prop.

## 0.76.0 — Better fish and creatures (2026-11-11)

- **All 10 fish rebuilt.** Fish used to be a plain egg shape with a block for a tail and
  a dot for an eye. Now each one has:
  - **A real fish body:** a slim tail end, a rounded belly and a darker back fading
    to a pale belly.
  - **Fins:** a forked tail fan, dorsal, pectoral, pelvic and anal fins, and bright
    eyes with a highlight.
  - **Its own shape and markings:**
    - Lake bass: dark side stripe.
    - Silver trout: pink band and spots.
    - Reed perch: dark bars and orange fins.
    - Golden carp and sunscale bream: deep golden bodies with scale shading (the bream is
      tall and flat).
    - Moon eel: a long body with moon spots and a fin running round it.
    - Crystal koi: white with violet and dark patches.
    - Cola carp: brown with fizz flecks.
    - Fizzfin: orange with a big sail fin.
    - Frost char: pale spots and orange fins.
  - Each fish is one mesh coloured per vertex: two draws, the same cost as before.
    They're used in your hand, on the line, in the catch display and on the new
    satchel icons.
- **Weakest enemies reworked:**
  - **Cola sloshback:** a glossy amber bubble throat, fizz bubbles across its back and
    dark spots.
  - **Dune maw:** the two flat boxes on its head are replaced by a round sandworm mouth
    ringed with twelve teeth, and rough sand plates run down its body.
  - **Stonejaw wyrm** (the Mosswake boss): rocky plates with moss along its back and
    stone brow ridges.
  - **Resonance wyrm:** glowing crystal shards along its back.
  - **Wrapper mimic:** now looks like a wrapped sweet, with a foil body, white stripes,
    and twisted, pleated pink wrapper ends.
  - **Fudge golem:** chocolate drips running off its shoulders and head, sprinkles, and
    a cherry on top.
- **Cinderfin fish** (the wildlife in Ashfall waters): glowing ember scales down each
  side and a flame-tipped sail fin, merged into one extra piece.
- **Performance:** the updated models are saved ready-made, so nothing is built while
  you play. The wyrms gain about 7 draws each (their segments move separately). The
  other models are the same or one more.

## 0.75.1 — No more land strips through lakes (2026-11-11)

- **Rivers no longer run through lakes.** Where a river reached a lake, it kept going
  straight across: its water ran on top of the lake, and the ground along its banks
  stood up out of the water as a long strip of land. Rivers now stop where they meet a
  lake and start again where they leave it.
- **The strips of land are gone.** The ground along those old riverbanks is lowered
  below the water, easing down from the shore. That's 6,918 height points in all,
  mostly in the cola lake south of Fizzpeak (where a raised channel crossed the whole
  lake) and the foothill lake at Fizzpeak. A few small bumps in two water lakes went too.
  Real islands, shores and built platforms in other lakes are untouched.
- The foam where Fizzpeak's river runs into the foothill lake now sits at the shore,
  where the river actually meets the lake.

## 0.75.0 — Fizzpeak's cola falls (2026-11-11)

- **Real waterfalls on Fizzpeak.** The cola river used to run down the mountain as a
  flat ribbon stuck to the rock. Its three steepest drops (about 100 m, 70 m and 55 m)
  are now waterfalls:
  - A curtain of falling cola pours over the lip and arcs clear of the cliff, with
    streaks pouring down it, foam at the top and bottom, and ragged see-through edges.
  - Where it lands, foam rings spread across the water and spray drifts up.
  - The curtains can be seen from far across S'morewood (up to 1.4 km), so Fizzpeak
    reads as a landmark.
- **The river gathers into the big cola lake at the foot.** Where the river runs into
  the foothill lake it churns and foams, and six fizz springs bubble up across the
  lake, with bubbles rising and popping over spreading foam rings.
- **Performance:** each waterfall is one mesh. The spray, foam and bubbles are simple
  see-through quads animated entirely on the GPU (no scripts run per frame). They're
  only drawn within 320 m, and none of it casts shadows.

## 0.74.0 — Menus, UI and HUD (2026-11-11)

- **A cleaner HUD.** While exploring you now see only your health, the current goal and
  the hotbar (plus the stick and A/B buttons on a phone). Everything else waits until
  it's needed:
  - **Combat buttons** (dodge, lock-on, aim, equip book) and the **crosshair** appear
    when an enemy is within about 28 m, when you're hurt, aiming or locked on, or during
    a boss fight. They stay up for 6 seconds after the danger passes.
  - **Mana bar and spell slots** only show with your grimoire out (or while a spell is
    active).
  - **Light Essence** shows for a few seconds when it changes, and on every menu screen.
  - The **item name above the hotbar** shows for 2.5 s after you switch.
  - The **DEV button** is gone from the HUD; Developer tools are still in the pause menu.
  - On desktop, the key hints fade out after your first minute (they're still under
    How to play).
  - The current goal sits on a small dark pill under the compass so it's readable over
    any sky.
  - Turning off **Contextual HUD** in Settings shows everything all the time, as before.
- **Satchel, workshop and shop share one design.** Every screen has the same parts in
  the same places: category tabs along the top, your Light Essence beside Close, the
  main list or grid on the left, an **item card** on the right, and the main action
  under the card.
  - **The item card:** a big picture, the name, what kind of thing it is, how many you
    have, its description, where it comes from and what it's used for. Tap any item
    on any screen to see its card.
  - **Satchel:** full-width, with bigger squares (74 px instead of 56). Category tabs:
    All, Materials, Food, Tools, Gear, Fish, Other and Equipped. Picking a category
    fades everything else without moving your stacks. New **Sort by kind** button. The
    hand-crafting grid moved to the Craft screen, where it already was too.
  - **Workshop:** recipe rows have a bigger picture and say "Ready to make" or "Needs
    materials". The recipe card shows each ingredient's picture with have / need.
  - **Shop:** category tabs to filter the goods, bigger rows with pictures, and the item
    card with a big Buy (or Sell) button. The card says when something is cheap or dear
    here. The Buy / Sell switch, pages and "Back to the conversation" sit along the
    bottom.
  - All buttons and squares are at least 48 px tall, so they're easy to tap on a phone.
- **New items and tools now show in your hand** (fix for 0.73). Holding a 0.73 resource
  or food (mossbloom, sunstone, wheat, fish stew and the rest) used to show an empty
  hand; now you hold a small version of it. The new weapons each have their own colour
  instead of looking exactly like the old ones: steel iron axe and pickaxe, dark
  obsidian blade, gold sunsteel sword, glowing violet prism saber.
- **Performance:** the danger check runs four times a second, not every frame. Hidden
  HUD parts aren't drawn at all. The weapon colour is one extra layer on the blade only.

## 0.73.1 — Smooth with a weapon in hand (2026-11-11)

- **Fixed the lag while holding a weapon or tool.** With a sword, axe or pickaxe out,
  the hero's fingers were being hidden and shown again every frame to swap in the
  gripping hand. That cost about 8 ms a frame on a desktop, several times more on a
  phone. The hand now settles on one grip per frame and only changes when the grip
  really changes. Hero animation with a weapon out went from about 9 ms to about 1.4 ms
  a frame (bare hands: about 1.2 ms). The grips look the same.
- The 0.73 weapons (iron axe and pickaxe, obsidian blade, sunsteel sword, prism saber)
  no longer cancel a grimoire cast every frame.

## 0.73.0 — More items and equipment (2026-11-11)

- **Every region has two resources of its own**, growing in patches beside its roads
  (14 patches each, 196 in all). Walk up and press interact to gather 1–2; a gathered
  patch grows back after about 10 minutes of play. They are also sold by the merchants
  who deal in them, cheapest in their home region.
  - **Mosswake Valley:** mossbloom, oak resin.
  - **S'morewood:** cocoa pods, sugar crystals.
  - **Windbell Plains:** wheat sheaves, wind feathers.
  - **Sunspire Dunes:** sunstone, cactus fruit.
  - **Ashfall Caldera:** obsidian, ember ore.
  - **Hollowmourn:** ghost lilies, grave silver.
  - **Prismere:** prism shards, glow moss.
- **Weapons and tools in clear tiers** (makeshift → stone → iron → regional):
  - **Iron axe:** more wood from every tree. **Iron pickaxe:** breaks rock in fewer
    swings. Both hit harder than the stone ones.
  - **Obsidian blade** (Ashfall), **Sunsteel sword** (Sunspire) and **Prism saber**
    (Prismere, the strongest forged blade), each with more reach.
- **Seven new pieces of gear** to fit alongside your others:
  - **Iron buckler** +1 heart, **Ember mail** +2 hearts.
  - **Grave cloak** +1 heart and +15 mana, **Prism ring** +1 heart and +15 mana.
  - **Sunstone amulet** +25 mana.
  - **Wind charm** +8% run speed, **Lantern charm** +5% speed and +10 mana.
- **Five new things to eat**, cooked at a camp:
  - **Hot cocoa** (cocoa pod + sugar crystal): 90 s of Cocoa Rush.
  - **Fish stew** (fish + herb + wheat): +4 hearts and Campfire Warmth.
  - **Cactus water** (2 cactus fruit): +2 hearts and Graham Grit.
  - **Sugar drops** (2 sugar crystals): +1 heart and a short Cocoa Rush.
  - **Mossbloom tonic** (mossbloom + herb + glow moss): +4 hearts and warmth.
- **Every item says where it comes from and what it's for.** The satchel shows a
  "From" line (gathered where, caught where, crafted where, which merchants sell it) and
  a "Used for" line (what it makes, what eating it does, whether it's gear, and which
  merchants buy it). Every item now has at least one use.
- **New icons** for all 31 new items, and item pictures now fill their slots instead of
  sitting small in the middle (fish, food and keepsakes too).
- **Merchants** stock the new goods: the blacksmith sells the new weapons and armor and
  buys ores; the alchemist deals in herbs and flowers; the grocer in cocoa, sugar and
  wheat; the curio dealer in charms, amulets, rings, sunstone and prism shards.
- **Performance:** resource patches are small, cast no shadows and are only drawn within
  70 m. Regrowth is checked every 2 seconds, not every frame.

## 0.72.0 — Specialist merchants (2026-11-11)

- **Merchants specialise now** instead of all selling the same things. Each town has a
  mix of:
  - **General store:** timber, planks, stone, sticks, string, crafting tables, camp
    kits, coffee beans, herbs.
  - **Blacksmith:** weapons, armor and tools (makeshift and stone axes, stone pickaxe,
    iron blade, plated chest, heart coil, spring boots, grapple spool) and iron.
  - **Alchemist:** tonics, mana potions, herbs, crystal, coffee.
  - **Grocer:** marshmallows, chocolate, graham crackers, roasted marshmallows, s'mores,
    coffee.
  - **Angler:** fishing rods and line; pays the best price for every fish.
  - **Curio dealer:** crystal, old relics, ancient cores.
  - **Caravan traders** on the roads carry a bit of everything and buy fish.
- **They buy what they deal in:** the Sell tab only lists what that merchant will buy.
  Specialists (angler, curio dealer, alchemist, blacksmith) pay 25% more for their own
  trade's goods.
- **Prices depend on the region:** what a land makes is 25% cheaper there, and what it
  lacks costs 30% more (and sells for 30% more). Sweets are cheap in S'morewood, iron
  and armor in Ashfall Caldera, crystal in Prismere, timber and tonics in Mosswake.
  The shop screen tells you what's cheap and dear where you are.
- **Gear can be bought:** weapons, tools and armor upgrades from a blacksmith, not just
  crafted. Things you already own show as Owned.
- **Shop screen:** shows the merchant's trade as its title, and each specialist tells you
  what they deal in when you talk to them.

## 0.71.0 — Camp treats (2026-11-11)

- **Marshmallows, chocolate bars and graham crackers can be eaten**, each with its own
  boost:
  - **Chocolate bar:** +1 heart and **Cocoa Rush**, +15% run speed for 45 s.
  - **Graham cracker:** +1 heart and **Graham Grit**: the next hit within 90 s does 1
    less damage.
  - **Marshmallow:** +1 heart and a little **Campfire Warmth** (a heart back every 8 s).
  - **Roasted marshmallow:** +2 hearts and 24 s of Campfire Warmth.
- **S'mores are the best:** toast all three at a lit campfire for +3 hearts and all
  three boosts at once (40 s of warmth, 60 s of Cocoa Rush, and Graham Grit).
- **Eating:**
  - **Full health:** treats with a boost can be eaten even when your hearts are full.
  - **The effect:** the treat lifts up into the lantern, the flame swallows it with a
    flare and sparks, and a line says what it did.
  - **Boosts on screen:** active boosts show as small chips under the compass with
    their time left, and blink when nearly over.
  - **How to eat:** tap the treat on the hotbar, or use "Eat one" in the satchel.
  - **Descriptions:** every treat's description now says what it does.
- **Keepsake fix:** the S'morewood and Ashfall Caldera keepsakes gave stamina, which
  nothing uses. They now give +8% run speed and +1 heart.

## 0.70.0 — The Last Light: story, goals and lore (2026-11-11)

- **A main story in nine chapters.** The Dawnbell of Bellcrown once rang every morning
  and carried the light over all seven lands. The Blackthorn Regent cracked it and its
  seven chimes scattered. Mr. Justice carries the last spark struck from the bell before
  it fell silent: the Last Light.
  - **The chapters:** go to Bellcrown, then win back each region's chime from the thing
    that holds it: the Stonejaw Wyrm, the Grand Confectioner (after climbing Fizzpeak),
    the Stormhorn Matriarch, the Glass Anubid, the Furnace Cathedral, the Aurora
    Custodian and the Pale Watcher. The last chapter is the Blackthorn Regent at the top
    of Blackthorn Keep.
  - **Story cards:** each chapter opens with a card telling you why and where, and
    closes with a card telling what happened and what you earned.
  - **Rewards:** every chapter pays out Light Essence plus supplies (tonics, iron,
    crystal, ancient cores, s'more makings).
  - **Out of order is fine:** bosses beaten early still count.
- **Always know where to go:**
  - **Tracked automatically:** the current chapter is tracked from the start, on the
    HUD card, the compass marker with its distance, and a gold star on the world map.
  - **Compass line:** with nothing tracked, the compass line shows the next goal instead
    of "explore freely".
- **Lore by the roads:** 21 pieces to find (an old journal on a lectern, a carved stone
  and a pinned note in each of the seven regions), each marked by a small floating light.
  - **Reading:** each one opens a page to read and gives Light Essence.
  - **Finding them:** unread pieces appear in Places, so they can be tracked, and as
    gold rings on the world map.
- **A reason to go everywhere:** each region's three pieces tell of a local trouble
  (backwards windmills, ovens that never cool, a blue fire, the dead who won't sleep…).
  Find all three and that trouble is solved, earning the region's keepsake: a lasting
  bonus to hearts, stamina or mana you can't get anywhere else.
- **Journal:** new **Story** and **Lore** pages (chapters so far with the chimes
  recovered; every region's lore and keepsake). The tabs are now Story, Lore, Places,
  Quests, Goals and Map.

## 0.69.0 — Lighter on the phone (2026-11-11)

These changes came from measuring what a town actually draws:
- **Room lights:** a room's lights now switch off when the room can't be seen. They used
  to stay lit (and keep lighting the street) while you were outside. Shops also had two
  lights where one was enough. In a busy town view, 34 active lights became 11.
- **Fewer shadows:** small things (pebbles, sticks, cups, little props, fingers) no longer
  cast shadows. Each was an extra draw in the shadow pass for a shadow too small to see.
  Small shadow casters in view went from 156 to 24, and all shadow casters in view from
  215 to 162.
- **Draws:** 672 draws in that view became 640.
- **Less memory churn:** a per-frame list in streamed ground chunks is now only made when
  something needs it, instead of on every frame for every chunk.

## 0.68.0 — Occlusion culling (2026-11-11)

- **Occlusion culling is on:** anything completely hidden behind something solid is no
  longer drawn (or shadowed). Hidden shapes, kept just inside the real surfaces so
  nothing visible is ever cut, mark what blocks the view:
  - **Hills and ridges:** a coarse sheet under every ground chunk, so the trees, houses
    and creatures behind a hill are skipped.
  - **Houses:** their walls (doorway left open). A street of houses hides what's behind
    it, and from inside a house the outside world isn't drawn at all.
  - **Blackthorn Keep:** every solid stretch of wall, so the rooms you can't see from
    where you stand are skipped.
- **The result:** about 5–20% fewer objects drawn in towns and hilly country in testing,
  and far more inside the keep, with no visible difference on screen.
- **Built on 0.67.1:** fishing and the better fish are carried over.

## 0.62.1 — Smoother running (2026-11-05)

- **Butterflies and fireflies removed.**
- **Rivers, lakes and the cola draw in a single pass.** They work out their own sunlight,
  glints and night-time darkening instead of being redrawn once for every lamp nearby,
  so being near water with the lantern lit costs much less. They look the same.
- **Cheaper wind:** the sway on trees and plants is a few simple waves per vertex, with
  no matrix work, since it runs on every plant on screen.
- **No first-time stutters:**
  - **Warmed up while loading:** the swaying-plant materials, the water and the
    damage-number text are prepared behind the loading screen, so the first walk into a
    meadow, the first river and the first hit no longer hitch.
  - **Defeat flash:** it no longer adds a temporary light; the sparks and dust remain.

## 0.62.0 — Full polish pass (2026-11-05)

### Combat
- **Every hit reads clearly**, whether from fists, weapons, spells or beams:
  - **Flash:** the enemy's whole body flashes white for an instant.
  - **Squash:** it squashes from the blow.
  - **Damage numbers:** numbers pop up over its head and drift away. Big hits show in
    orange, and rapid hits (beams, burning) add up into one number instead of a pile.
  - **Sound:** the impact sound varies a little from hit to hit.
- **Enemies feel alive:**
  - **Spotting you:** an enemy that first spots Mr. Justice flashes a "!" over its head
    and hops before closing in. A hit always gets its attention.
  - **At ease:** instead of standing frozen, enemies amble about their patch, pausing to
    look around.
- **A cue to dodge:** just before an enemy's blow lands, it glints hot orange.
- **Defeats pop:** a bright flash of light, a burst of sparks and a puff of dust. Bosses
  also get a short slow-motion beat as they fall.

### Movement
- **Jumps feel weightier:**
  - **Arc:** a light hang at the top of a jump, then a quicker fall than the rise
    instead of drifting down. A jump goes about as high as before.
  - **Fall damage:** drops that used to be safe are still safe.
- **Snappier turnarounds:** reversing direction at a run digs in hard, with a skid sound
  and a puff of dust.
- **Banking:** Mr. Justice leans into his turns when running.
- **Splashdown:** dropping into a river or lake throws up a splash and spray sized to
  the fall, with a little jolt.

### The world
- **Wind:** trees, bushes, grass, ferns and flowers sway, rock and flutter in slow gusts.
  - **Out of step:** each plant moves a little differently from its neighbours.
  - **Roots stay put:** only the tops move.
  - **Size:** small plants move more than tall trees.
  - **What stays still:** rocks, pebbles, stumps, mushrooms, cacti and crystals.
- **Butterflies by day:** they flit about at knee to head height around Mr. Justice, wings
  beating, in colours that suit each land:
  - golden and white in the valley;
  - pink in the sweets lands;
  - pale blue and violet among the crystals.
- **Fireflies by night:** after dark they give way to fireflies that drift slowly and
  blink.
  - **When they appear:** only out in the open, never indoors, sheltering or in heavy
    rain.
  - **Performance:** all of them together cost a single draw call.
- **Softer entrance rings:** the rings marking doors and entrances are a gentler mint
  glow instead of a hard neon green.

### HUD
- **Messages:** they slide up and fade in, then fade out, instead of popping on and off.
- **Light Essence counter:** collecting essence makes the counter bump and flash gold,
  with a "+N" that floats up beside it. Several quick pickups add up into one number.
- **Interaction prompts:** "Open", "Talk", "Pick up" and the rest pop in with a little
  spring when you walk up to something.
- **Last lantern:** when Mr. Justice is down to his last lantern, the edges of the
  screen glow red with a slow heartbeat. It is softer with Low flash on, and steady with
  UI motion off.

## 0.61.0 — Blackthorn Keep rebuilt, water that looks like water (2026-11-05)

- **Blackthorn Keep has a real floor plan** on all seven floors:
  - **Rooms:** six walled rooms per floor, each entered through an arched stone doorway
    from a long central landing lit by wall torches.
  - **Stair tower:** the landing opens through a grand doorway into the tower.
- **The keep's stairs are real stone flights:**
  - Solid steps with a thick stone underside.
  - Parapet walls on both sides, and lantern-topped posts at the top and bottom.
  - They switch back floor to floor.
  - A balustrade runs round the stair well on every upper floor.
  - The bottom of the well is floored.
- **Every room is furnished for its purpose**, with stone vaulting, Gothic windows, a
  pillared arcade and its own warm light:
  - **Great hall:** long feasting tables and a hearth.
  - **Bedrooms:** beds, wardrobes, chests and paintings.
  - **Kitchens:** ovens, barrels, crates and shelves.
  - **Prison:** barred cells.
  - **Crypt:** tombs.
  - **Library and study:** bookcases, map and council tables, a telescope.
  - **Other rooms:** the chapel, gallery, armory, vault, throne room and belfry are all
    furnished too.
  - **The castle's mood:** warm torchlit stone instead of a dark void.
- **Rivers, streams, lakes and the cola look like liquid:**
  - **Movement:** ripples run downstream on rivers and drift slowly on lakes.
  - **Light:** the sun glints off the water and the sky reflects at low angles.
  - **Depth:** the water is see-through and pale in the shallows by the bank, and deep
    and dark in the middle. A broken foam line marks the shore, and steep stretches run
    white.
  - **The cola:** dark and glossy, amber in the shallows, with fizz.
- **Water sits in its bed instead of floating:**
  - **Rivers:** wherever a bank was lower than the river, the surface now settles down
    to the bank, smoothly along the river and still deep enough to swim, or reaches out
    to the ground. No more slabs of water hanging in the air with their sides showing.
  - **Lakes:** shores spread out to meet the ground.
  - **Prismere:** where the town sits below the lake, a stone quay wall holds the water.

## 0.60.0 — Archways set into the walls (2026-11-05)

- **Dungeon archways line up with the ceiling:** every doorway arch now sits in a solid
  masonry wall that fills the corridor from side to side and from the floor up to the
  vaulted ceiling.
  - The opening is shaped to the arch, with a stone reveal through the wall's thickness.
  - The bricks run continuously from the walls into it, so arches no longer stand on
    their own with open gaps above and beside them.
  - The way through is just as wide as before.

## 0.59.0 — Caves, dungeons, homes and land (2026-11-05)

- **Caves** (all 52):
  - **Shape:** lumpy, faceted ceilings and walls that bulge in and out instead of flat
    panels.
  - **Formations:** stalactites hang everywhere the roof is high enough (always above head
    height). Stalagmite clusters and boulders crowd the foot of the walls.
  - **Rock:** layered strata, fine cracks, darker ceilings, and moss, sand or ash
    gathering on the ground.
  - **Each region grows its own features:**
    - Glowing teal mushrooms in the valley.
    - Candy crystals and chocolate drips in the sweets lands.
    - Mushrooms and blue crystals in the plains.
    - Sand drifts and old skulls in the desert.
    - Glowing lava cracks and lava pools in volcanic caves.
    - Ghost-blue mushrooms, drifting wisps and skulls in haunted caves.
    - Big glowing crystal clusters in the crystal caves.
  - **Lighting:** caves now sink into darkness tinted by their region, with a little haze.
    Glowing features cast coloured light, so Mr. Justice's lantern really matters.
  - The old flat mushroom discs, sticks and pale puddles are gone.
- **Dungeons** (all 40 outside Blackthorn Keep): every room is dressed for its purpose
  instead of with bedroom furniture.
  - **Room themes:**
    - Entry halls: runner carpets, banners and braziers.
    - Libraries: wall shelves, a reading table and candles.
    - Armories: sword-and-shield racks, keys, barrels and crates.
    - Tombs: an altar between candles, stone sarcophagi and urns.
    - Stores: stacked barrels and boxes and a laden table.
    - Boss sanctums: a ring of stone pillars, braziers and red banners.
    - Vaults: gold chests and coin piles.
  - Big rooms get carved stone pillars, and rubble lies about.
  - **Torches:** wall torches line the walls and corridors with real flickering
    torchlight.
  - **Walls:** masonry blocks vary in shade, with damp and mossy patches. The air is
    warmer and dimmer.
  - Doorways and the way out are always kept clear.
- **Homes:**
  - **Hearth:** every home has a stone hearth opposite the door, with a mantel, chimney
    breast, logs, a woodpile, a candle and a jug, a patterned rug, and a fire that throws
    flickering warm light.
  - **Decoration:** paintings on the walls, a bottle shelf over the table, potted plants,
    and warmer room light.
  - **Shops:** pictures, plants by the door and warm light too.
- **Terrain:**
  - **Meadows:** broad lush and sun-dried patches across the land, so the ground no
    longer reads as one repeated tile.
  - **Wildflowers:** tiny white, pink and violet blossom clusters up close (blue in the
    crystal lands), never on paths.
  - **Cliffs and rock:** warm grey stone with mottling, ledges, rain streaks and moss on
    the tops, instead of one flat dark tone.
- New cave and dungeon shaders are warmed up behind the loading screen.

## 0.58.0 — Judgement Pillar unleashed (2026-11-05)

- **Judgement Pillar is now one of the strongest spells in the game:**
  - Full power plus a damage bonus: it burns for 7 per pulse (was 2), 10 pulses over about
    8 seconds.
  - **Chargeable** (2.2 seconds): hold to widen the pillar by up to half again and hit
    harder. A full charge burns for 9 per pulse, up to 90 damage to anything that stays
    inside.
  - **Only one at a time:** you can't cast or charge another while one is still standing.
  - **Lightning:** forks of lightning in the pillar's own gold strike down around it the
    whole time it stands, and arcs jump across its face.
  - It costs 78 mana.
- Spells already at full power now turn extra charge into extra damage instead of wasting
  it.

## 0.57.0 — Casting arm holds (2026-11-05)

- **Casting arm stays up longer:** after a spell leaves his hand, Mr. Justice holds his
  arm out toward it for a moment before lowering it.
  - Quick casts hold for about half a second at the end of the grimoire gesture.
  - Charged hand spells hold about 0.6 seconds after you let go.
  - Beams still keep the arm up for as long as they fire.
  - Lantern spells still leave the hands alone.

## 0.56.0 — Braced beams, snappy casting circles (2026-11-05)

- **Casting circles fade right after the cast:** the circle at the hand (or lantern) and at
  the feet flashes open and fades straight away for most spells, quick-cast or charged.
  - Spells that keep pouring out of the hand keep theirs open while they last. Those are
    beams (Thunder Lance, Lantern Beam, Torrent Beam, Null Lance, Chrono Lance, Railgun)
    and breath cones.
  - Ground circles under instant blasts fade straight away. Fields and traps keep theirs
    for as long as they last, and rain keeps its sky circle while it pours.
- **Firing a beam:**
  - You can't look around while a beam is firing; the camera holds still.
  - Mr. Justice is locked facing the beam, and the beam keeps the direction it was fired
    in (it still comes out of his hand or lantern as he moves).
  - He is slowed to a braced shuffle, about a third of walking speed.
- **Shorter beams:** beams last about 1 to 1.6 seconds (the Railgun 2 seconds) instead of
  up to 3.

## 0.55.0 — Beams follow Mr. Justice (2026-11-05)

- **Beams follow Mr. Justice:** a beam keeps coming out of his hand (or lantern) for as long
  as it lasts.
  - Walk and it moves with you. Turn or move your aim and it sweeps after it. With lock-on,
    it stays on the locked target.
  - Whatever the beam sweeps across gets burned, and his raised arm keeps pointing down the
    beam.
  - Storm lightning along Thunder Lance and the Railgun moves with the beam too.

## 0.54.0 — Circles follow Mr. Justice (2026-11-05)

- **Magic circles follow Mr. Justice:**
  - The circle in front of his hand (or lantern) moves with him and turns with his aim for
    as long as the spell is active. That includes the circle a charged spell grew while
    charging.
  - Circles at his feet (wards, heals, teleports, summons) move with him too.
  - Circles that mark where a spell landed (on the ground under an area spell, in the sky
    over rain) stay at the spell.

## 0.53.0 — Circles last as long as the spell (2026-11-05)

- **Magic circles last as long as the spell:** every circle stays fully open for as long as
  its spell is still doing something, then fades. Something counts as long as:
  - projectiles are still in flight,
  - a field is still pulsing,
  - a trap, wall or summoned guardian is still standing,
  - a ward is still up,
  - a breath or beam is still pouring.
  This applies to quick casts and charged spells, at the hand, at your feet, on the ground
  and in the sky.
- **Beam circles:** the circle a beam fires from stays open for the whole beam. That covers
  the charging circle of charged beams and the lantern's circle for Lantern Beam.
- **Lantern Beam:** fixed Mr. Justice raising his hand at the end of the cast. The brief
  "beam firing" pose no longer plays for lantern spells, and his hands stay still for the
  whole beam.

## 0.52.0 — Longer-lasting spells (2026-11-05)

- **Spells last longer:** every built-in spell with a lasting effect runs about 60% longer.
  - Fields and pillars keep pulsing for the extra time, and so do traps, walls, summoned
    guardians, slows, freezes, stasis and shields.
  - Wards last 60% longer.
  - Rain spells pour over a longer stretch.
  - Orbiting spells hover around you longer before they fly.
- **Spells cast for longer:**
  - Beams pour for about 3 seconds instead of a quick flash, and keep burning whatever stands
    in them every 0.4 seconds, with a slightly lighter hit than the first. Mr. Justice's
    arm stays raised the whole time.
  - Breath and gust cones (Frost Breath, Gust, Tide Splash and the rest) keep blowing for
    over a second and keep hitting while they do.
- **Effects linger:**
  - Blasts, strikes, cones, heals and lightning bolts stay on screen longer.
  - Magic circles do too, at the hand, at your feet, on the ground and in the sky.
- The Railgun beam lasts 2.6 seconds.
- Teleports and Levitation keep their old timing.
- Because they do more now, the longest-lasting spells cost a little more mana. For
  example, Judgement Pillar costs 50 (was 36) and Earthquake 49 (was 37).

## 0.51.0 — Longer Railgun charge, flat rain circles (2026-11-05)

- **Railgun:** takes 3.5 seconds to charge fully, up from 2, so the metal circle array
  builds up slowly before the shot.
- **Rain spells:** the magic circle in the sky now lies flat and level over the target
  instead of tipping toward you, and hangs a little lower so it stays in view.
- Magic circles use anisotropic filtering, so their thin lines stay sharp when seen at a
  low angle (circles overhead or on the ground).

## 0.50.0 — Railgun array, held beams and sky circles (2026-11-05)

- **Railgun, the most powerful spell in the game:**
  - Charging opens a large **metal** magic circle in front of the hand as the base. Smaller
    **storm**, **flame** and **light** circles rise out of it and orbit its rim faster and
    faster, with lightning arcing between them.
  - Past half charge, a barrel of metal accelerator rings lines up down the aim. At full
    charge the whole array throbs and crackles.
  - On release, the barrel rings are flung down the beam like shockwaves and the base flares
    and spins out. Two layers of lightning wrap the beam.
  - Where the shot lands, a second metal circle blooms with storm, flame and light circles
    bursting outward, plus a flash of light, a firestorm and a lightning strike from the sky.
  - The camera kicks, the controller rumbles and the game freezes for an instant on the shot.
- **Beams:** Mr. Justice keeps his arm raised toward the target for as long as a beam lasts,
  not just at the moment it fires.
- **Lantern Beam:** his hands no longer move at all. It comes from the lantern, so his arms
  stay exactly where they are while charging and firing.
- **Rain spells** (Meteor Fall, Landslide, Seed Barrage, Needle Rain, Hourglass Rain) now pour
  out of a magic circle hanging in the sky over the target, tipped toward you so it reads
  face-on. The drops fall from the circle.
- **Cloud spells** (Thunderstorm, Blizzard) hang their circle just under the cloud.
- **Fix:** ground circles under area spells aimed at an enemy now sit on the ground instead
  of on top of the enemy.

## 0.49.0 — Solid beams end-on (2026-11-05)

- **Beams:** you could see through the middle of a beam when looking down it from behind
  Mr. Justice (it showed as hollow rings). Beams now have a solid, white-hot heart when seen
  end-on, so Lantern Beam, Thunder Lance and the rest read as a full column of light from
  every angle. Void beams keep their black heart, and water beams (Torrent Beam, Geyser) get
  a solid inner column under the flowing water.

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
