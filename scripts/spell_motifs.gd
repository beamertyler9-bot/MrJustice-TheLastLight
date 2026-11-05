extends Node3D
## Signature visuals that make a spell look like its name: a tornado is a funnel, a geyser
## erupts, an earthquake throws rocks up, a ward is a shell of its element around you.
## Chosen per spell with the "motif" field (spellbook.gd) and spawned by spell_presentation
## when the spell lands. Built from the shared magic shaders, so they match everything else.
## Self-managing: animates for `life` seconds, then frees itself.

const KAME_BODY = preload("res://shaders/magic/kame_beam.gdshader")
const KAME_GLOW = preload("res://shaders/magic/kame_glow.gdshader")

var presentation
var spell: Dictionary
var motif := ""
var radius := 1.5
var life := 1.0
var age := 0.0
var follow: Node3D
var _parts: Array = []
var _materials: Array = []
var _rng := RandomNumberGenerator.new()
var _body: Color
var _core: Color


func setup(owner_presentation, recipe: Dictionary, kind: String, point: Vector3, size: float, duration: float, hero: Node3D) -> void:
	presentation = owner_presentation; spell = recipe; motif = kind
	radius = clampf(size, 0.6, 5.0); life = clampf(duration, 0.4, 12.0)
	position = point
	follow = hero
	_rng.seed = hash(point)


func _ready() -> void:
	name = "Motif_" + motif
	top_level = true
	global_position = position
	_body = presentation._color(spell, "color", Color("a764ed"))
	_core = presentation._color(spell, "core_color", presentation._color(spell, "accent", Color("ffefc8")))
	match motif:
		"tornado": _build_funnel(true)
		"updraft": _build_funnel(false)
		"geyser": _build_geyser()
		"whirlpool": _build_whirlpool()
		"quake": _build_quake()
		"fire_ring": _build_fire_ring()
		"dome": _build_dome()
		"thicket": _build_thicket()
		"rain_heal": _build_rain()
		"bloom": _build_bloom()
		"black_sun": _build_black_sun()
		"magnet": _build_magnet()
		"nova": _build_nova()
		"gale": _build_gale()
		"shell": _build_shell()
		"phoenix": pass
	_update(0.0)


func _process(dt: float) -> void:
	age += dt
	if age >= life:
		queue_free(); return
	if is_instance_valid(follow): global_position = follow.global_position
	_update(dt)


# ------------------------------------------------------------------ helpers
func _kame(shader: Shader, extra: Dictionary = {}) -> ShaderMaterial:
	var material := ShaderMaterial.new(); material.shader = shader
	material.set_shader_parameter("body_color", _body)
	material.set_shader_parameter("core_color", _core)
	material.set_shader_parameter("low_flash", 1.0 if bool(presentation._settings().get("low_flash", false)) else 0.0)
	for key in extra: material.set_shader_parameter(key, extra[key])
	_materials.append(material)
	return material

func _spell_material(shader: Shader) -> ShaderMaterial:
	var material: ShaderMaterial = presentation._material(shader, spell)
	_materials.append(material)
	return material

func _part(mesh: Mesh, material: Material, role: String, data: Dictionary = {}) -> MeshInstance3D:
	var part := MeshInstance3D.new(); part.mesh = mesh; part.material_override = material
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; part.extra_cull_margin = 3.0
	add_child(part)
	data.node = part; data.role = role
	_parts.append(data)
	return part

func _cone(top: float, bottom: float, height: float) -> CylinderMesh:
	var cone := CylinderMesh.new(); cone.top_radius = top; cone.bottom_radius = bottom; cone.height = height
	cone.radial_segments = 16; cone.rings = 6; cone.cap_top = false; cone.cap_bottom = false
	return cone

func _envelope() -> float:
	var p := age / life
	return smoothstep(0.0, 0.12, p) * (1.0 - smoothstep(0.78, 1.0, p))


# ------------------------------------------------------------------ builders
func _build_funnel(twister: bool) -> void:
	var height := 3.6 if twister else 4.2
	var outer := _part(_cone(radius * (0.95 if twister else 0.55), radius * (0.18 if twister else 0.5), height), _kame(KAME_GLOW, {"turns": 3.0, "spiral": 1.0, "tube": true}), "funnel", {"height": height})
	outer.position.y = height * 0.5
	var inner := _part(_cone(radius * (0.6 if twister else 0.35), radius * (0.1 if twister else 0.32), height * 0.95), _kame(KAME_GLOW, {"turns": 4.5, "spiral": 1.0, "tube": true}), "funnel_inner", {"height": height})
	inner.position.y = height * 0.48
	var debris := SphereMesh.new(); debris.radius = 0.5; debris.height = 1.0; debris.radial_segments = 5; debris.rings = 3
	var stuff := _spell_material(presentation.MOTE)
	for i in range(14):
		_part(debris, stuff, "swirl", {"seed": float(i), "height": height, "twister": twister})

