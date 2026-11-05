extends Node3D
## The Railgun's magic array - the most powerful spell in the game.
##
## Charging: a large METAL magic circle opens in front of the hand as the base. Smaller
## STORM, FLAME and LIGHT circles rise out of it and orbit around its rim, faster and faster,
## with lightning arcing between them. Past half charge a "barrel" of metal accelerator rings
## lines up down the aim, and at full charge the whole array throbs and crackles.
##
## Release (self-freeing): the barrel rings are flung down the beam like shockwaves, the base
## and its three orbiting circles flare huge and spin out, lightning wraps the beam, and a
## second array of circles blooms at the point of impact.

const Circle = preload("res://scripts/magic_circle.gd")
const BARREL := 4
const ARCS := 6

var _base: MeshInstance3D
var _orbiters: Array[MeshInstance3D] = []
var _barrel: Array[MeshInstance3D] = []
var _impact: Array[MeshInstance3D] = []
var _materials: Array[ShaderMaterial] = []
var _arcs: MeshInstance3D
var _arc_mesh: ImmediateMesh
var _arc_material: StandardMaterial3D
var _clock := 0.0
var _arc_clock := 0.0
var _release := false
var _life := 1.9
var _origin := Vector3.ZERO
var _direction := Vector3.FORWARD
var _end := Vector3.ZERO
var _gentle := false
var _spin := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "RailgunArray"
	top_level = true
	_rng.seed = 7151


func _card(element: String, glow: float) -> MeshInstance3D:
	var quad := QuadMesh.new(); quad.size = Vector2.ONE * 2.0
	var material := ShaderMaterial.new(); material.shader = Circle.SHADER
	material.set_shader_parameter("sheet", Circle.SHEETS[element])
	material.set_shader_parameter("glow", glow)
	_materials.append(material)
	var card := MeshInstance3D.new()
	card.mesh = quad; card.material_override = material
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; card.extra_cull_margin = 4.0
	card.visible = false
	add_child(card)
	return card


func _ensure() -> void:
	if _base != null: return
	_base = _card("metal", 1.7)
	for element in ["storm", "flame", "light"]: _orbiters.append(_card(element, 1.9))
	for i in range(BARREL): _barrel.append(_card("metal", 1.5))
	_arc_mesh = ImmediateMesh.new()
	_arc_material = StandardMaterial3D.new()
	_arc_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_arc_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_arc_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_arc_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_arc_material.vertex_color_use_as_albedo = true
	_arc_material.no_depth_test = false
	_arcs = MeshInstance3D.new(); _arcs.mesh = _arc_mesh; _arcs.material_override = _arc_material
	_arcs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; _arcs.extra_cull_margin = 16.0
	add_child(_arcs)


static func _facing(direction: Vector3) -> Basis:
	var z := -direction.normalized()
	if z.length_squared() < 0.5: z = Vector3.BACK
	var x := Vector3.UP.cross(z)
	if x.length_squared() < 1.0e-4: x = Vector3.RIGHT
	x = x.normalized()
	return Basis(x, z.cross(x).normalized(), z)


func _place(card: MeshInstance3D, basis: Basis, point: Vector3, size: float, twist: float, opacity: float) -> void:
	card.visible = size > 0.01 and opacity > 0.01
	if not card.visible: return
	card.global_transform = Transform3D(basis * Basis(Vector3.BACK, twist) * Basis.from_scale(Vector3.ONE * size), point)
	var material := card.material_override as ShaderMaterial
	material.set_shader_parameter("opacity", clampf(opacity, 0.0, 1.0))


