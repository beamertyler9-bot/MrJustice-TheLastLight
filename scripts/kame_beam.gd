extends Node3D
## Kamehameha-style beam: a column of light that bursts out of the hands, races to the
## target, holds with travelling bulges, streaks and a spiralling aura, then thins away.
##
## One renderer for every beam in the game (Mr. Justice's hand beam and every beam spell),
## built from the shared energy look in shaders/magic/toon_magic.gdshaderinc.

const BODY = preload("res://shaders/magic/kame_beam.gdshader")
const GLOW = preload("res://shaders/magic/kame_glow.gdshader")
const MOTE = preload("res://shaders/magic/mote.gdshader")
const GROW_TIME := 0.12
const SPARKS := 14

var start := Vector3.ZERO
var end := Vector3.FORWARD
var radius := 0.3
var life := 0.6
var age := 0.0
var low_flash := false
var body_color := Color("3fc8ff")
var core_color := Color("e8fbff")
var muzzle_scale := 1.7
## Void beams: black heart, glowing edge.
var dark_core := false
var _body_override: Material

var _pivot: Node3D
var _body: MeshInstance3D
var _sheath: MeshInstance3D
var _inner: MeshInstance3D
var _muzzle: MeshInstance3D
var _head: MeshInstance3D
var _sparks: MultiMeshInstance3D
var _materials: Array[ShaderMaterial] = []
var _orb_materials: Array[ShaderMaterial] = []
var _length := 1.0
var _orbs := true

static var _sphere: SphereMesh
static var _spark_mesh: SphereMesh


## Spawns a beam under `parent` (world space). `radius` is the beam's core radius in metres.
static func spawn(parent: Node, from: Vector3, to: Vector3, body: Color, core: Color, beam_radius: float, duration: float, gentle: bool = false, muzzle_scale: float = 1.7) -> Node3D:
	if parent == null or not parent.is_inside_tree() or not from.is_finite() or not to.is_finite() or from.distance_squared_to(to) < 1.0e-4: return null
	var beam = load("res://scripts/kame_beam.gd").new()
	beam.start = from; beam.end = to; beam.body_color = body; beam.core_color = core
	beam.radius = clampf(beam_radius, 0.015, 1.2); beam.life = clampf(duration, 0.12, 8.0); beam.low_flash = gentle; beam.muzzle_scale = muzzle_scale
	parent.add_child(beam)
	return beam


func _ready() -> void:
	name = "KameBeam"
	top_level = true
	global_transform = Transform3D.IDENTITY
	if _sphere == null:
		_sphere = SphereMesh.new(); _sphere.radius = 0.5; _sphere.height = 1.0; _sphere.radial_segments = 16; _sphere.rings = 8
		_spark_mesh = SphereMesh.new(); _spark_mesh.radius = 0.5; _spark_mesh.height = 1.0; _spark_mesh.radial_segments = 4; _spark_mesh.rings = 2
	var delta := end - start
	_length = delta.length()
	_orbs = radius >= 0.06
	# Pivot sits at the hands with +Y pointing down the beam; scaling it along Y "grows" the beam.
	_pivot = Node3D.new(); add_child(_pivot)
	_pivot.global_transform = Transform3D(_basis_along(delta.normalized()), start)
	var tube := CylinderMesh.new()
	tube.top_radius = 1.0; tube.bottom_radius = 1.0; tube.height = _length
	tube.radial_segments = 14 if radius > 0.1 else 8
	tube.rings = clampi(int(_length * 2.5), 2, 48)
	tube.cap_top = false; tube.cap_bottom = false
	_body = _part(tube, _material(BODY, {"wave": 1.0 if radius > 0.08 else 0.35, "length_m": _length}))
	_body.position = Vector3(0, _length * 0.5, 0)
	if _body_override != null: _body.material_override = _body_override
	_body.scale = Vector3(radius, 1, radius)
	_pivot.add_child(_body)
	_sheath = _part(tube, _material(GLOW, {"turns": maxf(1.0, _length * 0.45), "spiral": 1.0 if radius > 0.08 else 0.0}))
	_sheath.position = _body.position
	_pivot.add_child(_sheath)
	if _orbs:
		_muzzle = _part(_sphere, _material(BODY, {"wave": 0.0, "tube": false}, true))
		add_child(_muzzle)
		_head = _part(_sphere, _material(BODY, {"wave": 0.0, "tube": false}, true))
		add_child(_head)
		var spark_material := ShaderMaterial.new(); spark_material.shader = MOTE
		_sparks = MultiMeshInstance3D.new()
		_sparks.multimesh = MultiMesh.new(); _sparks.multimesh.transform_format = MultiMesh.TRANSFORM_3D; _sparks.multimesh.use_colors = true
		_sparks.multimesh.mesh = _spark_mesh; _sparks.multimesh.instance_count = SPARKS
		_sparks.material_override = spark_material; _sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_sparks)
	_update()


