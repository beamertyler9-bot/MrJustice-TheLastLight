extends Node3D
## Small life around Mr. Justice in the open countryside:
##  - by day, butterflies flit about at knee to head height, wings beating, drifting and
##    turning as they go, in colours that suit the land;
##  - after dark they give way to fireflies that drift slowly and blink.
## One MultiMesh (a single draw call), only near the player, never indoors or in rain.

const COUNT := 16
const NEAR := 2.0
const FAR := 9.0
const WINGS := {9: ["#ffd25a", "#ffffff", "#f39a3c", "#9fd0ff"], 10: ["#ffc2e2", "#ffffff", "#d68be8"], 11: ["#ffe27a", "#ffffff", "#ff9f6b"],
	12: ["#f2c98a", "#fff1d0"], 13: ["#c9c3b6", "#a99f93"], 14: ["#b8b2e0", "#d8c6ff"], 15: ["#bfe9ff", "#e3d4ff", "#fff8ff"]}

var game
var daylight := 1.0
var biome := 9
var allowed := true
var art: MultiMeshInstance3D
var material: ShaderMaterial
var flyers: Array = []
var clock := 0.0
var _shown := 0.0


func setup(owner_game) -> void:
	game = owner_game
	name = "AmbientLife"
	art = MultiMeshInstance3D.new(); art.name = "Flyers"; art.top_level = true
	art.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true; mm.use_custom_data = true
	mm.mesh = _wing_mesh(); mm.instance_count = COUNT
	art.multimesh = mm
	material = ShaderMaterial.new(); material.shader = preload("res://shaders/flyer.gdshader")
	art.material_override = material
	add_child(art)
	art.custom_aabb = AABB(Vector3(-1.0e5, -1.0e4, -1.0e5), Vector3(2.0e5, 2.0e4, 2.0e5))
	for i in range(COUNT): flyers.append({"anchor": Vector3.INF, "phase": randf() * TAU, "speed": randf_range(0.7, 1.3), "color": Color.WHITE, "pos": Vector3.ZERO, "yaw": 0.0})


## Two wing quads hinged along the body (the Z axis).
static func _wing_mesh() -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		var a := Vector3(0, 0, -0.05); var b := Vector3(0, 0, 0.06)
		var c := Vector3(side * 0.11, 0, 0.09); var d := Vector3(side * 0.12, 0, -0.07)
		for p in [a, b, c, a, c, d]:
			st.set_normal(Vector3.UP); st.set_uv(Vector2(absf(p.x) / 0.12, (p.z + 0.07) / 0.16)); st.add_vertex(p)
	return st.commit()


func _process(dt: float) -> void:
	if game == null or game.player == null or art == null: return
	clock += dt
	var night := daylight < 0.35
	var land_ok: bool = allowed and (night or biome != 13)
	_shown = move_toward(_shown, 1.0 if land_ok else 0.0, dt * 0.5)
	art.visible = _shown > 0.01
	if not art.visible: return
	material.set_shader_parameter("night", night)
	material.set_shader_parameter("fade", _shown)
	var centre: Vector3 = game.player.global_position
	var palette: Array = WINGS.get(biome, WINGS[9])
	var world = game.world
	for i in range(COUNT):
		var f: Dictionary = flyers[i]
		var anchor: Vector3 = f.anchor
		if not anchor.is_finite() or Vector2(anchor.x - centre.x, anchor.z - centre.z).length() > FAR + 4.0:
			var angle := randf() * TAU; var reach := randf_range(NEAR, FAR)
			anchor = centre + Vector3(cos(angle), 0, sin(angle)) * reach
			anchor.y = world.height_at(anchor.x, anchor.z) if world != null else centre.y
			f.anchor = anchor; f.color = Color(palette[randi() % palette.size()]); f.pos = anchor
		# Wandering path: a looping drift around the anchor that rises and dips.
		var t := clock * float(f.speed) * (0.45 if night else 1.0) + float(f.phase)
		var height := (1.4 if night else 0.8) + sin(t * 1.3) * 0.35 + sin(t * 3.1) * 0.1
		var target := anchor + Vector3(sin(t * 0.7) * 2.2 + sin(t * 1.9) * 0.6, height, cos(t * 0.5) * 2.2 + cos(t * 2.3) * 0.5)
		var previous: Vector3 = f.pos
		f.pos = target
		var step := target - previous
		if Vector2(step.x, step.z).length() > 0.001: f.yaw = lerp_angle(float(f.yaw), atan2(step.x, step.z), 1.0 - exp(-dt * 6.0))
		var basis := Basis(Vector3.UP, float(f.yaw))
		art.multimesh.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * (1.0 if night else 2.0)), target))
		art.multimesh.set_instance_color(i, Color("#e8ff8a") if night else f.color)
		art.multimesh.set_instance_custom_data(i, Color(float(f.phase), float(f.speed), 0, 0))