## Charging: `anchor` is the hand, `direction` the aim, `amount` 0..1.
func update_charge(_presentation, _spell: Dictionary, anchor: Vector3, direction: Vector3, amount: float, dt: float) -> void:
	_ensure()
	_gentle = bool(_presentation._settings().get("low_flash", false)) if _presentation != null and _presentation.has_method("_settings") else false
	_clock += dt
	_spin += dt * (1.2 + amount * amount * 9.0)
	for material in _materials: material.set_shader_parameter("clock", _clock * (1.0 + amount))
	var facing := _facing(direction)
	var forward := direction.normalized()
	var center := anchor + forward * 0.7
	var full := amount >= 0.999
	var throb := 1.0 + (sin(_clock * 22.0) * 0.06 if full and not _gentle else 0.0)
	# The metal base opens over the first third of the charge.
	var open := smoothstep(0.0, 0.3, amount)
	_place(_base, facing, center, (0.25 + 0.9 * open) * throb, _spin * 0.35, open)
	# Storm, flame and light rise out of it and orbit its rim.
	var rise := smoothstep(0.22, 0.6, amount)
	var orbit_points: Array[Vector3] = []
	for i in range(_orbiters.size()):
		var angle := float(i) * TAU / 3.0 + _spin + PI * 0.5
		var offset := (facing.x * cos(angle) + facing.y * sin(angle)) * 1.2 * rise * throb
		var point := center + offset + forward * 0.12
		orbit_points.append(point)
		_place(_orbiters[i], facing, point, 0.42 * rise * throb, -_spin * 2.2, rise)
	# Past half charge, a barrel of accelerator rings lines up down the aim.
	var barrel := smoothstep(0.5, 0.9, amount)
	for i in range(BARREL):
		var stagger := clampf(barrel * float(BARREL) - float(i), 0.0, 1.0)
		var size := (0.62 - float(i) * 0.08) * stagger * throb
		_place(_barrel[i], facing, center + forward * (0.8 + float(i) * 0.7), size, _spin * (0.8 + float(i) * 0.3) * (1.0 if i % 2 == 0 else -1.0), stagger * 0.9)
	# Lightning arcs jump between the orbiting circles (and down the barrel when full).
	_arc_clock -= dt
	if _arc_clock <= 0.0:
		_arc_clock = 0.09 if not _gentle else 0.22
		_arc_mesh.clear_surfaces()
		if rise > 0.5:
			_begin_arcs()
			for i in range(3):
				_bolt(orbit_points[i], orbit_points[(i + 1) % 3], 0.18, 0.035, Color(0.55, 0.85, 1.0, 0.95))
			if amount > 0.75:
				for i in range(3):
					_bolt(orbit_points[i], center + forward * (0.8 + 0.7 * float(BARREL - 1)), 0.22, 0.03, Color(0.75, 0.9, 1.0, 0.9))
			_arc_mesh.surface_end()


## Fire: hand over to the self-freeing release animation.
func release(presentation, spell: Dictionary, origin: Vector3, direction: Vector3, end: Vector3 = Vector3.INF) -> void:
	_ensure()
	_gentle = bool(presentation._settings().get("low_flash", false)) if presentation != null and presentation.has_method("_settings") else false
	_release = true; _origin = origin; _direction = direction.normalized(); _clock = 0.0
	_end = end if end.is_finite() else origin + _direction * float(spell.get("range", 30.0))
	# A second array blooms where the shot lands, facing back at the hero.
	_impact.append(_card("metal", 1.8))
	for element in ["storm", "flame", "light"]: _impact.append(_card(element, 1.9))
	_animate_release()


func _process(dt: float) -> void:
	if not _release: return
	_clock += dt
	if _clock >= _life:
		queue_free(); return
	_spin += dt * maxf(2.0, 14.0 * (1.0 - _clock / _life))
	for material in _materials: material.set_shader_parameter("clock", _clock * 2.0)
	_arc_clock -= dt
	_animate_release()


