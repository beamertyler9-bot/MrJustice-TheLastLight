extends Node3D

const B = preload("res://scripts/build.gd")
const TRAIL_COUNT := 32
var hero
var wings: Array[Node3D] = []
var fans: Array[Node3D] = []
var tips: Array[Node3D] = []
var halo: Node3D
var wake: MultiMeshInstance3D
var burst: MeshInstance3D
var paint: ShaderMaterial
var glow: StandardMaterial3D
var age := 0.0
var spread := 0.0
var emit_clock := 0.0
var trail_cursor := 0
var trails: Array[Dictionary] = []
var low_flash := false
var flap_phase := 0.0
var power_blend := 0.0
var boost_blend := 0.0
var boost_circle: MeshInstance3D
var circle_paint: StandardMaterial3D
var shock_paint: StandardMaterial3D
var boost_age := 9.0
var _boost_forward := Vector3.FORWARD
var _boost_origin := Vector3.ZERO
var _boost_released := false
static var _wing_meshes: Array[ArrayMesh] = []
static var _boost_mesh: ArrayMesh

func setup(context) -> void:
	hero = context
	name = "SeraphWings"
	paint = ShaderMaterial.new()
	paint.shader = preload("res://shaders/seraph_light.gdshader")
	if _wing_meshes.is_empty():
		_wing_meshes = [_wing_mesh(false), _wing_mesh(true)]
		_wing_meshes.append(_mirror_mesh(_wing_meshes[0]))
		_wing_meshes.append(_mirror_mesh(_wing_meshes[1]))
	for side in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.name = "LeftWingSocket" if side < 0 else "RightWingSocket"
		shoulder.position = Vector3(side * 0.255, 1.7 - hero.TORSO_PIVOT, 0.19)
		add_child(shoulder)
		var wing := Node3D.new(); shoulder.add_child(wing)
		wings.append(wing)
		_art(wing, _wing_meshes[2 if side < 0 else 0])
		var fan := Node3D.new(); fan.position = Vector3(side * 1.4, 0.63, 0.04); wing.add_child(fan)
		fans.append(fan); _art(fan, _wing_meshes[3 if side < 0 else 1])
		var tip := Node3D.new(); tip.position = Vector3(side * 1.68, 1.68, 0.15); fan.add_child(tip); tips.append(tip)
	halo = Node3D.new(); halo.name = "SeraphHalo"; add_child(halo)
	var ring := TorusMesh.new(); ring.inner_radius = 0.44; ring.outer_radius = 0.49; ring.rings = 48; ring.ring_segments = 6
	var gold := StandardMaterial3D.new(); gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gold.albedo_color = Color("#ffe5a0"); gold.emission_enabled = true; gold.emission = Color("#ffd379"); gold.emission_energy_multiplier = 1.3
	var inner := _art(halo, ring); inner.material_override = gold
	var aura := TorusMesh.new(); aura.inner_radius = 0.47; aura.outer_radius = 0.56; aura.rings = 48; aura.ring_segments = 4
	glow = StandardMaterial3D.new(); glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.albedo_color = Color(1.0, 0.76, 0.28, 0.18); glow.no_depth_test = false
	var outer := _art(halo, aura); outer.material_override = glow
	burst = _art(self, ring); burst.material_override = glow; burst.name = "TakeoffCorona"
	shock_paint = _pulse_paint(Color("#fff2ba"))
	burst.material_override = shock_paint; burst.top_level = true; burst.hide()
	if _boost_mesh == null: _boost_mesh = _magic_circle_mesh()
	boost_circle = _art(self, _boost_mesh); boost_circle.name = "BoostMagicCircle"; boost_circle.top_level = true
	circle_paint = _pulse_paint(Color("#ffdf8b")); circle_paint.vertex_color_use_as_albedo = true
	boost_circle.material_override = circle_paint; boost_circle.hide()
	wake = MultiMeshInstance3D.new(); wake.name = "LightFeatherWake"
	wake.multimesh = MultiMesh.new(); wake.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	wake.multimesh.use_colors = true; wake.multimesh.mesh = _trail_mesh()
	wake.multimesh.instance_count = TRAIL_COUNT
	var particles := StandardMaterial3D.new(); particles.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particles.vertex_color_use_as_albedo = true; particles.albedo_color = Color("#fff0bd")
	particles.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; particles.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	wake.material_override = particles; wake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wake); wake.top_level = true; wake.global_transform = Transform3D.IDENTITY
	for i in TRAIL_COUNT:
		trails.append({"age": 2.0, "point": Vector3.ZERO, "velocity": Vector3.ZERO, "spin": float(i) * 2.4})
		wake.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 1.0e-05), Vector3.ZERO))
	hide()

