extends RefCounted


const Book = preload("res://scripts/spellbook.gd")
const ROLES := ["offense", "control", "protection", "support", "mobility", "construct", "companion"]
static var _spells: Array = []
static var _notes: Dictionary = {}

static func starting_slots() -> Array:
	return ["basic_fireball", "basic_lightning_bolt", "basic_rock_throw", "basic_levitation"]

static func all_spells() -> Array:
	_ensure_catalog()
	return _spells.duplicate(true)

static func spell_by_id(id: String) -> Dictionary:
	_ensure_catalog()
	for spell in _spells:
		if spell.id == id: return spell.duplicate(true)
	return {}

static func metadata(id: String) -> Dictionary:
	_ensure_catalog()
	return _notes.get(id, {}).duplicate(true)

static func is_curated(id: String) -> bool:
	_ensure_catalog()
	return _notes.has(id)

static func entries(legacy: Array = []) -> Array:
	var result: Array = []
	var old_ids := {}
	for spell in legacy:
		if spell is Dictionary: old_ids[str(spell.get("id", ""))] = true
	for spell in all_spells():
		if not old_ids.has(spell.id): result.append(spell)
	for spell in legacy:
		if spell is Dictionary: result.append(spell.duplicate(true))
	return result

static func role(spell: Dictionary) -> String:
	var note := metadata(str(spell.get("id", "")))
	if not note.is_empty(): return str(note.role)
	match str(spell.get("form", "")):
		"ward": return "protection"
		"mend": return "support"
		"step": return "mobility"
		"wall": return "construct"
		"summon": return "companion"
	return "offense" if _damaging_stages(spell).size() > 0 else "control"

static func damage_summary(spell: Dictionary) -> String:
	var stages := _damaging_stages(spell)
	if stages.is_empty(): return "No direct damage · " + role(spell).capitalize()
	var low := 99; var high := 0
	for stage in stages:
		var damage := Book.damage(stage)
		low = mini(low, damage); high = maxi(high, damage)
	var amount := str(low) if low == high else "%d–%d" % [low, high]
	return "%s damage per contact%s" % [amount, " · staged follow-up" if stages.size() > 1 else ""]

static func _damaging_stages(spell: Dictionary) -> Array:
	var result: Array = []
	for stage in Book.stage_list(spell):
		if stage.form in ["ward", "mend", "step", "wall"] or stage.targeting not in ["enemies", "both"]: continue
		if "elemental" in [stage.effect, stage.secondary_effect, stage.tertiary_effect]: result.append(stage)
	return result

static func _complete(raw: Dictionary, family: String) -> Dictionary:
	var full := Book.defaults(str(raw.id))
	full.element = family
	full.range = 18.0
	full.duration = 3.0
	full.merge(raw, true)
	var palette: Array = Book.ELEMENT_COLORS[full.element]
	for key in ["color", "trail_color"]:
		if not raw.has(key): full[key] = palette[0]
	for key in ["accent", "core_color", "rim_color"]:
		if not raw.has(key): full[key] = palette[1]
	return full

static func _add(recipe: Dictionary, purpose: String, summary: String, tactics: String) -> void:
	var raw: Dictionary = recipe.duplicate(true)
	var children: Array = raw.get("stages", [])
	raw.erase("stages")
	var full := _complete(raw, str(raw.element))
	full.stages = []
	for index in range(children.size()):
		var stage: Dictionary = children[index].duplicate(true)
		stage.id = "%s_s%d" % [raw.id, index + 1]
		if not stage.has("name"): stage.name = raw.name
		var finished := _complete(stage, str(raw.element))
		finished.erase("stages")
		full.stages.append(finished)
	var clean := Book.sanitize(full)
	if clean.is_empty():
		push_error("Invalid fixed spell: " + str(raw.id))
		return
	_spells.append(clean)
	_notes[str(raw.id)] = {"role": purpose, "summary": summary, "tactics": tactics}