func _build_geyser() -> void:
	var water_body := Color(str(spell.get("color", "#3fbbdf"))); var water_core := Color(str(spell.get("core_color", spell.get("accent", "#d0faff"))))
	preload("res://scripts/kame_beam.gd").spawn(self, global_position, global_position + Vector3.UP * (3.4 + radius * 0.6), water_body, water_core, clampf(radius * 0.22, 0.25, 0.7), minf(life, 1.2), false, 0.9)
	var drop: Mesh = presentation._mesh("core_sphere"); var liquid := _spell_material(presentation.CORE)
	for i in range(12):
		_part(drop, liquid, "spray", {"seed": float(i)})

func _build_whirlpool() -> void:
	var ring := TorusMesh.new(); ring.inner_radius = 0.86; ring.outer_radius = 1.0; ring.rings = 32; ring.ring_segments = 4
	var swirl := _spell_material(presentation.ENERGY)
	for i in range(4):
		_part(ring, swirl, "vortex_ring", {"seed": float(i)})
	var pool := SphereMesh.new(); pool.radius = 0.5; pool.height = 1.0; pool.radial_segments = 20; pool.rings = 8
	_part(pool, _spell_material(presentation.CORE), "pool")

func _build_quake() -> void:
	var stone: Mesh = presentation._mesh("stone"); var rock := _spell_material(presentation.SURFACE)
	for i in range(10):
		var angle := float(i) * TAU / 10.0 + _rng.randf_range(-0.2, 0.2)
		var distance := radius * _rng.randf_range(0.25, 0.95)
		_part(stone, rock, "boulder", {"seed": float(i), "at": Vector3(cos(angle), 0.0, sin(angle)) * distance, "size": _rng.randf_range(0.35, 0.7)})

func _build_fire_ring() -> void:
	var card := QuadMesh.new(); card.size = Vector2.ONE
	var fire := _spell_material(presentation.FLAME)
	for i in range(16):
		_part(card, fire, "ring_flame", {"seed": float(i)})

func _build_dome() -> void:
	var dome := SphereMesh.new(); dome.radius = 1.0; dome.height = 1.0; dome.is_hemisphere = true; dome.radial_segments = 24; dome.rings = 8
	_part(dome, _kame(KAME_GLOW, {"turns": 2.0, "spiral": 1.0, "tube": false}), "dome")
	# The element itself as the dome's skin: crackling plasma, a golden clock face...
	var skin := _part(dome, _spell_material(presentation.CORE), "dome")
	skin.transparency = 0.5
	var rim := TorusMesh.new(); rim.inner_radius = 0.97; rim.outer_radius = 1.0; rim.rings = 40; rim.ring_segments = 4
	_part(rim, _spell_material(presentation.ENERGY), "dome_rim")

func _build_thicket() -> void:
	var thorn: Mesh = presentation._mesh("blade"); var leaf: Mesh = presentation._mesh("leaf")
	var wood := _spell_material(presentation.SURFACE)
	for i in range(16):
		var angle := _rng.randf() * TAU; var distance := radius * sqrt(_rng.randf()) * 0.9
		_part(thorn if i % 3 != 0 else leaf, wood, "vine", {"seed": float(i), "at": Vector3(cos(angle), 0.0, sin(angle)) * distance, "lean": _rng.randf_range(-0.5, 0.5), "size": _rng.randf_range(0.5, 1.0)})

func _build_rain() -> void:
	var drop: Mesh = presentation._mesh("core_sphere"); var liquid := _spell_material(presentation.CORE)
	for i in range(18):
		_part(drop, liquid, "raindrop", {"seed": float(i), "angle": _rng.randf() * TAU, "distance": _rng.randf_range(0.2, 1.1), "phase": _rng.randf()})
	var glow := TorusMesh.new(); glow.inner_radius = 0.9; glow.outer_radius = 1.0; glow.rings = 32; glow.ring_segments = 4
	_part(glow, _spell_material(presentation.ENERGY), "heal_ring")

func _build_bloom() -> void:
	var leaf: Mesh = presentation._mesh("leaf"); var petals := _spell_material(presentation.SURFACE)
	for i in range(14):
		_part(leaf, petals, "petal", {"seed": float(i)})

func _build_black_sun() -> void:
	var orb: Mesh = presentation._mesh("core_sphere")
	_part(orb, _spell_material(presentation.CORE), "black_sun")
	var corona := QuadMesh.new(); corona.size = Vector2.ONE
	_part(presentation._mesh("shock_card"), _spell_material(presentation.HALO), "corona")
	_part(corona, _spell_material(presentation.HALO), "corona_glow")