func _art(parent: Node3D, mesh: Mesh) -> MeshInstance3D:
	var result := MeshInstance3D.new(); result.mesh = mesh; result.material_override = paint
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(result)
	return result

static func _feather(tool: SurfaceTool, root: Vector3, tip: Vector3, width: float, shade: Color, birth := 0.0, bend := 0.065) -> void:
	var along := tip - root
	var across := Vector3(-along.y, along.x, 0).normalized()
	var rings: Array[PackedVector3Array] = []
	var samples := PackedFloat32Array([0.0, 0.16, 0.38, 0.62, 0.82, 0.94, 1.0])

	for j in range(7):
		var u := samples[j]
		var curve := sin(u * PI)
		var center := root + along * u + across * along.length() * bend * curve + Vector3(0, 0, -0.04 * curve)
		var vane := pow(maxf(0.0, curve), 0.5 if along.length() < 0.8 else 0.68) * width * (1.0 - u * 0.22)
		var depth := vane * 0.13
		rings.append(PackedVector3Array([center - across * vane * 0.82, center + Vector3(0, 0, -depth), center + across * vane, center + Vector3(0, 0, depth)]))
	for j in range(6):
		for face in range(4):
			var next := (face + 1) % 4
			var corners := [Vector2i(j, face), Vector2i(j + 1, face), Vector2i(j + 1, next), Vector2i(j, next)]
			for triangle in [[0, 1, 2], [0, 2, 3]]:
				for k in triangle:
					var entry: Vector2i = corners[k]
					var u := samples[entry.x]
					var across_uv: float = [0.0, 0.5, 1.0, 0.5][entry.y]
					var color := shade.lerp(Color("#f6fbff"), smoothstep(0.5, 1.0, u) * 0.55)
					if entry.y in [0, 2]: color = color.darkened(0.075)
					elif entry.y == 3: color = color.darkened(0.035)
					tool.set_custom(0, Color(root.x, root.y, root.z, birth))
					tool.set_color(color); tool.set_uv(Vector2(across_uv, u)); tool.add_vertex(rings[entry.x][entry.y])

static func _wing_mesh(outer: bool) -> ArrayMesh:
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	_leading_edge(tool, outer)
	if outer:

		for i in range(11):
			var t := float(i) / 10.0
			var root := Vector3(0.18 + t * 0.22, 0.09 - t * 0.28, 0.045)
			var tip := Vector3(1.68 - t * 1.02, 1.68 - t * 2.6 + sin(t * PI) * 0.2, 0.14 + t * 0.04)
			_feather(tool, root, tip, lerpf(0.13, 0.18, t), Color("#f0eee6").lightened(float(i % 3) * 0.025), 0.35 + t * 0.1, 0.085)
		for back in [false, true]:
			for i in range(9):
				var t := float(i) / 8.0
				var z := 0.12 if back else -0.09
				_feather(tool, Vector3(t * 0.4, 0.13 - t * 0.25, z), Vector3(0.67 + t * 0.12, 0.66 - t * 1.26, z - 0.025), 0.145, Color("#eee8d8"), 0.32 + t * 0.1)
	else:
		for i in range(13):
			var t := float(i) / 12.0
			var y := sin(t * PI * 0.5) * 0.63
			_feather(tool, Vector3(t * 1.42, y, 0.055), Vector3(0.16 + t * 1.55, -0.72 + t * 0.68 - sin(t * PI) * 0.13, 0.12), 0.18, Color("#ede9dd").lightened(float(i % 3) * 0.025), 0.18 + t * 0.12)
		for back in [false, true]:
			for row in range(2):
				for i in range(8):
					var t := clampf((float(i) + float(row) * 0.42) / 7.4, 0.0, 1.0)
					var y := sin(t * PI * 0.5) * 0.63 - float(row) * 0.17
					var z := (0.14 if back else -0.06) + float(row) * (0.025 if back else -0.025)
					_feather(tool, Vector3(t * 1.42, y, z), Vector3(0.12 + t * 1.46, y - 0.3 - float(row) * 0.07, z - 0.015), 0.17, Color("#f5f0e3"), 0.2 + float(row) * 0.1 + t * 0.08)
	tool.generate_normals()
	tool.index()
	return tool.commit()

