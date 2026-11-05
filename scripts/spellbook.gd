extends RefCounted


const SCHEMA_VERSION := 2
const MAX_STAGES := 4
const MAX_SPELLS := 64
const SLOT_COUNT := 4
const MAX_MANA := 100.0
const COOLDOWN_SCALE := 0.5
const FORMS := ["volley", "beam", "burst", "ward", "mend", "step", "touch", "field", "cone", "rain", "orbitals", "trap", "wall", "summon", "strike"]
## Where the spell leaves Mr. Justice: his casting hand or the lantern in his head.
const ORIGINS := ["hand", "lantern"]
## Signature visual that makes a spell look like its name (see spell_motifs.gd).
const MOTIFS := ["none", "tornado", "updraft", "geyser", "whirlpool", "quake", "fire_ring", "dome", "thicket", "rain_heal", "bloom", "black_sun", "magnet", "nova", "gale", "shell", "phoenix",
	"fire_ground", "storm_cloud", "pillar", "wind_cone", "frost_cloud", "tidal_wave", "railgun", "clockwork", "clock_face", "fissure", "vortex"]
const ELEMENTS := ["flame", "frost", "storm", "grove", "light", "shadow", "water", "wind", "earth", "metal", "void", "time"]
const PROJECTILES := ["orb", "lance", "shard", "star", "comet", "ring", "cube", "blade", "bolt", "disc", "moth", "serpent", "ribbon"]
const TRAJECTORIES := ["straight", "fan", "helix", "seeking", "lob", "wave", "rising", "returning", "spiral", "ballistic"]
const PARTICLES := ["sparks", "runes", "petals", "embers", "stars"]
const TRAILS := ["ribbon", "orbit", "none"]
const EFFECTS := ["elemental", "levitate", "push", "pull", "suspend", "orbit", "gravity_well", "repel", "launch", "slow", "stasis", "projectile_stasis", "enchant", "heal", "shield"]
const SECONDARY_EFFECTS := ["none", "elemental", "levitate", "push", "pull", "suspend", "orbit", "gravity_well", "repel", "launch", "slow", "stasis", "projectile_stasis", "enchant", "heal", "shield"]
const TERTIARY_EFFECTS := SECONDARY_EFFECTS
const TARGETING := ["enemies", "objects", "both", "caster", "projectiles"]
const TRIGGERS := ["impact", "delay", "pulse"]
const IMPACTS := ["shatter", "pierce", "bounce", "chain"]
const STAGE_TRIGGERS := ["hit", "delay", "end"]
const CONDITIONS := ["always", "wet", "burning", "frozen", "movable"]
const MATERIAL_STYLES := ["elemental", "astral", "spectral", "crystal", "ink", "molten", "runic", "botanical"]
const SIGILS := ["circle", "star", "clock", "petals", "fracture"]
const IMPACT_ACCENTS := ["bloom", "shards", "rings", "sparks", "mist"]
const SUMMON_KINDS := ["sentinel", "familiar", "protector"]
const ENUMS := {"form": FORMS, "element": ELEMENTS, "projectile": PROJECTILES, "trajectory": TRAJECTORIES, "particles": PARTICLES, "trail": TRAILS,
	"effect": EFFECTS, "secondary_effect": SECONDARY_EFFECTS, "tertiary_effect": TERTIARY_EFFECTS, "targeting": TARGETING, "trigger": TRIGGERS, "impact": IMPACTS,
	"when": STAGE_TRIGGERS, "condition": CONDITIONS, "material_style": MATERIAL_STYLES, "sigil": SIGILS, "impact_accent": IMPACT_ACCENTS, "summon_kind": SUMMON_KINDS, "origin": ORIGINS, "motif": MOTIFS}