func _build_magnet() -> void:
	var arc: Mesh = presentation._mesh("arc"); var field := _spell_material(presentation.ENERGY)
	for i in range(8):
		_part(arc, field, "field_line", {"seed": float(i)})
	var core: Mesh = presentation._mesh("core_sphere")
	_part(core, _spell_material(presentation.CORE), "magnet_core")

func _build_nova() -> void:
	var shard: Mesh = presentation._mesh("shard"); var ice := _spell_material(presentation.SURFACE)
	for i in range(18):
		_part(shard, ice, "nova_shard", {"seed": float(i)})
	var ring := TorusMesh.new(); ring.inner_radius = 0.92; ring.outer_radius = 1.0; ring.rings = 40; ring.ring_segments = 4
	_part(ring, _spell_material(presentation.ENERGY), "nova_ring")

func _build_gale() -> void:
	var ring := TorusMesh.new(); ring.inner_radius = 0.9; ring.outer_radius = 1.0; ring.rings = 40; ring.ring_segments = 4
	var wind := _spell_material(presentation.ENERGY)
	for i in range(4):
		_part(ring, wind, "gale_ring", {"seed": float(i)})

func _build_shell() -> void:
	var shell := SphereMesh.new(); shell.radius = 1.0; shell.height = 2.0; shell.radial_segments = 24; shell.rings = 12
	_part(shell, _kame(KAME_GLOW, {"turns": 1.5, "spiral": 1.0, "tube": false}), "shell")
	var family := str(presentation._family(spell))
	var mesh_name: String = {"earth": "stone", "metal": "blade", "frost": "shard", "light": "rune", "time": "rune", "grove": "leaf", "shadow": "moth"}.get(family, "core_sphere")
	var material: ShaderMaterial = _spell_material(presentation.CORE if mesh_name == "core_sphere" else presentation.SURFACE)
	for i in range(8):
		_part(presentation._mesh(mesh_name), material, "plate", {"seed": float(i), "family": family})