static func _leading_edge(tool: SurfaceTool, outer: bool) -> void:

	var rings: Array[PackedVector3Array] = []
	for j in range(10):
		var t := float(j) / 9.0
		var center := Vector3(t * 0.43, sin(t * PI) * 0.06 - t * 0.15, t * 0.035) if outer else Vector3(t * 1.4, sin(t * PI * 0.5) * 0.63, 0.04)
		var radius := (0.16 if outer else lerpf(0.16, 0.105, t)) * pow(sin(PI * t), 0.32)
		var ring := PackedVector3Array()
		for k in range(8):
			var angle := TAU * float(k) / 8.0
			ring.append(center + Vector3(0, cos(angle) * radius, sin(angle) * radius * 0.85))
		rings.append(ring)
	for j in range(9):
		for k in range(8):
			var next := (k + 1) % 8
			for entry in [Vector2i(j, k), Vector2i(j + 1, k), Vector2i(j + 1, next), Vector2i(j, k), Vector2i(j + 1, next), Vector2i(j, next)]:
				tool.set_custom(0, Color(0, 0, 0, -2.0 if outer else -1.0))
				tool.set_color(Color("#eeeadd")); tool.set_uv(Vector2(float(entry.y) / 8.0, float(entry.x) / 9.0))
				tool.add_vertex(rings[entry.x][entry.y])

static func _trail_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	_feather(tool, Vector3(0, 0.5, 0), Vector3(0, -0.5, 0), 0.14, Color.WHITE)
	tool.generate_normals()
	return tool.commit()

static func _mirror_mesh(source: ArrayMesh) -> ArrayMesh:
	var a := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var roots: PackedFloat32Array = a[Mesh.ARRAY_CUSTOM0]
	for i in vertices.size(): vertices[i].x = -vertices[i].x; normals[i].x = -normals[i].x
	for i in range(0, roots.size(), 4): roots[i] = -roots[i]
	for i in range(0, indices.size(), 3):
		var swap := indices[i]; indices[i] = indices[i + 2]; indices[i + 2] = swap
	a[Mesh.ARRAY_VERTEX] = vertices; a[Mesh.ARRAY_NORMAL] = normals; a[Mesh.ARRAY_INDEX] = indices
	a[Mesh.ARRAY_CUSTOM0] = roots
	var result := ArrayMesh.new(); result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, source.surface_get_format(0))
	return result