## Replace the beam's surface (water beams wear the sloshing water material).
func set_body_material(material: Material) -> void:
	_body_override = material
	if _body != null: _body.material_override = material
	# A solid inner column under the replacement surface, so a see-through surface (water)
	# still reads as a full beam when you look straight down it.
	if _body != null and _inner == null:
		_inner = _part(_body.mesh, _material(BODY, {"wave": 0.0, "length_m": _length}))
		_inner.position = _body.position
		_pivot.add_child(_inner)
		_update()

func _basis_along(direction: Vector3) -> Basis:
	var y := direction
	var x := y.cross(Vector3.UP)
	if x.length_squared() < 1.0e-4: x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


func _part(mesh: Mesh, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh; part.material_override = material
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	part.extra_cull_margin = 2.0
	return part


func _material(shader: Shader, extra: Dictionary, orb := false) -> ShaderMaterial:
	var material := ShaderMaterial.new(); material.shader = shader
	material.set_shader_parameter("body_color", body_color)
	material.set_shader_parameter("core_color", core_color)
	material.set_shader_parameter("low_flash", 1.0 if low_flash else 0.0)
	for key in extra: material.set_shader_parameter(key, extra[key])
	_materials.append(material)
	if orb: _orb_materials.append(material)
	return material


func _process(dt: float) -> void:
	age += dt
	if age >= life:
		queue_free(); return
	_update()


func _update() -> void:
	var grow := clampf(age / GROW_TIME, 0.0, 1.0)
	grow = 1.0 - pow(1.0 - grow, 3.0)
	var fade_start := life * 0.68
	var fade := clampf((age - fade_start) / maxf(life - fade_start, 0.01), 0.0, 1.0)
	var thickness := (1.0 - fade * fade) * (1.0 + (1.0 - grow) * 0.35)
	var opacity := 1.0 - smoothstep(0.55, 1.0, fade)
	for material in _materials:
		material.set_shader_parameter("age", age)
		material.set_shader_parameter("opacity", opacity)
		if dark_core: material.set_shader_parameter("dark_core", 1.0)
	if _body_override is ShaderMaterial:
		_body_override.set_shader_parameter("age", age)
		_body_override.set_shader_parameter("opacity", opacity)
		_body_override.set_shader_parameter("brightness", 1.1)
	_pivot.scale = Vector3(1, maxf(grow, 0.001), 1)
	_body.scale = Vector3(radius * thickness, 1, radius * thickness)
	if _inner != null: _inner.scale = Vector3(radius * thickness * 0.6, 1, radius * thickness * 0.6)
	_sheath.scale = Vector3(radius * thickness * 1.75, 1, radius * thickness * 1.75)
	if not _orbs: return
	var direction := (end - start) / maxf(_length, 0.001)
	var beat := 1.0 + sin(age * (14.0 if low_flash else 30.0)) * 0.06
	_muzzle.global_position = start
	_muzzle.scale = Vector3.ONE * radius * muzzle_scale * thickness * beat
	_head.global_position = start + direction * _length * grow
	_head.scale = Vector3.ONE * radius * (3.6 - grow * 0.6) * thickness * beat
	# Sparks race down the beam just outside its surface.
	var side := _pivot.global_basis.x; var up := _pivot.global_basis.z
	var tone := body_color.lerp(core_color, 0.5)
	for i in range(SPARKS):
		var seed := float(i) * 2.39996
		var run := fposmod(age * 1.6 + float(i) / float(SPARKS), 1.0) * grow
		var spin := seed + age * 9.0
		var offset := (side * cos(spin) + up * sin(spin)) * radius * thickness * (1.25 + 0.4 * sin(seed * 3.1))
		var point := start + direction * _length * run + offset
		var size := radius * 0.22 * (1.0 - run * 0.4) * thickness
		_sparks.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * maxf(size, 0.001)), point))
		var color := tone; color.a = opacity * 0.9
		_sparks.multimesh.set_instance_color(i, color)