static func _ensure_catalog() -> void:
	if not _spells.is_empty(): return
	_add({"id": "basic_fireball", "name": "Fireball", "element": "flame", "count": 1, "power": 1, "speed": 16.0, "size": 0.19, "radius": 1.0, "spread": 0.0, "particles": "embers", "material_style": "molten", "trail_length": 0.7, "intensity": 1},
		"offense", "A single bright fireball with a short ember tail.", "A simple aimed projectile. Hit a visible target; solid cover stops it.")
	_add({"id": "basic_lightning_bolt", "name": "Lightning Bolt", "element": "storm", "form": "beam", "projectile": "bolt", "count": 1, "power": 1, "range": 18.0, "size": 0.1, "particles": "sparks", "material_style": "runic", "intensity": 1},
		"offense", "A quick, clean bolt of lightning from the grimoire.", "Strikes the first visible surface along your aim. Wet foes react to storm magic.")
	_add({"id": "basic_rock_throw", "name": "Rock Throw", "element": "earth", "count": 1, "power": 1, "speed": 15.0, "size": 0.26, "radius": 1.0, "spread": 0.0, "trail": "none", "particles": "runes", "glow": 0.18, "intensity": 1},
		"offense", "Launch one solid, rough stone at the target.", "A direct earth projectile with real collision. Aim through a clear path.")
	_add({"id": "basic_levitation", "name": "Levitation", "element": "wind", "form": "beam", "effect": "levitate", "targeting": "objects", "count": 1, "power": 1, "force": 16.0, "duration": 6.0, "range": 12.0, "mass_limit": 12.0, "projectile": "ribbon", "particles": "runes", "material_style": "spectral", "intensity": 1},
		"control", "Lift a nearby movable object or regular creature.", "Aim at an unobstructed carryable within twelve metres. Use the vertical distance slider; tap B to launch or hold B to lower it.")

	_add({"id": "v18_cinder_serpents", "name": "Cinder Serpents", "element": "flame", "projectile": "serpent", "trajectory": "seeking", "count": 2, "power": 2, "speed": 16.0, "spread": 8.0, "homing": 2.5, "material_style": "molten", "particles": "embers", "trail_length": 1.6, "edge_noise": 1.2,
		"stages": [{"form": "burst", "power": 1, "radius": 1.4, "when": "hit", "impact_accent": "bloom", "particles": "embers", "material_style": "molten"}]},
		"offense", "Two molten serpents curl into a compact ember bloom.", "Aim at a visible foe. The first contact blooms once; burning adds two later ticks.")
	_add({"id": "v18_hearth_ring", "name": "Hearth Ring", "element": "flame", "form": "ward", "power": 2, "radius": 1.6, "sigil": "circle", "particles": "embers", "material_style": "runic", "impact_accent": "rings", "glow": 1.4},
		"protection", "A warm ring of runes gathers around the open book.", "Absorbs three damage for 4.6 seconds. Cast before approaching a dangerous foe.")
	_add({"id": "v18_phoenix_rain", "name": "Phoenix Rain", "element": "flame", "form": "rain", "projectile": "comet", "count": 5, "power": 2, "radius": 2.1, "rain_height": 5.0, "stagger": 0.12, "speed": 20.0, "material_style": "molten", "particles": "embers", "trail_width": 1.3, "impact_accent": "bloom"},
		"offense", "Five bright comets fall in a staggered fiery shower.", "Aim at the ground near a group. Falling projectiles collide with cover; every landing is a real contact.")
	_add({"id": "v18_ashen_step", "name": "Ashen Step", "element": "flame", "form": "step", "radius": 3.8, "power": 1, "particles": "embers", "sigil": "fracture", "material_style": "spectral", "impact_accent": "mist", "residual_motes": 1.4,
		"stages": [{"form": "ward", "power": 1, "when": "end", "particles": "embers", "material_style": "runic", "impact_accent": "rings"}]},
		"mobility", "An ember afterimage closes into a small protective seal.", "Steps up to 3.8 metres, stopping at cover. A two-damage ward protects the caster after the step.")

	_add({"id": "v18_ice_needle", "name": "Ice Needle", "element": "frost", "projectile": "shard", "trajectory": "straight", "count": 1, "power": 2, "speed": 28.0, "size": 0.12, "impact": "pierce", "pierces": 2, "material_style": "crystal", "particles": "stars", "trail": "none", "impact_accent": "shards"},
		"offense", "A narrow ice splinter pierces a line of targets.", "Line up enemies before casting. Frost briefly freezes movement and lasts longer against wet foes.")
	_add({"id": "v18_mirrorwake", "name": "Mirrorwake", "element": "frost", "form": "wall", "power": 1, "duration": 4.0, "wall_width": 3.5, "wall_height": 2.3, "wall_thickness": 0.3, "range": 9.0, "material_style": "crystal", "particles": "stars", "sigil": "fracture", "impact_accent": "shards",
		"stages": [{"form": "burst", "power": 1, "radius": 2.0, "when": "end", "material_style": "crystal", "impact_accent": "shards"}]},
		"construct", "A real glasslike wall breaks into a final frost pulse.", "Place in clear space away from bodies. The solid wall lasts four seconds; its expiry releases the frost burst.")
	_add({"id": "v18_hushglass", "name": "Hushglass", "element": "frost", "form": "field", "effect": "stasis", "targeting": "enemies", "duration": 1.5, "radius": 2.5, "power": 1, "material_style": "crystal", "sigil": "fracture", "particles": "stars", "impact_accent": "mist"},
		"control", "A quiet crystal field stills nearby enemies.", "Temporarily suspends enemy time inside a 2.5 metre field. Pure control: it deals no direct damage.")
	_add({"id": "v18_winter_crown", "name": "Winter Crown", "element": "frost", "form": "orbitals", "projectile": "blade", "trajectory": "fan", "count": 4, "power": 1, "hold_time": 0.65, "stagger": 0.09, "orbit_radius": 0.8, "spread": 14.0, "speed": 24.0, "material_style": "crystal", "particles": "stars", "sigil": "star", "impact_accent": "shards"},
		"offense", "Four icy blades form a crown before fanning forward.", "Allow the short orbit to finish. The narrow fan freezes visible targets and cannot pass through solid cover.")

	_add({"id": "v18_thunderline", "name": "Thunderline", "element": "storm", "form": "beam", "projectile": "lance", "power": 2, "range": 25.0, "size": 0.12, "particles": "sparks", "material_style": "runic", "sigil": "fracture", "impact_accent": "sparks",
		"stages": [{"form": "burst", "power": 1, "radius": 1.6, "when": "hit", "particles": "sparks", "impact_accent": "rings"}]},
		"offense", "A sharp lightning line opens into a ringing thunderclap.", "Instantly contacts the first visible surface. Storm damage can arc to another nearby visible enemy.")
	_add({"id": "v18_copper_swarm", "name": "Copper Swarm", "element": "storm", "form": "orbitals", "projectile": "bolt", "trajectory": "seeking", "count": 3, "power": 2, "hold_time": 0.4, "stagger": 0.14, "orbit_radius": 0.6, "homing": 3.0, "speed": 20.0, "spread": 10.0, "particles": "sparks", "material_style": "runic", "trail": "orbit"},
		"offense", "Three charged bolts orbit tightly, then seek a target.", "Release near a visible enemy. Each bolt has its own finite flight and may arc once on contact.")
	_add({"id": "v18_stormhand", "name": "Stormhand", "element": "storm", "form": "touch", "effect": "launch", "targeting": "objects", "force": 23.0, "power": 1, "duration": 1.0, "particles": "sparks", "material_style": "runic", "sigil": "fracture", "impact_accent": "sparks"},
		"control", "A close electric palm launches a movable object upward.", "Stand within two metres of a carryable object. It launches the object without inventing spell damage.")
	_add({"id": "v18_ozone_sentinel", "name": "Ozone Sentinel", "element": "storm", "form": "summon", "summon_kind": "sentinel", "summon_count": 1, "duration": 6.0, "power": 2, "range": 12.0, "particles": "sparks", "material_style": "runic", "sigil": "star", "impact_accent": "sparks"},
		"companion", "A compact storm sentinel patrols beside the aim point.", "Summons one temporary guardian for six seconds. It attacks visible enemies and respects cover.")

	_add({"id": "v18_briar_loom", "name": "Briar Loom", "element": "grove", "form": "field", "power": 1, "radius": 2.6, "duration": 2.0, "trigger": "pulse", "pulses": 3, "interval": 0.7, "particles": "petals", "material_style": "botanical", "sigil": "petals", "impact_accent": "bloom"},
		"offense", "A petal-woven garden pulses three times around its mark.", "Place the garden under a group. Grove contacts can restore one heart per cast, within the shared healing limit.")
	_add({"id": "v18_moss_mercy", "name": "Moss Mercy", "element": "grove", "form": "mend", "power": 3, "radius": 2.2, "particles": "petals", "material_style": "botanical", "sigil": "petals", "impact_accent": "bloom", "particle_drift": 0.4},
		"support", "Soft moss-green petals gather into a restorative bloom.", "Restores two hearts to the caster. It costs mana even when already healthy, so choose the right moment.")
	_add({"id": "v18_acorn_pact", "name": "Acorn Pact", "element": "grove", "form": "summon", "summon_kind": "familiar", "summon_count": 1, "duration": 7.0, "power": 1, "range": 12.0, "particles": "petals", "material_style": "botanical", "sigil": "petals", "impact_accent": "bloom"},
		"companion", "A tiny botanical familiar takes flight near the spell mark.", "The familiar helps against visible foes for seven seconds. Its flight is blocked by solid ceilings.")
	_add({"id": "v18_vine_tether", "name": "Vine Tether", "element": "grove", "projectile": "ribbon", "trajectory": "seeking", "count": 1, "power": 2, "speed": 19.0, "homing": 2.3, "effect": "elemental", "secondary_effect": "pull", "targeting": "both", "force": 12.0, "particles": "petals", "material_style": "botanical", "trail_length": 1.8, "impact_accent": "rings"},
		"control", "A living ribbon seeks a foe and tugs it toward the caster.", "Combines a real grove hit with a gentle pull. It can also tug light carryable objects.")

	_add({"id": "v18_sun_verdict", "name": "Sun Verdict", "element": "light", "form": "beam", "projectile": "lance", "power": 3, "size": 0.14, "range": 28.0, "material_style": "runic", "particles": "runes", "sigil": "star", "impact_accent": "rings",
		"stages": [{"form": "burst", "power": 1, "radius": 1.7, "when": "hit", "material_style": "runic", "sigil": "star", "particles": "runes", "impact_accent": "rings"}]},
		"offense", "A golden line stamps a luminous star at first contact.", "A precise instant cast with one compact follow-up. Light contacts repel foes; walls stop the line.")
	_add({"id": "v18_halo_shelter", "name": "Halo Shelter", "element": "light", "form": "ward", "power": 3, "radius": 1.7, "material_style": "runic", "sigil": "star", "particles": "runes", "impact_accent": "rings", "glow": 1.5},
		"protection", "A bright circular seal wraps the caster in a gold halo.", "Absorbs four damage for 5.4 seconds. This protective seal has no offensive contact.")
	_add({"id": "v18_sunmoth_veil", "name": "Sunmoth Veil", "element": "light", "projectile": "moth", "trajectory": "seeking", "count": 3, "power": 1, "speed": 15.0, "homing": 2.0, "spread": 16.0, "stagger": 0.12, "material_style": "spectral", "particles": "stars", "trail": "none", "impact_accent": "rings"},
		"offense", "Three pale sunmoths flutter outward, then home toward foes.", "Each moth follows its own path. Their light contacts gently repel enemies without bypassing cover.")
	_add({"id": "v18_gentle_lantern", "name": "Gentle Lantern", "element": "light", "form": "field", "effect": "shield", "targeting": "caster", "power": 2, "radius": 2.0, "duration": 3.0, "material_style": "runic", "particles": "runes", "sigil": "circle", "impact_accent": "rings"},
		"protection", "A low ring of light renews the caster's sheltered stance.", "A caster-only shield delivered through a field. Its aim mark does not shield enemies or cause damage.")

	_add({"id": "v18_inkwell", "name": "Inkwell", "element": "shadow", "form": "trap", "power": 2, "radius": 2.3, "duration": 5.0, "material_style": "ink", "particles": "stars", "sigil": "fracture", "impact_accent": "mist"},
		"offense", "An ink-dark seal waits for an enemy to cross its rim.", "The first detected target consumes the trap. Shadow damage delays enemy attacks; the seal expires after five seconds.")
	_add({"id": "v18_umbral_fold", "name": "Umbral Fold", "element": "shadow", "form": "step", "power": 2, "radius": 4.5, "material_style": "ink", "particles": "stars", "sigil": "fracture", "impact_accent": "mist", "trail_fade": 1.7},
		"mobility", "A dark fold leaves a brief ink silhouette behind the caster.", "Steps up to 4.5 metres toward aim while stopping at physical cover. No direct damage.")
	_add({"id": "v18_velvet_moths", "name": "Velvet Moths", "element": "shadow", "projectile": "moth", "trajectory": "wave", "count": 4, "power": 1, "speed": 14.0, "orbit_radius": 0.45, "stagger": 0.13, "material_style": "ink", "particles": "stars", "trail_length": 1.6, "impact_accent": "mist"},
		"offense", "Four velvet silhouettes weave a staggered wave through the air.", "Aim through open space. Their wave paths contact real targets and shadow hits delay enemy attacks.")
	_add({"id": "v18_night_lens", "name": "Night Lens", "element": "shadow", "form": "cone", "effect": "slow", "targeting": "enemies", "duration": 3.0, "slow_factor": 0.35, "power": 1, "range": 7.5, "cone_angle": 42.0, "material_style": "ink", "particles": "stars", "sigil": "circle", "impact_accent": "mist"},
		"control", "A broad dark lens slows enemies in front of the book.", "Targets visible enemies inside a 42 degree cone. It slows local time without dealing direct damage.")

	_add({"id": "v18_tide_choir", "name": "Tide Choir", "element": "water", "form": "cone", "effect": "elemental", "secondary_effect": "pull", "targeting": "both", "force": 11.0, "power": 2, "range": 8.0, "cone_angle": 48.0, "particles": "stars", "material_style": "spectral", "impact_accent": "mist", "sigil": "circle"},
		"control", "A wide water chorus gathers foes and loose objects inward.", "The cone wets visible enemies and pulls targets toward the caster. Follow with frost or storm for reactions.")
	_add({"id": "v18_pearled_mercy", "name": "Pearled Mercy", "element": "water", "form": "mend", "power": 2, "radius": 1.6, "particles": "stars", "material_style": "crystal", "sigil": "circle", "impact_accent": "mist", "particle_drift": 0.3},
		"support", "A soft pearl of water opens into a restorative mist.", "Restores two hearts to the caster. This is healing, with no water damage or wet target effect.")
	_add({"id": "v18_leviathan_arc", "name": "Leviathan Arc", "element": "water", "projectile": "serpent", "trajectory": "lob", "power": 3, "count": 1, "speed": 28.0, "size": 0.28, "particles": "stars", "material_style": "spectral", "trail_length": 1.6, "impact_accent": "mist",
		"stages": [{"form": "field", "power": 1, "radius": 2.0, "duration": 1.0, "trigger": "pulse", "pulses": 2, "interval": 0.6, "when": "hit", "material_style": "spectral", "impact_accent": "mist"}]},
		"offense", "A heavy water serpent arcs into a brief pulsing pool.", "The rising arc falls under gravity. First contact leaves two water pulses at the contact point.")
	_add({"id": "v18_glasscurrent", "name": "Glasscurrent", "element": "water", "form": "orbitals", "projectile": "disc", "trajectory": "returning", "count": 3, "power": 1, "hold_time": 0.35, "stagger": 0.12, "orbit_radius": 0.65, "return_time": 0.8, "speed": 20.0, "spread": 10.0, "material_style": "crystal", "particles": "stars", "trail_width": 0.7, "impact_accent": "mist"},
		"offense", "Three water discs circle the book, skim outward and return.", "A short hold precedes the returning flight. Water contacts prepare enemies for elemental combinations.")

	_add({"id": "v18_lanternlift", "name": "Lanternlift", "element": "wind", "form": "beam", "effect": "levitate", "targeting": "objects", "power": 1, "force": 16.0, "duration": 6.0, "range": 12.0, "mass_limit": 12.0, "projectile": "ribbon", "particles": "runes", "material_style": "spectral", "sigil": "circle", "impact_accent": "rings"},
		"control", "A pale ribbon lifts a real carryable object into the air.", "Aim at an unblocked object within twelve metres. The object stays under the existing levitation hand controls.")
	_add({"id": "v18_gale_gate", "name": "Gale Gate", "element": "wind", "form": "field", "effect": "repel", "targeting": "both", "force": 18.0, "power": 1, "radius": 2.6, "duration": 1.5, "trigger": "pulse", "pulses": 2, "interval": 0.8, "material_style": "spectral", "particles": "runes", "sigil": "circle", "impact_accent": "rings"},
		"control", "Two pale pressure rings repel targets from their centre.", "Place between approaching enemies and the caster. It pushes enemies and loose objects outward without direct damage.")
	_add({"id": "v18_zephyr_step", "name": "Zephyr Step", "element": "wind", "form": "step", "power": 1, "radius": 5.0, "particles": "runes", "material_style": "spectral", "sigil": "circle", "impact_accent": "rings", "particle_drift": 2.0},
		"mobility", "A clean wind wake follows the caster's longest short step.", "Moves up to five metres toward aim. Physical cover and safe placement still limit the distance.")
	_add({"id": "v18_skylark_blades", "name": "Skylark Blades", "element": "wind", "projectile": "blade", "trajectory": "helix", "count": 3, "power": 1, "speed": 25.0, "orbit_radius": 0.28, "spin": 1.7, "secondary_effect": "push", "force": 7.0, "particles": "runes", "material_style": "spectral", "trail_width": 0.6, "impact_accent": "rings"},
		"offense", "Three slim wind blades twist in a tight, fast helix.", "The narrow spiral is suited to open sight lines. Each real wind hit also pushes its target.")

	_add({"id": "v18_fault_bell", "name": "Fault Bell", "element": "earth", "form": "burst", "power": 3, "radius": 2.8, "range": 14.0, "projectile": "cube", "particles": "runes", "material_style": "crystal", "sigil": "fracture", "impact_accent": "shards", "impact_scale": 1.3},
		"offense", "A cracked earthen bell bursts in a heavy circle of stone.", "Aimed area damage respects visible cover. Heavy earth impact can shatter a frozen enemy for bonus damage.")
	_add({"id": "v18_stonewake_bastion", "name": "Stonewake Bastion", "element": "earth", "form": "wall", "power": 1, "duration": 6.0, "wall_width": 4.0, "wall_height": 2.6, "wall_thickness": 0.55, "range": 9.0, "particles": "runes", "material_style": "crystal", "sigil": "fracture", "impact_accent": "shards"},
		"construct", "A broad stone barricade rises from the marked ground.", "Creates a solid six-second wall in clear space. It blocks movement and vanishes without leaving world clutter.")
	_add({"id": "v18_gravestone_bloom", "name": "Gravestone Bloom", "element": "earth", "form": "rain", "projectile": "cube", "count": 4, "power": 2, "radius": 1.7, "rain_height": 3.5, "speed": 14.0, "stagger": 0.16, "size": 0.28, "particles": "runes", "material_style": "crystal", "sigil": "fracture", "impact_accent": "shards"},
		"offense", "Four squared stones tumble from a low, deliberate shower.", "Use against a tightly gathered group. The slow stagger leaves each solid impact easy to read.")
	_add({"id": "v18_lodestone_touch", "name": "Lodestone Touch", "element": "earth", "form": "touch", "effect": "enchant", "secondary_effect": "orbit", "targeting": "objects", "force": 10.0, "duration": 4.0, "power": 1, "particles": "runes", "material_style": "runic", "sigil": "fracture", "impact_accent": "shards",
		"stages": [{"form": "burst", "power": 2, "radius": 1.7, "when": "hit", "material_style": "crystal", "impact_accent": "shards"}]},
		"control", "A stone rune sets a nearby object orbiting with a stored impact.", "Touch a carryable object within two metres. Its first later physical impact releases one small earth burst.")

	_add({"id": "v18_forge_orbit", "name": "Forge Orbit", "element": "metal", "form": "orbitals", "projectile": "blade", "trajectory": "returning", "count": 3, "power": 2, "hold_time": 0.75, "stagger": 0.08, "orbit_radius": 0.75, "return_time": 0.9, "speed": 22.0, "spread": 8.0, "particles": "sparks", "material_style": "runic", "trail_length": 1.3, "impact_accent": "shards"},
		"offense", "Three forged blades form a precise, returning wheel.", "A clear hold precedes release. Each blade can strike along its physical outbound or return path.")
	_add({"id": "v18_mercury_lance", "name": "Mercury Lance", "element": "metal", "form": "beam", "projectile": "lance", "power": 3, "range": 30.0, "size": 0.1, "particles": "sparks", "material_style": "molten", "sigil": "fracture", "impact_accent": "shards", "trail": "none"},
		"offense", "A thin silver lance strikes in one exact line.", "A fast, single-contact metal attack for a distant visible target. The line ends at the first blocking surface.")
	_add({"id": "v18_tin_sentinel", "name": "Tin Sentinel", "element": "metal", "form": "summon", "summon_kind": "protector", "summon_count": 1, "power": 2, "duration": 6.0, "range": 12.0, "particles": "sparks", "material_style": "runic", "sigil": "circle", "impact_accent": "shards"},
		"companion", "A small metal protector answers with a sturdy silver silhouette.", "The temporary protector helps against visible enemies for six seconds. At most two guardians may be active.")
	_add({"id": "v18_needle_choir", "name": "Needle Choir", "element": "metal", "form": "rain", "projectile": "lance", "count": 6, "power": 1, "radius": 2.0, "rain_height": 7.0, "speed": 25.0, "stagger": 0.08, "size": 0.11, "particles": "sparks", "material_style": "runic", "trail": "none", "impact_accent": "sparks"},
		"offense", "Six fine silver needles descend in a bright, quick cadence.", "A compact falling pattern for clustered enemies. The needles still collide with roofs and other cover.")

	_add({"id": "v18_gravity_bloom", "name": "Gravity Bloom", "element": "void", "form": "field", "effect": "gravity_well", "secondary_effect": "suspend", "targeting": "both", "force": 16.0, "power": 1, "radius": 2.8, "duration": 1.8, "trigger": "pulse", "pulses": 3, "interval": 0.65, "material_style": "astral", "particles": "stars", "sigil": "fracture", "impact_accent": "rings"},
		"control", "Three astral pulses gather and suspend a small cluster.", "Pulls nearby enemies and loose objects into a bounded gravity field. It is control magic with no direct damage.")
	_add({"id": "v18_null_pearl", "name": "Null Pearl", "element": "void", "projectile": "orb", "trajectory": "spiral", "count": 1, "power": 3, "speed": 16.0, "orbit_radius": 0.3, "size": 0.26, "particles": "stars", "material_style": "astral", "trail": "orbit", "sigil": "fracture", "impact_accent": "rings",
		"stages": [{"form": "burst", "power": 1, "radius": 1.8, "when": "hit", "material_style": "astral", "particles": "stars", "impact_accent": "rings"}]},
		"offense", "A dark pearl spirals forward before collapsing into a ring.", "One heavy void projectile produces one compact first-contact burst. Its short spiral keeps the central sight line readable.")
	_add({"id": "v18_horizon_fold", "name": "Horizon Fold", "element": "void", "form": "step", "power": 1, "radius": 4.2, "particles": "stars", "material_style": "astral", "sigil": "fracture", "impact_accent": "rings", "residual_motes": 0.3,
		"stages": [{"form": "mend", "power": 1, "when": "delay", "stage_delay": 0.45, "material_style": "astral", "particles": "stars", "impact_accent": "rings"}]},
		"mobility", "An astral fracture offers a brief, restorative breathing space.", "Steps up to 4.2 metres, stopping at cover. After 0.45 seconds the caster regains one heart; no direct damage.")
	_add({"id": "v18_empty_citadel", "name": "Empty Citadel", "element": "void", "form": "wall", "power": 1, "duration": 5.0, "wall_width": 2.5, "wall_height": 3.1, "wall_thickness": 0.3, "range": 10.0, "particles": "stars", "material_style": "astral", "sigil": "fracture", "impact_accent": "rings", "opacity": 0.8},
		"construct", "A tall, narrow astral slab seals a chosen gap.", "Place a temporary solid wall in clear space. Its five-second lifetime is independent of saved world structures.")

	_add({"id": "v18_clockglass", "name": "Clockglass", "element": "time", "form": "field", "effect": "projectile_stasis", "targeting": "projectiles", "power": 1, "radius": 3.0, "duration": 1.7, "material_style": "spectral", "particles": "runes", "sigil": "clock", "impact_accent": "rings"},
		"control", "A clockface field arrests nearby magical projectiles.", "Temporarily freezes projectiles within the marked field, including friendly magic. It neither hurts nor heals enemies.")
	_add({"id": "v18_secondhand", "name": "Secondhand", "element": "time", "form": "orbitals", "projectile": "bolt", "trajectory": "fan", "count": 4, "power": 1, "hold_time": 1.25, "stagger": 0.0, "orbit_radius": 0.85, "spread": 12.0, "speed": 21.0, "secondary_effect": "slow", "duration": 2.0, "slow_factor": 0.45, "material_style": "spectral", "particles": "runes", "sigil": "clock", "impact_accent": "rings"},
		"offense", "Four clock hands wait, then release together in a narrow fan.", "The visible pause is part of the spell. Contact damages enemies and temporarily slows their local time.")
	_add({"id": "v18_borrowed_heart", "name": "Borrowed Heart", "element": "time", "form": "mend", "power": 2, "radius": 1.8, "material_style": "spectral", "particles": "runes", "sigil": "clock", "impact_accent": "rings",
		"stages": [{"form": "ward", "power": 1, "when": "delay", "stage_delay": 0.4, "material_style": "spectral", "particles": "runes", "sigil": "clock", "impact_accent": "rings"}]},
		"support", "A borrowed moment restores the caster, then adds a small ward.", "Restores two hearts immediately. After 0.4 seconds a two-damage ward grants a little time to recover position.")
	_add({"id": "v18_rewind_disc", "name": "Rewind Disc", "element": "time", "projectile": "disc", "trajectory": "returning", "count": 1, "power": 2, "speed": 22.0, "return_time": 0.65, "secondary_effect": "slow", "duration": 2.5, "slow_factor": 0.5, "material_style": "spectral", "particles": "runes", "sigil": "clock", "trail_fade": 1.7, "impact_accent": "rings"},
		"offense", "A single clock disc turns back along its flight path.", "A precise temporal hit slows the target. The finite return flight is visible and respects real collision.")