func tick(dt: float, flying: bool, powered: bool, velocity: Vector3, reduced_flash: bool, flight_mode := "seraph_fly") -> void:
	if not is_finite(dt) or dt <= 0 or hero == null: return
	low_flash = reduced_flash
	var was_hidden := spread <= 0.001
	spread = move_toward(spread, 1.0 if flying else 0.0, dt * (1.0 / 1.05 if flying else 2.5))
	if spread <= 0.001:
		hide(); wake.hide(); boost_circle.hide(); burst.hide(); return
	if flying and was_hidden: age = 0.0; emit_clock = 0.0; flap_phase = 0.0; power_blend = 0.0
	show(); wake.show(); age += dt
	paint.set_shader_parameter("world_time", age)
	paint.set_shader_parameter("radiance", 0.45 if low_flash else 1.0)
	paint.set_shader_parameter("manifestation", spread)
	var unfurl := smoothstep(0.0, 1.0, spread)
	var shoulder_open := smoothstep(0.06, 0.74, spread)
	var fan_open := smoothstep(0.24, 0.95, spread)
	var hovering := flight_mode == "seraph_hover"
	boost_blend = move_toward(boost_blend, 1.0 if flight_mode == "seraph_boost" else 0.0, dt * 5.0)
	power_blend = move_toward(power_blend, 0.45 if hovering else (1.0 if powered else 0.0), dt * 3.0)
	if age > 0.75: flap_phase += dt * lerpf(1.6, 5.2, power_blend)
	var phase := flap_phase
	var flap := sin(phase) * smoothstep(0.55, 1.0, spread)
	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		var stroke := flap * lerpf(0.075, 0.46, power_blend) * (1.0 - boost_blend * 0.82)
		wings[i].rotation = Vector3(-0.06, side * (lerpf(-1.32, 0.06, shoulder_open) + stroke), side * lerpf(-0.62, 0.06 + (0.12 * flap if hovering else 0.0) - boost_blend * 0.32, shoulder_open))
		wings[i].scale = Vector3.ONE
		fans[i].rotation.y = side * lerpf(-0.22, lerpf(0.045, 0.22, power_blend) * sin(phase - 0.65), fan_open)
		fans[i].rotation.z = side * lerpf(-1.62, -0.4 - boost_blend * 0.55 + lerpf(0.02, 0.055, power_blend) * sin(phase - 0.8), fan_open)
	var halo_frame := Basis(Vector3.UP, hero.global_rotation.y)
	var halo_size: float = hero.MODEL_SCALE * smoothstep(0.04, 0.44, spread)


	var halo_point: Vector3 = hero.head.to_global(Vector3(0, 0.4075, 0)) + Vector3.UP * hero.MODEL_SCALE * 0.12
	halo.global_transform = Transform3D(halo_frame.scaled(Vector3.ONE * maxf(0.001, halo_size)), halo_point)
	glow.albedo_color = Color(1.0, 0.76, 0.28, (0.08 if low_flash else 0.18) * unfurl)
	burst.visible = flying and age < 0.85 and not low_flash
	if burst.visible:
		var frame: Transform3D = hero.torso.global_transform
		frame.origin = hero.torso.to_global(Vector3(0, 1.65 - hero.TORSO_PIVOT, 0.24))
		frame.basis = frame.basis * Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3.ONE * lerpf(0.2, 2.8, smoothstep(0.0, 0.85, age)))
		burst.global_transform = frame
		shock_paint.albedo_color = Color(1, 0.88, 0.58, 0.16 * (1.0 - age / 0.85))
	if not flying: boost_age = 9.0
	_tick_boost(dt)
	emit_clock += dt
	if flying and spread > 0.48 and emit_clock >= (0.1 if low_flash else 0.055):
		emit_clock = 0.0
		for tip in tips:
			var slot: Dictionary = trails[trail_cursor]
			slot.age = 0.0; slot.point = tip.global_position
			slot.velocity = -velocity * 0.08 + Vector3(sin(age * 4.2) * 0.2, -0.38, 0)
			trail_cursor = (trail_cursor + 1) % TRAIL_COUNT
	var bounds := AABB(hero.global_position - Vector3.ONE * 3, Vector3.ONE * 6)
	for i in TRAIL_COUNT:
		var slot: Dictionary = trails[i]; slot.age += dt
		if slot.age < 1.0:
			slot.point += slot.velocity * dt
			var basis := Basis.from_euler(Vector3(slot.age * 1.3, slot.spin, slot.age * 2.0 + slot.spin))
			var size: float = (0.13 if powered else 0.1) * sin(minf(1.0, slot.age / 0.08) * PI * 0.5) * (1.0 - slot.age)
			wake.multimesh.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * maxf(1.0e-05, size)), slot.point))
			wake.multimesh.set_instance_color(i, Color(1, 0.88, 0.56, (1.0 - slot.age) * unfurl))
			bounds = bounds.expand(slot.point)
		else:
			wake.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 1.0e-05), hero.global_position))
	wake.custom_aabb = bounds.grow(0.3)