const INTEGER_FIELDS := ["count", "power", "intensity", "pulses", "pierces", "bounces", "chains", "repeat_contacts", "summon_count"]
const LIMITS := {
	"count": [1.0, 12.0], "power": [1.0, 5.0], "speed": [8.0, 28.0],
	"spread": [0.0, 45.0], "size": [0.1, 0.45], "lifetime": [0.8, 3.0],
	"radius": [1.0, 5.0], "intensity": [1.0, 3.0],
	"delay": [0.1, 3.0], "pulses": [1.0, 10.0], "interval": [0.2, 2.0],
	"duration": [0.5, 14.0], "force": [2.0, 30.0], "range": [2.0, 100.0],
	"mass_limit": [0.5, 30.0], "pierces": [1.0, 4.0], "bounces": [1.0, 4.0], "chains": [1.0, 4.0],
	"particle_density": [0.25, 2.0], "particle_size": [0.5, 2.0], "trail_width": [0.5, 2.0],
	"spin": [-3.0, 3.0], "pulse_speed": [0.25, 3.0], "glow": [0.0, 2.0], "opacity": [0.25, 1.0],
	"stage_delay": [0.0, 10.0], "repeat_contacts": [1.0, 4.0],
	"stagger": [0.0, 0.75], "homing": [0.0, 4.0], "orbit_radius": [0.3, 5.0], "return_time": [0.1, 3.0], "hold_time": [0.0, 3.0],
	"slow_factor": [0.1, 0.9], "cone_angle": [5.0, 90.0], "rain_height": [2.0, 12.0],
	"wall_width": [1.0, 6.0], "wall_height": [1.0, 4.0], "wall_thickness": [0.2, 1.0], "summon_count": [1.0, 2.0],
	"edge_noise": [0.0, 2.0], "trail_length": [0.25, 3.0], "trail_fade": [0.1, 3.0], "particle_drift": [0.0, 3.0],
	"impact_scale": [0.25, 3.0], "cast_scale": [0.25, 3.0], "residual_motes": [0.0, 2.0],
	"charge": [0.0, 4.0]
}
const ELEMENT_COLORS := {
	"flame": ["#ff794e", "#ffe6a0"], "frost": ["#82d9ff", "#ebffff"],
	"storm": ["#8c9aff", "#e9f5ff"], "grove": ["#82df9b", "#f8e3a2"],
	"light": ["#ffd36c", "#fff7d8"], "shadow": ["#b68bff", "#efb6ff"],
	"water": ["#3fbbdf", "#d0faff"], "wind": ["#afe7d9", "#f3fff6"],
	"earth": ["#bd9464", "#ffdda0"], "metal": ["#a9c4da", "#fff1c5"],
	"void": ["#6d4eaa", "#d7a6ff"], "time": ["#58d4c3", "#fff0b5"]
}

static func defaults(id: String = "custom_spell") -> Dictionary:
	var result := _flat_defaults(id)
	result["stages"] = []
	return result

static func _flat_defaults(id: String) -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "id": id, "name": "New spell", "form": "volley", "element": "flame",
		"projectile": "orb", "trajectory": "straight", "count": 1, "power": 2,
		"speed": 18.0, "spread": 12.0, "size": 0.18, "lifetime": 1.8, "radius": 2.5,
		"color": "#ff794e", "accent": "#ffe6a0", "particles": "sparks", "trail": "ribbon", "intensity": 2,
		"effect": "elemental", "secondary_effect": "none", "tertiary_effect": "none", "targeting": "enemies", "trigger": "impact",
		"delay": 0.5, "pulses": 3, "interval": 0.7, "duration": 4.0, "force": 12.0, "range": 100.0,
		"mass_limit": 12.0, "impact": "shatter", "pierces": 2, "bounces": 2, "chains": 2,
		"particle_density": 1.0, "particle_size": 1.0, "trail_width": 1.0,
		"spin": 1.0, "pulse_speed": 1.0, "glow": 1.0, "opacity": 1.0,
		"when": "hit", "condition": "always", "stage_delay": 0.5, "repeat_contacts": 1,
		"stagger": 0.0, "homing": 1.0, "orbit_radius": 1.5, "return_time": 1.0, "hold_time": 0.8,
		"slow_factor": 0.45, "cone_angle": 35.0, "rain_height": 6.0,
		"wall_width": 3.0, "wall_height": 2.5, "wall_thickness": 0.4, "summon_count": 1, "summon_kind": "sentinel",
		"core_color": "#ffe6a0", "rim_color": "#ffe6a0", "trail_color": "#ff794e", "material_style": "elemental",
		"edge_noise": 0.5, "trail_length": 1.0, "trail_fade": 1.0, "particle_drift": 1.0,
		"impact_scale": 1.0, "cast_scale": 1.0, "residual_motes": 1.0, "sigil": "circle", "impact_accent": "bloom",
		"charge": 0.0, "origin": "hand", "motif": "none"}

