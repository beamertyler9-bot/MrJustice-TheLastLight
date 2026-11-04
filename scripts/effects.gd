extends Node3D

const B = preload("res://scripts/build.gd")
var bursts: Array = []
var speck_mesh: SphereMesh
var active_tweens: Array[Tween] = []
var _swing_pool: Array[Dictionary] = []
var _swing_meshes: Dictionary = {}
const SWING_POOL_LIMIT: int = 6
var preferences: Dictionary = {}
var _stamp_pool: Array[Dictionary] = []
var _stamp_textures: Dictionary = {}
var _feedback_tweens: Array[Tween] = []

func configure(settings: Dictionary) -> void:
	preferences = settings
	if bool(settings.get("low_flash", false)) or not bool(settings.get("ui_motion", true)): suspend_feedback()
	var limit = [6, 12, 18][clampi(int(settings.get("quality", 1)), 0, 2)]
	while _stamp_pool.size() > limit:
		var slot = _stamp_pool.pop_back()
		if is_instance_valid(slot.node): slot.node.queue_free()

func suspend_feedback() -> void:
	for slot in _stamp_pool:
		slot.node.hide(); slot.age = slot.life
	for slot in _swing_pool:
		slot.node.hide(); slot.age = slot.life
	for data in bursts:
		if is_instance_valid(data.node): data.node.queue_free()
	bursts.clear()
	for tween in _feedback_tweens:
		if tween.is_valid(): tween.kill()
	_feedback_tweens.clear()
	for node in get_children():
		if bool(node.get_meta("feedback_transient", false)): node.queue_free()

func _stamp(kind: String, pos: Vector3, color: Color, size: float, life: float, angle: float = 0) -> void:
	if kind in ["hit", "slash"] and (bool(preferences.get("low_flash", false)) or not bool(preferences.get("ui_motion", true))): return
	var limit = [6, 12, 18][clampi(int(preferences.get("quality", 1)), 0, 2)]
	var slot: Dictionary = {}
	for candidate in _stamp_pool:
		if not candidate.node.visible: slot = candidate; break
	if slot.is_empty() and _stamp_pool.size() >= limit:
		slot = _stamp_pool[0]
		for candidate in _stamp_pool:
			if candidate.age > slot.age: slot = candidate
	if slot.is_empty():
		var node = Sprite3D.new(); node.name = "PooledVFX"; node.shaded = false; node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(node); slot = {"node": node, "age": 0.0, "life": life, "frames": 1, "kind": kind, "origin": pos, "color": color}; _stamp_pool.append(slot)
	if not _stamp_textures.has(kind):
		var file = {"hit": "impact", "slash": "slash", "dust": "dust", "ripple": "ripple"}.get(kind, "dust")
		_stamp_textures[kind] = load("res://assets/imported/vfx/" + file + ".png")
	slot.kind = kind; slot.age = 0; slot.life = maxf(0.05, life); slot.origin = pos; slot.color = color
	var sprite: Sprite3D = slot.node; sprite.texture = _stamp_textures[kind]
	if kind == "hit":
		if not slot.has("hit_material"):
			var mat = ShaderMaterial.new(); mat.shader = preload("res://shaders/overhaul_hit.gdshader")
			mat.set_meta("source_pack", "HitFXFree"); mat.set_shader_parameter("impact_texture", _stamp_textures[kind]); slot.hit_material = mat
		slot.hit_material.set_shader_parameter("progress", 0.0); sprite.material_override = slot.hit_material
	else: sprite.material_override = null
	sprite.hframes = 6 if kind == "hit" else 1; sprite.vframes = 5 if kind == "hit" else 1; slot.frames = sprite.hframes * sprite.vframes; sprite.frame = 0
	sprite.pixel_size = size / (float(sprite.texture.get_width()) / sprite.hframes)
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED if kind == "ripple" else BaseMaterial3D.BILLBOARD_ENABLED
	sprite.rotation = Vector3(-PI * 0.5, 0, 0) if kind == "ripple" else Vector3(0, 0, angle)
	sprite.modulate = color; sprite.modulate.a = 0.42 if kind in ["dust", "ripple"] else 0.62
	sprite.position = pos; sprite.scale = Vector3.ONE; sprite.show()

func footfall(pos: Vector3, water_contact: bool, strength: float) -> void:
	burst(pos + Vector3.UP * 0.12, Color("#99cbc9") if water_contact else Color("#b3b38c"), 4, 0.35 + strength * 0.25)
	_stamp("ripple" if water_contact else "dust", pos + Vector3.UP * (0.025 if water_contact else 0.12), Color("#a5d7d8") if water_contact else Color("#d0bd97"), 0.7 + strength * 0.55, 0.48)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	speck_mesh = SphereMesh.new()
	speck_mesh.radial_segments = 6
	speck_mesh.rings = 3
	speck_mesh.radius = 0.5
	speck_mesh.height = 1.0