# ------------------------------------------------------------------ animation
func _update(dt: float) -> void:
	var envelope := _envelope()
	for material in _materials:
		if material.shader == KAME_BODY or material.shader == KAME_GLOW:
			material.set_shader_parameter("age", age); material.set_shader_parameter("opacity", envelope)
		else:
			presentation._set_material_clock(material, spell, age, envelope)
	var camera: Camera3D = presentation._camera()
	for data in _parts:
		var node: MeshInstance3D = data.node
		var seed: float = data.get("seed", 0.0)
		match str(data.role):
			"funnel", "funnel_inner":
				node.rotation.y = age * (3.5 if data.role == "funnel" else -5.0)
				node.scale = Vector3(1.0, smoothstep(0.0, 0.25, age / life), 1.0)
				node.position = Vector3(sin(age * 2.3) * 0.12 * radius, float(data.height) * 0.5 * node.scale.y, cos(age * 1.9) * 0.12 * radius)
			"swirl":
				var rise := fposmod(age * 0.55 + seed / 14.0, 1.0)
				var spin := seed * 2.39996 + age * (6.0 if data.twister else 3.0)
				var r := radius * (lerpf(0.2, 0.95, rise) if data.twister else 0.5)
				node.position = Vector3(cos(spin) * r, rise * float(data.height), sin(spin) * r)
				node.scale = Vector3.ONE * 0.09 * (1.0 + seed * 0.05)
			"spray":
				var t := fposmod(age * 1.3 + seed / 12.0, 1.0)
				var dir := Vector3(cos(seed * 2.39996), 0.0, sin(seed * 2.39996))
				node.position = dir * (0.3 + t * radius * 0.8) + Vector3.UP * (3.5 * t - 4.0 * t * t + 2.4)
				node.scale = Vector3.ONE * 0.22 * (1.0 - t * 0.5)
			"vortex_ring":
				var shrink := 1.0 - fposmod(age * 0.6 + seed / 4.0, 1.0)
				node.scale = Vector3(radius * shrink, 1.0, radius * shrink) * Vector3(1.0, 0.2, 1.0)
				node.rotation = Vector3(0.0, age * (2.0 + seed), 0.0)
				node.position.y = 0.06 + (1.0 - shrink) * -0.25
			"pool":
				node.scale = Vector3(radius * 0.7, 0.18, radius * 0.7)
				node.position.y = 0.04
			"boulder":
				var pulse := fposmod(age / maxf(life / 3.0, 0.3) + seed * 0.07, 1.0)
				var pop := sin(pulse * PI)
				node.position = data.at + Vector3.UP * (pop * 0.9 - 0.25)
				node.scale = Vector3.ONE * float(data.size) * (0.6 + pop * 0.6)
				node.rotation = Vector3(seed, age * 2.0 + seed, seed * 0.5)
			"ring_flame":
				var angle := seed * TAU / 16.0 + age * 0.4
				var flicker := 1.0 + sin(age * 11.0 + seed * 1.7) * 0.18
				node.global_position = global_position + Vector3(cos(angle) * radius, 0.55 * flicker, sin(angle) * radius)
				node.scale = Vector3(0.7, 1.2 * flicker, 1.0) * clampf(radius * 0.45, 0.6, 1.4)
				if camera != null: node.look_at(camera.global_position, Vector3.UP, true)
			"dome":
				node.scale = Vector3.ONE * radius * smoothstep(0.0, 0.2, age / life + 0.05)
				node.rotation.y = age * 0.6
			"dome_rim":
				node.scale = Vector3(radius, 0.3, radius); node.position.y = 0.04; node.rotation.y = -age
			"vine":
				var grow := smoothstep(0.0, 0.25, age / life) * (1.0 - smoothstep(0.85, 1.0, age / life))
				node.position = data.at
				node.rotation = Vector3(-PI * 0.5 + float(data.lean), seed, sin(age * 2.0 + seed) * 0.15)
				node.scale = Vector3(0.6, 0.6, 3.0) * float(data.size) * maxf(grow, 0.01)
			"raindrop":
				var t := fposmod(age * 1.4 + float(data.phase), 1.0)
				var angle: float = data.angle
				node.position = Vector3(cos(angle) * float(data.distance), 3.0 - t * 3.0, sin(angle) * float(data.distance))
				node.scale = Vector3(0.07, 0.17, 0.07)
			"heal_ring":
				node.scale = Vector3(1.2, 0.3, 1.2) * (1.0 + sin(age * 4.0) * 0.06); node.position.y = 0.05
			"petal":
				var t := fposmod(age * 0.6 + seed / 14.0, 1.0); var spin := seed * 2.39996 + age * 3.0
				node.position = Vector3(cos(spin) * (0.5 + t * 0.6), t * 2.4, sin(spin) * (0.5 + t * 0.6))
				node.rotation = Vector3(age * 2.0 + seed, spin, seed)
				node.scale = Vector3.ONE * 0.22
			"black_sun":
				node.position.y = 1.4; node.scale = Vector3.ONE * radius * 0.6 * (0.6 + 0.4 * smoothstep(0.0, 0.2, age / life))
			"corona", "corona_glow":
				node.position.y = 1.4
				node.scale = Vector3.ONE * radius * (1.25 if data.role == "corona" else 1.7) * (1.0 + sin(age * 3.0) * 0.04)
				if camera != null: node.look_at(camera.global_position, Vector3.UP, true)
				node.transparency = 0.0
			"field_line":
				var shrink := 1.0 - fposmod(age * 0.9 + seed / 8.0, 1.0)
				node.position = Vector3(0, 0.8, 0)
				node.rotation = Vector3(PI * 0.5, seed * TAU / 8.0, 0.0)
				node.scale = Vector3(1.0, 1.0, 2.5) * radius * (0.35 + shrink * 0.9)
			"magnet_core":
				node.position.y = 0.8; node.scale = Vector3.ONE * 0.7 * (1.0 + sin(age * 8.0) * 0.08)
			"nova_shard":
				var burst := 1.0 - pow(1.0 - clampf(age / 0.45, 0.0, 1.0), 2.0)
				var angle := seed * TAU / 18.0
				node.position = Vector3(cos(angle), 0.0, sin(angle)) * radius * burst + Vector3.UP * 0.35
				node.rotation = Vector3(0.0, -angle + PI * 0.5, 0.0)
				node.scale = Vector3(0.3, 0.3, 0.9) * (1.0 - smoothstep(0.6, 1.0, age / life))
			"nova_ring":
				var burst := 1.0 - pow(1.0 - clampf(age / 0.45, 0.0, 1.0), 2.0)
				node.scale = Vector3(radius * burst, 0.4, radius * burst); node.position.y = 0.2
			"gale_ring":
				var grow := fposmod(age * 0.9 + seed / 4.0, 1.0)
				node.scale = Vector3(radius * (0.2 + grow), 0.6, radius * (0.2 + grow))
				node.position.y = 0.3 + seed * 0.45
				node.rotation.y = age * 3.0
				node.transparency = grow * 0.4
			"shell":
				node.position.y = 1.0
				node.scale = Vector3(0.95, 1.15, 0.95) * (1.0 + sin(age * 3.0) * 0.03)
			"plate":
				var spin := seed * TAU / 8.0 + age * 1.6
				var height := 0.5 + fposmod(seed * 0.37, 1.0) * 1.1
				node.position = Vector3(cos(spin) * 0.85, height, sin(spin) * 0.85)
				node.rotation = Vector3(0.0, -spin, 0.3)
				node.scale = Vector3.ONE * (0.32 if str(data.family) in ["earth", "metal", "frost"] else 0.18)