static func _valid_id(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 48:
		return false
	for i in value.length():
		var c: int = value.unicode_at(i)
		if not ((c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 95 or c == 45):
			return false
	return true

static func _valid_name(value: Variant) -> bool:
	if not value is String or value.strip_edges().is_empty() or value.length() > 36:
		return false
	for i in value.length():
		var code: int = value.unicode_at(i)
		if code < 32 or code == 127:
			return false
	return true

static func _hex(value: Variant) -> bool:
	if not value is String or value.length() != 7 or not value.begins_with("#"):
		return false
	for i in range(1, 7):
		if value.substr(i, 1).to_lower() not in "0123456789abcdef":
			return false
	return true

static func sanitize(raw: Variant) -> Dictionary:
	if not raw is Dictionary or not _valid_id(raw.get("id")):
		return {}
	var successors: Variant = raw.get("stages", [])
	if not successors is Array or successors.size() >= MAX_STAGES: return {}
	var result := _sanitize_flat(raw, true)
	if result.is_empty(): return {}
	var canonical: Array = []
	for successor in successors:
		var stage := _sanitize_flat(successor)
		if stage.is_empty(): return {}
		canonical.append(stage)
	result["stages"] = canonical
	return result

static func _sanitize_flat(raw: Variant, allow_root_stages: bool = false) -> Dictionary:
	if not raw is Dictionary or not _valid_id(raw.get("id")): return {}
	var version: Variant = raw.get("schema_version", 1)
	if not (version is int or version is float) or not is_finite(float(version)) or float(version) not in [1.0, 2.0]: return {}
	var result := _flat_defaults(raw.id)
	for key in raw:
		if key == "stages" and allow_root_stages: continue
		if not result.has(key): return {}
		result[key] = raw[key]
	result.schema_version = SCHEMA_VERSION
	if not _valid_name(result.name): return {}
	result.name = result.name.strip_edges()
	for key in ENUMS:
		if not result[key] is String or result[key] not in ENUMS[key]: return {}
	for key in LIMITS:
		var value: Variant = result[key]
		if not (value is float or value is int) or not is_finite(float(value)): return {}
		if key in INTEGER_FIELDS and float(value) != floorf(float(value)): return {}
		var bounded: float = clampf(float(value), LIMITS[key][0], LIMITS[key][1])
		result[key] = int(bounded) if key in INTEGER_FIELDS else bounded

	if not raw.has("range"):
		if result.form == "volley": result.range = 100.0
		elif result.form == "beam": result.range = 24.0 + float(result.power) * 2.0
		elif result.form == "burst": result.range = 18.0
		elif result.form == "strike": result.range = 32.0

	if not raw.has("core_color"): result.core_color = result.accent
	if not raw.has("rim_color"): result.rim_color = result.accent
	if not raw.has("trail_color"): result.trail_color = result.color
	for key in ["color", "accent", "core_color", "rim_color", "trail_color"]:
		if not _hex(result[key]): return {}
		result[key] = result[key].to_lower()
	return result


static func stage_list(raw: Dictionary) -> Array:
	var clean := sanitize(raw)
	if clean.is_empty(): return []
	var successors: Array = clean.stages
	clean.erase("stages")
	var result: Array = [clean]
	result.append_array(successors)
	return result

static func stage_recipe(raw: Dictionary, index: int) -> Dictionary:
	var stages := stage_list(raw)
	return stages[index] if index >= 0 and index < stages.size() else {}

static func stage_count(raw: Dictionary) -> int:
	return stage_list(raw).size()


static func update_stage(raw: Dictionary, index: int, changes: Dictionary) -> Dictionary:
	var clean := sanitize(raw)
	if clean.is_empty() or index < 0 or index > clean.stages.size() or changes.has("stages"): return {}
	if index == 0:
		clean.merge(changes, true)
	else:
		clean.stages[index - 1].merge(changes, true)
	return sanitize(clean)

static func add_stage(raw: Dictionary, recipe: Dictionary = {}) -> Dictionary:
	var clean := sanitize(raw)
	if clean.is_empty() or clean.stages.size() >= MAX_STAGES - 1: return {}
	var successor := recipe.duplicate(true)
	if successor.is_empty():
		successor = _flat_defaults(str(clean.id).left(39) + "_stage_%d" % (clean.stages.size() + 1))
		successor.name = clean.name
		successor.form = "burst"
		successor.element = clean.element
		for key in ["color", "accent", "core_color", "rim_color", "trail_color"]: successor[key] = clean[key]
	var stage := _sanitize_flat(successor)
	if stage.is_empty(): return {}
	clean.stages.append(stage)
	return clean

static func remove_stage(raw: Dictionary, index: int) -> Dictionary:
	var clean := sanitize(raw)
	if clean.is_empty() or index <= 0 or index > clean.stages.size(): return {}
	clean.stages.remove_at(index - 1)
	return clean

static func starters() -> Array:
	return templates()



## Editable copies of a few catalog spells for the spell workshop and a fresh spellbook.
## Their ids are prefixed so they never collide with the read-only catalog.
static func templates() -> Array:
	var result: Array = []
	var catalog = load("res://scripts/spell_collection.gd")
	for id in ["fireball", "skybolt", "lantern_beam", "levitation", "ice_shard", "water_bolt", "rock_throw", "thorn_shot", "shade_bolt", "iron_needle", "void_orb", "clock_bolt"]:
		var spell: Dictionary = catalog.spell_by_id(id)
		if spell.is_empty(): continue
		spell.id = "my_" + id
		spell.name = ("My " + str(spell.name)).left(36)
		for index in range(spell.stages.size()): spell.stages[index].id = "my_%s_s%d" % [id, index + 1]
		var clean := sanitize(spell)
		if not clean.is_empty(): result.append(clean)
	return result

static func default_slots() -> Array:
	return ["fireball", "skybolt", "lantern_beam", "levitation"]

static func effective_pulses(spell: Dictionary) -> int:
	var s := sanitize(spell)
	if s.is_empty(): return 0
	return _pulse_count(s)

static func _pulse_count(s: Dictionary) -> int:
	if s.trigger != "pulse": return 1
	return mini(int(s.pulses), 1 + floori(float(s.duration) / float(s.interval))) if s.form == "field" else int(s.pulses)

static func cost(spell: Dictionary) -> float:
	var s := sanitize(spell)
	if s.is_empty(): return MAX_MANA + 1.0
	var total := _stage_cost(s)
	var activations := 1
	for successor in s.stages:
		if successor.when == "hit": activations *= int(successor.repeat_contacts)
		total += _stage_cost(successor) * activations
	return ceilf(clampf(total, 4.0, 90.0))

static func _has_effect(s: Dictionary, choices: Array) -> bool:
	return s.effect in choices or s.secondary_effect in choices or s.tertiary_effect in choices

static func _stage_cost(s: Dictionary) -> float:
	var base: float = {"volley": 5.0, "beam": 10.0, "burst": 12.0, "ward": 12.0, "mend": 15.0, "step": 8.0, "touch": 4.0, "field": 12.0,
		"cone": 11.0, "rain": 13.0, "orbitals": 9.0, "trap": 10.0, "wall": 15.0, "summon": 16.0, "strike": 11.0}[s.form]
	var multiple: float = float(s.count - 1) * 2.0 if s.form in ["volley", "rain", "orbitals"] else 0.0
	var functional: bool = s.form not in ["ward", "mend", "step", "wall"]
	var strength := 0.0
	if functional:
		if _has_effect(s, ["levitate", "push", "pull", "suspend", "orbit", "gravity_well", "repel", "launch"]):
			strength += s.force * 0.16 + s.mass_limit * 0.08
			if _has_effect(s, ["levitate", "suspend", "orbit", "gravity_well"]): strength += s.duration * 0.35
		if s.secondary_effect != "none": strength += 5.0
		if s.tertiary_effect != "none": strength += 5.0
		if _has_effect(s, ["stasis", "projectile_stasis", "shield", "enchant"]): strength += s.duration * 0.5
		if _has_effect(s, ["slow"]): strength += s.duration * (1.0 - float(s.slow_factor)) * 0.8
		if s.trigger == "pulse": strength += (_pulse_count(s) - 1) * (2.0 + s.power * 0.8)
		if s.form in ["volley", "rain", "orbitals"] and s.impact != "shatter": strength += 2.0 * s[{"pierce": "pierces", "bounce": "bounces", "chain": "chains"}[s.impact]]
	if s.form == "orbitals": strength += s.hold_time * 0.3
	elif s.form == "trap": strength += s.duration * 0.3
	elif s.form == "cone": strength += maxf(0.0, s.range - 2.0) * s.cone_angle / 450.0
	elif s.form == "wall": strength += s.wall_width * s.wall_height * s.wall_thickness + s.duration * 0.3
	elif s.form == "summon": strength += (s.summon_count - 1) * 12.0 + s.duration * 0.5
	return base + s.power * 2.0 + multiple + strength + (s.radius - 1.0) * (1.0 if s.form in ["burst", "step", "field", "rain", "trap"] else 0.0)

static func cooldown(spell: Dictionary) -> float:
	var s := sanitize(spell)
	if s.is_empty(): return 10.0
	var total := _stage_cooldown(s)
	var activations := 1
	for successor in s.stages:
		if successor.when == "hit": activations *= int(successor.repeat_contacts)
		total += 0.25 + _stage_cooldown(successor) * activations * 0.6
	return minf(total, 30.0) * COOLDOWN_SCALE

static func _stage_cooldown(s: Dictionary) -> float:
	var base: float = {"volley": 0.7, "beam": 1.1, "burst": 1.8, "ward": 2.5, "mend": 3.0, "step": 1.8, "touch": 0.6, "field": 1.8,
		"cone": 1.5, "rain": 2.0, "orbitals": 1.7, "trap": 1.8, "wall": 2.5, "summon": 3.0, "strike": 1.6}[s.form]
	var extra := 0.0
	if s.form not in ["ward", "mend", "step", "wall"]:
		if s.secondary_effect != "none": extra += 0.3
		if s.tertiary_effect != "none": extra += 0.3
		if s.trigger == "pulse": extra += _pulse_count(s) * 0.15
	if s.form == "summon": extra += (s.summon_count - 1) * 0.5
	return base + s.power * 0.09 + (s.count - 1) * 0.045 + extra

static func damage(spell: Dictionary) -> int:
	var s := sanitize(spell)
	if s.is_empty(): return 0
	return int(s.power) + (1 if s.form in ["beam", "burst", "strike"] else 0)

static func describe(spell: Dictionary) -> String:
	var s := sanitize(spell)
	if s.is_empty(): return "Invalid spell"
	var summary := _describe_stage(s)
	for successor in s.stages:
		var when: String = {"hit": "On first hit", "delay": "After %.1f s" % successor.stage_delay, "end": "When it ends"}[successor.when]
		if successor.when == "hit" and successor.repeat_contacts > 1: when = "On up to %d contacts" % successor.repeat_contacts
		if successor.condition != "always": when += " if %s (otherwise chain ends)" % successor.condition
		summary += " → " + when +": " + _describe_stage(successor)
	return "%s · %d mana · %.1f s recovery" % [summary, int(cost(s)), cooldown(s)]

static func _describe_stage(s: Dictionary) -> String:
	var effect: String = {"flame": "burns twice", "frost": "freezes movement", "storm": "arcs to a nearby foe", "grove": "returns a little health", "light": "repels foes", "shadow": "delays enemy attacks",
		"water": "wets targets", "wind": "pushes targets", "earth": "heavy stone impact", "metal": "sharp metal impact", "void": "void impact", "time": "time impact"}[s.element]
	if s.form == "ward": effect = "protects the caster"
	elif s.form == "mend": effect = "heals the caster"
	elif s.form == "step": effect = "stops at cover"
	var action: String = {"volley": "%d %s projectiles" % [s.count, s.trajectory], "beam": "instant line of magic", "burst": "visible area of %.1f m" % s.radius,
		"ward": "absorbs %d damage for %.1f s" % [s.power + 1, 3.0 + s.power * 0.8], "mend": "restores %d hearts" % maxi(1, int(ceilf(s.power * 0.6))), "step": "moves up to %.1f m toward aim" % s.radius,
		"touch": "contact within 2 m", "field": "field of %.1f m for %.1f s" % [s.radius, s.duration],
		"cone": "%.0f° cone within %.1f m" % [s.cone_angle, s.range], "rain": "%d falling projectiles over %.1f m" % [s.count, s.radius],
		"orbitals": "%d orbiting projectiles, held %.1f s then released" % [s.count, s.hold_time], "trap": "trap of %.1f m for %.1f s" % [s.radius, s.duration],
		"wall": "%.1f × %.1f m solid wall for %.1f s" % [s.wall_width, s.wall_height, s.duration],
		"summon": "%d %s guardian for %.1f s" % [s.summon_count, s.summon_kind, s.duration],
		"strike": "strike from the sky over %.1f m" % s.radius}[s.form]
	if float(s.charge) > 0.0: action += " · hold to charge (%.1f s)" % s.charge
	if s.form not in ["ward", "mend", "step", "wall"]:
		if s.effect != "elemental": effect = s.effect.replace("_", " ") + " " + s.targeting
		if s.secondary_effect != "none": effect += " + " + s.secondary_effect.replace("_", " ")
		if s.tertiary_effect != "none": effect += " + " + s.tertiary_effect.replace("_", " ")
		if s.trigger == "delay": effect += " after %.1f s" % s.delay
		elif s.trigger == "pulse": effect += " · %d pulses / %.1f s" % [_pulse_count(s), s.interval]
	elif s.form == "wall": effect = "blocks movement and expires"
	return "%s · %s" % [action, effect]