func clear() -> void:
	spread = 0.0
	boost_age = 9.0
	boost_blend = 0.0
	for slot in trails: slot.age = 2.0
	hide()
	if is_instance_valid(wake): wake.hide()
	if is_instance_valid(boost_circle): boost_circle.hide()
	if is_instance_valid(burst): burst.hide()

func _pulse_paint(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	return material

func play_boost(direction: Vector3) -> void:
	if not direction.is_finite() or direction.length_squared() < 0.1: return
	_boost_forward = direction.normalized()
	_boost_origin = hero.head.global_position + _boost_forward * 0.7
	_boost_released = false
	boost_age = 0.0
	burst.hide()

func cancel_boost() -> void:
	boost_age = 9.0
	boost_circle.hide()
	burst.hide()

func _tick_boost(dt: float) -> void:
	if boost_age >= 1.0:
		boost_circle.hide()
		return
	boost_age += dt
	if not _boost_released:
		_boost_origin = hero.head.global_position + _boost_forward * 0.7
		if boost_age >= 0.14: _boost_released = true
	var frame := Basis(Quaternion(Vector3.BACK, _boost_forward)) * Basis(Vector3.BACK, boost_age * 1.2)
	var size: float = hero.MODEL_SCALE * 1.6 * smoothstep(0.0, 0.14, boost_age) * (1.0 + 0.45 * smoothstep(0.14, 0.55, boost_age))
	boost_circle.global_transform = Transform3D(frame.scaled(Vector3.ONE * maxf(0.001, size)), _boost_origin)
	boost_circle.visible = boost_age < 0.55
	var alpha := smoothstep(0.0, 0.07, boost_age) * (1.0 - smoothstep(0.25, 0.55, boost_age))
	circle_paint.albedo_color = Color(1, 0.88, 0.54, (0.16 if low_flash else 0.8) * alpha)
	burst.visible = boost_age >= 0.14 and boost_age < 0.85
	if burst.visible:
		var t := clampf((boost_age - 0.14) / 0.71, 0, 1)
		var radius: float = hero.MODEL_SCALE * lerpf(0.6, 12.0, 1.0 - pow(1.0 - t, 2))
		burst.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, _boost_forward)).scaled(Vector3.ONE * radius), _boost_origin)
		shock_paint.albedo_color = Color(1, 0.91, 0.68, (0.09 if low_flash else 0.32) * pow(1.0 - t, 2))

static func _magic_circle_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for radius in [0.65, 0.78, 1.0, 1.055]:
		for i in range(96):
			var a := TAU * float(i) / 96.0
			var b := TAU * float(i + 1) / 96.0
			_circle_line(tool, Vector3(cos(a), sin(a), 0) * radius, Vector3(cos(b), sin(b), 0) * radius, 0.009)
	for i in range(12):
		var angle := TAU * float(i) / 12.0
		var radial := Vector3(cos(angle), sin(angle), 0)
		var tangent := Vector3(-radial.y, radial.x, 0)
		var center := radial * 0.89
		_circle_line(tool, center - radial * 0.065, center + radial * 0.065, 0.012)
		_circle_line(tool, center - tangent * 0.035, center + tangent * 0.035 + radial * 0.025, 0.012)
		if i % 2 == 0: _circle_line(tool, center - radial * 0.04, center + tangent * 0.035, 0.009)
	for i in range(8):
		var angle := TAU * float(i) / 8.0
		var tip := Vector3(cos(angle), sin(angle), 0) * 0.55
		var left := Vector3(cos(angle + 0.35), sin(angle + 0.35), 0) * 0.16
		var right := Vector3(cos(angle - 0.35), sin(angle - 0.35), 0) * 0.16
		_circle_line(tool, left, tip, 0.015); _circle_line(tool, tip, right, 0.015)
	tool.index()
	return tool.commit()

static func _circle_line(tool: SurfaceTool, a: Vector3, b: Vector3, width: float) -> void:
	var d := b - a
	var side := Vector3(-d.y, d.x, 0).normalized() * width
	for point in [a - side, b - side, b + side, a - side, b + side, a + side]:
		tool.set_color(Color("#fff5d2")); tool.set_normal(Vector3.BACK); tool.add_vertex(point)