func _process(dt: float) -> void:
	for i in range(_feedback_tweens.size() - 1, -1, -1):
		if not _feedback_tweens[i].is_valid(): _feedback_tweens.remove_at(i)
	for slot in _stamp_pool:
		if not slot.node.visible: continue
		slot.age += dt
		var progress = clampf(slot.age / slot.life, 0, 1)
		if slot.kind == "hit" and slot.has("hit_material"): slot.hit_material.set_shader_parameter("progress", progress)
		slot.node.visible = progress < 1
		slot.node.frame = mini(slot.frames - 1, floori(progress * slot.frames))
		slot.node.modulate.a = (0.42 if slot.kind in ["dust", "ripple"] else 0.62) * pow(1 - progress, 0.7)
		slot.node.scale = Vector3.ONE * lerpf(0.85, 1.2, progress)
		if slot.kind == "dust": slot.node.position = slot.origin + Vector3.UP * progress * 0.13
	for swing_data in _swing_pool:
		if not swing_data.node.visible:
			continue
		swing_data.age += dt
		var progress = clampf(swing_data.age / swing_data.life, 0.0, 1.0)
		swing_data.node.visible = progress < 1.0
		swing_data.material.albedo_color.a = (1.0 - progress) * float(swing_data.get("opacity", 0.58))
		swing_data.node.scale = Vector3.ONE * lerpf(0.93, 1.16, progress)
	for i in range(active_tweens.size() - 1, -1, -1):
		if not active_tweens[i].is_valid():
			active_tweens.remove_at(i)
	for i in range(bursts.size() - 1, -1, -1):
		var data = bursts[i]
		data.age += dt
		if not is_instance_valid(data.node) or data.age >= data.life:
			if is_instance_valid(data.node):
				data.node.queue_free()
			bursts.remove_at(i)
			continue
		var age: float = data.age
		var fade = pow(maxf(0, 1.0 - age / data.life), 0.65)
		for j in range(data.velocities.size()):
			var pos: Vector3 = data.velocities[j] * age + Vector3.DOWN * age * age * data.gravity
			var scale_value: float = data.sizes[j] * fade
			data.node.multimesh.set_instance_transform(j, Transform3D(Basis.from_scale(Vector3.ONE * scale_value), pos))

func burst(pos: Vector3, color: Color, count: int = 9, strength: float = 1.0) -> void:
	if speck_mesh == null:
		return
	if bursts.size() > 22:
		var old = bursts.pop_front()
		if is_instance_valid(old.node):
			old.node.queue_free()
	var node = MultiMeshInstance3D.new()
	node.position = pos
	node.multimesh = MultiMesh.new()
	node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	node.multimesh.mesh = speck_mesh
	node.multimesh.instance_count = count
	node.material_override = B.mat(color.to_html(false), 0.0, 0.75)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	var velocities: Array[Vector3] = []
	var sizes: Array[float] = []
	for i in range(count):
		var angle = float(i) * TAU / maxf(count, 1) + randf_range(-0.2, 0.2)
		velocities.append(Vector3(cos(angle) * randf_range(0.6, 2.1), randf_range(0.5, 2.6), sin(angle) * randf_range(0.6, 2.1)) * strength)
		sizes.append(randf_range(0.07, 0.18) * strength)
		node.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * sizes[i]), Vector3.ZERO))
	bursts.append({"node": node, "velocities": velocities, "sizes": sizes, "age": 0.0, "life": 0.55 if count < 16 else 0.9, "gravity": 1.5})
	if count >= 6: _stamp("hit", pos, color, 1.0 if count < 16 else 1.65, 0.32)
	if count >= 16:
		ring(pos, color, 2.5, 0.85)

func ring(pos: Vector3, color: Color, radius: float = 1.0, duration: float = 0.45) -> void:
	var material = B.mat(color.to_html(false), 0, 0.7).duplicate()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.7
	var node = B.ring(self, pos, 0.5, 0.018, material)
	node.set_meta("feedback_transient", true)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tween = create_tween().set_parallel()
	active_tweens.append(tween)
	_feedback_tweens.append(tween)
	tween.tween_property(node, "scale", Vector3.ONE * radius * 2, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, duration)
	tween.chain().tween_callback(node.queue_free)