func _animate_release() -> void:
	var t := _clock / _life
	var facing := _facing(_direction)
	var center := _origin + _direction * 0.7
	var fade := 1.0 - smoothstep(0.45, 1.0, t)
	# The base and its orbiters flare huge and spin out.
	var flare := 1.0 + smoothstep(0.0, 0.25, t) * 0.9
	_place(_base, facing, center, 1.15 * flare, _spin * 0.5, fade)
	for i in range(_orbiters.size()):
		var angle := float(i) * TAU / 3.0 + _spin + PI * 0.5
		var spread := 1.2 + smoothstep(0.0, 0.6, t) * 1.6
		var point := center + (facing.x * cos(angle) + facing.y * sin(angle)) * spread + _direction * t * 1.5
		_place(_orbiters[i], facing, point, 0.42 * (1.0 + t), -_spin * 2.5, fade)
	# The barrel rings are flung down the beam like shockwaves, growing as they go.
	var length := _origin.distance_to(_end)
	for i in range(BARREL):
		var launch := clampf(t * 2.2 - float(i) * 0.12, 0.0, 1.0)
		var travel := lerpf(0.8 + float(i) * 0.7, length * (0.25 + 0.18 * float(i)), 1.0 - pow(1.0 - launch, 3.0))
		var ring_fade := 1.0 - smoothstep(0.55, 1.0, launch)
		_place(_barrel[i], facing, center + _direction * travel, (0.62 - float(i) * 0.08) * (1.0 + launch * 2.4), _spin * (1.0 + float(i) * 0.4), ring_fade)
	# The impact array: metal base on the struck point, three circles bursting outward.
	var bloom := smoothstep(0.04, 0.2, t)
	var back := _facing(-_direction)
	var hit_point := _end - _direction * 0.25
	if not _impact.is_empty():
		_place(_impact[0], back, hit_point, 2.4 * bloom, -_spin * 0.4, fade)
		for i in range(1, _impact.size()):
			var angle := float(i - 1) * TAU / 3.0 - _spin * 0.6
			var out := 1.6 + smoothstep(0.1, 0.8, t) * 2.2
			_place(_impact[i], back, hit_point + (back.x * cos(angle) + back.y * sin(angle)) * out * bloom, 0.8 * bloom, _spin * 1.8, fade)
	# Lightning wraps the beam and lashes between the circles.
	if _arc_clock <= 0.0 and fade > 0.05:
		_arc_clock = 0.06 if not _gentle else 0.2
		_arc_mesh.clear_surfaces()
		_begin_arcs()
		var tint := Color(0.6, 0.88, 1.0, 0.95 * fade)
		for k in range(ARCS if not _gentle else 2):
			var a := _rng.randf() * TAU; var b := a + _rng.randf_range(-1.2, 1.2)
			var from := center + (facing.x * cos(a) + facing.y * sin(a)) * 0.9
			var along := length * _rng.randf_range(0.35, 1.0)
			var to := _origin + _direction * along + (facing.x * cos(b) + facing.y * sin(b)) * 0.9
			_bolt(from, to, 0.55, 0.05, tint)
		for i in range(_orbiters.size()):
			if _orbiters[i].visible: _bolt(_orbiters[i].global_position, center, 0.25, 0.04, tint)
		_arc_mesh.surface_end()
	elif fade <= 0.05:
		_arc_mesh.clear_surfaces()


func _begin_arcs() -> void:
	_arc_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _arc_material)


## One jagged lightning bolt as a camera-facing ribbon.
func _bolt(from: Vector3, to: Vector3, jitter: float, width: float, tint: Color) -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var eye: Vector3 = camera.global_position if camera != null else from + Vector3.BACK * 10.0
	var span := to - from
	var segments := clampi(int(span.length() * 2.5), 4, 24)
	var axis := span.normalized()
	var side_a := axis.cross(Vector3.UP)
	if side_a.length_squared() < 1.0e-4: side_a = axis.cross(Vector3.RIGHT)
	side_a = side_a.normalized()
	var side_b := axis.cross(side_a).normalized()
	var points: Array[Vector3] = []
	for i in range(segments + 1):
		var f := float(i) / float(segments)
		var p := from + span * f
		if i > 0 and i < segments:
			var bend := sin(f * PI) * jitter * span.length() * 0.25
			p += side_a * _rng.randf_range(-1.0, 1.0) * bend + side_b * _rng.randf_range(-1.0, 1.0) * bend
		points.append(p)
	var core := Color(1, 1, 1, tint.a)
	for i in range(segments):
		var a := points[i]; var b := points[i + 1]
		var view := (eye - (a + b) * 0.5).normalized()
		var across := (b - a).cross(view).normalized() * width
		# A wide tinted glow and a thin white-hot core.
		for layer in [[across * 2.6, tint * Color(1, 1, 1, 0.45)], [across, core]]:
			var w: Vector3 = layer[0]; var c: Color = layer[1]
			_arc_mesh.surface_set_color(c); _arc_mesh.surface_add_vertex(a - w)
			_arc_mesh.surface_set_color(c); _arc_mesh.surface_add_vertex(a + w)
			_arc_mesh.surface_set_color(c); _arc_mesh.surface_add_vertex(b + w)
			_arc_mesh.surface_set_color(c); _arc_mesh.surface_add_vertex(a - w)
			_arc_mesh.surface_set_color(c); _arc_mesh.surface_add_vertex(b + w)
			_arc_mesh.surface_set_color(c); _arc_mesh.surface_add_vertex(b - w)
