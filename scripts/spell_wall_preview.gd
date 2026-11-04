extends Node3D

const Book = preload("res://scripts/spellbook.gd")
var runtime
var valid := false
var outline: MeshInstance3D
var caption: Label3D
var _ink: StandardMaterial3D
var _size := Vector3.ZERO
func setup(owner_runtime) -> void:
	runtime = owner_runtime; name = "SpellWallFootprint"
	_ink = StandardMaterial3D.new(); _ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ink.emission_enabled = true; _ink.cull_mode = BaseMaterial3D.CULL_DISABLED
	outline = MeshInstance3D.new(); outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	outline.material_override = _ink; add_child(outline)
	caption = Label3D.new(); caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	caption.font_size = 42; caption.pixel_size = 0.003; caption.outline_size = 9; add_child(caption)
	visible = false
func update_spell(raw: Dictionary, target: Vector3, enabled: bool = true) -> Dictionary:
	var spell := Book.sanitize(raw)
	if not enabled or spell.is_empty() or spell.form != "wall" or not is_instance_valid(runtime): visible = false; return {}
	var solution: Dictionary = runtime.weave.wall_solution(spell, runtime._origin(), target)
	valid = bool(solution.valid); global_transform = solution.transform
	var size: Vector3 = solution.shape.size
	if not _size.is_equal_approx(size): _build(size)
	var color := Color("#78f6a1") if valid else Color("#ff665e")
	_ink.albedo_color = color; _ink.emission = color * 0.25
	caption.modulate = color; caption.text = str(solution.reason); caption.position = Vector3(0, size.y * 0.5 + 0.18, 0)
	visible = true; return solution
func _build(size: Vector3) -> void:
	_size = size; var half := size * 0.5
	var points: Array[Vector3] = []
	for y in [-half.y, half.y]:
		var corners := [Vector3(-half.x, y, -half.z), Vector3(half.x, y, -half.z), Vector3(half.x, y, half.z), Vector3(-half.x, y, half.z)]
		for i in range(4): points.append(corners[i]); points.append(corners[(i + 1) % 4])
	for x in [-half.x, half.x]:
		for z in [-half.z, half.z]: points.append(Vector3(x, -half.y, z)); points.append(Vector3(x, half.y, z))
	var wire := ImmediateMesh.new(); wire.surface_begin(Mesh.PRIMITIVE_LINES)
	for point in points: wire.surface_add_vertex(point)
	wire.surface_end(); outline.mesh = wire