func beam(start: Vector3, end: Vector3, color: Color, width: float, duration: float) -> MeshInstance3D:
	var material = B.mat(color.to_html(false), 0, 0.9).duplicate()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.45
	var node = cylinder_between(start, end, width, material)
	node.set_meta("feedback_transient", true)
	var core = CylinderMesh.new()
	core.top_radius = width * 0.28
	core.bottom_radius = width * 0.28
	core.height = node.mesh.height
	core.radial_segments = 8
	B.mesh(node, core, B.mat("#eafff5", 0, 1.2)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tween = create_tween()
	active_tweens.append(tween)
	_feedback_tweens.append(tween)
	tween.tween_interval(maxf(0.05, duration - 0.14))
	tween.tween_property(node, "scale", Vector3(0.01, 1, 0.01), 0.14).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(node.queue_free)
	burst(end, color, 10, 0.75)
	var flash = B.ball(self, start, Vector3.ONE * 0.32, B.mat("#c6fff2", 0, 0.8))
	flash.set_meta("feedback_transient", true)
	var flash_tween = create_tween()
	active_tweens.append(flash_tween)
	_feedback_tweens.append(flash_tween)
	flash_tween.tween_property(flash, "scale", Vector3.ZERO, 0.2)
	flash_tween.tween_callback(flash.queue_free)
	return node

func rope(start: Vector3, end: Vector3) -> MeshInstance3D:
	return cylinder_between(start, end, 0.028, B.mat("#c6b78d", 0.55, 0.15))

func cylinder_between(start: Vector3, end: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var shape = CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = maxf(0.01, start.distance_to(end))
	shape.radial_segments = 8
	var node = B.mesh(self, shape, material, (start + end) * 0.5)
	node.quaternion = Quaternion(Vector3.UP, (end - start).normalized())
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node



func swing(pos: Vector3, direction: Vector3, variant: int) -> void:
	variant = posmod(variant, 3)
	var slot: Dictionary = {}
	for available in _swing_pool:
		if not available.node.visible:
			slot = available
			break
	if slot.is_empty() and _swing_pool.size() >= SWING_POOL_LIMIT:
		slot = _swing_pool[0]
		for available in _swing_pool:
			if available.age > slot.age:
				slot = available
	if slot.is_empty():
		var material = B.mat("#fff0c4", 0, 0.6).duplicate()
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_texture = preload("res://assets/imported/vfx/slash.png")
		var node = MeshInstance3D.new()
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		slot = {"node": node, "material": material, "age": 0.0, "life": 0.18}
		_swing_pool.append(slot)
	if not _swing_meshes.has(variant):
		_swing_meshes[variant] = _swing_mesh(variant)
	slot.node.mesh = _swing_meshes[variant]
	slot.node.position = pos + Vector3.UP * 1.05
	slot.node.rotation = Vector3(0, atan2(-direction.x, -direction.z), 0)
	slot.node.scale = Vector3.ONE * 0.93
	slot.node.visible = true
	slot.age = 0.0
	slot.life = 0.22 if variant == 2 else 0.17
	slot.opacity = 0.16 if bool(preferences.get("low_flash", false)) or not bool(preferences.get("ui_motion", true)) else 0.58
	slot.material.albedo_color.a = slot.opacity

func _swing_mesh(variant: int) -> ArrayMesh:
	var vertices = PackedVector3Array()
	var indices = PackedInt32Array()
	var uvs = PackedVector2Array()
	for i in range(17):
		var t = float(i) / 16.0
		var angle = lerpf(-1.42, 1.42, t) if variant == 2 else lerpf(-0.58, 0.58, t)
		var ribbon = pow(maxf(0.0, sin(t * PI)), 0.65) * (0.16 if variant == 2 else 0.1)
		for radius in [0.92 - ribbon * 0.5, 0.92 + ribbon * 0.5]:
			var side = -1.0 if variant == 1 else 1.0
			vertices.append(Vector3(sin(angle) * radius * side, sin(angle) * (0.28 if variant == 2 else -0.08 * side), -cos(angle) * radius))
			uvs.append(Vector2(t, 0 if radius < 0.92 else 1))
	for i in range(16):
		var j = i * 2
		indices.append_array(PackedInt32Array([j, j + 1, j + 2, j + 1, j + 3, j + 2]))
	var data = []
	data.resize(Mesh.ARRAY_MAX)
	data[Mesh.ARRAY_VERTEX] = vertices
	data[Mesh.ARRAY_INDEX] = indices
	data[Mesh.ARRAY_TEX_UV] = uvs
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data)
	return mesh

func clear_effects() -> void:
	for tween in active_tweens:
		if tween.is_valid():
			tween.kill()
	active_tweens.clear()
	_feedback_tweens.clear()
	_swing_pool.clear()
	_stamp_pool.clear()
	bursts.clear()
	for node in get_children():
		if not node.is_queued_for_deletion():
			node.queue_free()
