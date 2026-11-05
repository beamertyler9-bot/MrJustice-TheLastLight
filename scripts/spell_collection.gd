extends RefCounted


const Book = preload("res://scripts/spellbook.gd")
const ROLES := ["offense", "control", "protection", "support", "mobility", "construct", "companion"]
static var _spells: Array = []
static var _notes: Dictionary = {}

static func starting_slots() -> Array:
	return preload("res://scripts/spell_catalog.gd").STARTERS.duplicate()

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
	full.range = 60.0 if str(raw.get("form", "volley")) in ["volley", "orbitals"] else 18.0
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
	var level := str(raw.get("tier", "advanced")); raw.erase("tier")
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
	_lengthen(full)
	for stage in full.stages: _lengthen(stage)
	var clean := Book.sanitize(full)
	if clean.is_empty():
		push_error("Invalid fixed spell: " + str(raw.id))
		return
	_spells.append(clean)
	_notes[str(raw.id)] = {"role": purpose, "summary": summary, "tactics": tactics, "tier": level}

## Every built-in spell lasts longer: lingering effects (fields, traps, walls, summons,
## statuses, stasis) run 60 % longer and keep pulsing for it, rain pours over a longer
## stretch, and orbiting spells hover longer before they fly. Teleports and Levitation keep
## their own timing.
const LONGER := 1.6

static func _lengthen(spell: Dictionary) -> void:
	var form := str(spell.get("form", ""))
	if form in ["step", "touch"]: return
	if "levitate" in [spell.get("effect"), spell.get("secondary_effect"), spell.get("tertiary_effect")]: return
	spell.duration = minf(float(spell.get("duration", 4.0)) * LONGER, 14.0)
	if str(spell.get("trigger", "")) == "pulse":
		spell.pulses = clampi(roundi(float(spell.get("pulses", 3)) * LONGER), 1, 10)
	if form == "rain":
		spell.stagger = minf(float(spell.get("stagger", 0.0)) * LONGER, 0.75)
	if form == "orbitals":
		spell.hold_time = minf(float(spell.get("hold_time", 0.8)) * 1.5, 3.0)

static func _ensure_catalog() -> void:
	if not _spells.is_empty(): return
	for entry in preload("res://scripts/spell_catalog.gd").entries():
		_add(entry[0], entry[1], entry[2], entry[3])

## "basic" for each element's two starter-level spells, "advanced" otherwise.
static func tier(id: String) -> String:
	_ensure_catalog()
	return str(_notes.get(id, {}).get("tier", "advanced"))
