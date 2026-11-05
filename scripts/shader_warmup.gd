extends Node3D
## Shader warm-up behind the loading screen.
##
## Phone GPU drivers compile a shader variant the first time it is drawn, which costs tens
## to hundreds of milliseconds each. Without this, the first walk into a forest (trees,
## ferns, flowers, distant canopy) or the first spell cast stalls the game for a moment.
## Here one tiny instance of every heavy world and magic material is drawn in front of the
## loading camera for a couple of frames, in the same forms the game uses (multimesh,
## shadow casting, vertex colours), so those compiles happen while the loading screen is up.

const Trees = preload("res://scripts/regional_trees.gd")
const Presentation = preload("res://scripts/spell_presentation.gd")

var _slot := 0


func build(game: Node, camera: Camera3D) -> void:
	name = "ShaderWarmup"
	if camera == null: return
	# Just in front of the lens and very small: drawn, never noticeable.
	global_transform = camera.global_transform.translated_local(Vector3(0, 0, -1.2))
	var world = game.get("world")
	for region in [9, 10, 11, 12, 13, 14, 15]:
		_try(func(): _multi(Trees.mesh(region), null, true))
		_try(func(): _multi(Trees.distant_mesh(region), null, false))
	if world != null:
		_try(func(): _multi(world.grass_mesh(), world.foliage_material("#5f8f45", true, 0.11), false))
		_try(func(): _multi(world.fern_mesh(), world.foliage_material("#418372", true, 0.055), false))
		_try(func(): _multi(world.flower_mesh(0), world.flower_material(), false))
		_try(func(): _multi(world.mushroom_mesh(0), world.flower_material(), false))
		_try(func(): _multi(world.leaf_mesh(), world.stone_material(false), true))
		_try(func(): _single(world.leaf_mesh(), world.stone_material(true), true))
	var magic = game.get("magic")
	var presentation = magic.get("presentation") if magic != null else null
	if presentation != null:
		var spell := {"element": "flame", "color": Color("ff7a2f"), "accent": Color("ffe7a8")}
		for shader in [Presentation.SURFACE, Presentation.FLAME, Presentation.ENERGY, Presentation.HALO, Presentation.LENS, Presentation.SEAL]:
			_try(func(): _single(presentation._mesh("quad"), presentation._material(shader, spell), false))
		_try(func(): _single(presentation._mesh("blade"), presentation._material(Presentation.SURFACE, spell), false))
		_try(func(): _single(presentation._mesh("core_sphere"), presentation._material(Presentation.CORE, spell), false))
		_try(func(): _single(presentation._mesh("shock_card"), presentation._material(Presentation.HALO, spell), false))
		for shader in [preload("res://shaders/magic/kame_beam.gdshader"), preload("res://shaders/magic/kame_glow.gdshader")]:
			var beam_material := ShaderMaterial.new(); beam_material.shader = shader
			var tube := CylinderMesh.new(); tube.radial_segments = 8; tube.rings = 2
			_try(func(): _single(tube, beam_material, false))
		var circle := ShaderMaterial.new(); circle.shader = preload("res://shaders/magic/magic_circle.gdshader")
		circle.set_shader_parameter("sheet", preload("res://assets/magic_circles/flame.png"))
		var card := QuadMesh.new()
		_try(func(): _single(card, circle, false))
		# Cave and dungeon surfaces: glowing crystals / mushrooms / lava, and the shared stone.
		var cave_glow := ShaderMaterial.new(); cave_glow.shader = preload("res://shaders/cave_glow.gdshader")
		_try(func(): _single(card, cave_glow, false))
		_try(func(): _multi(card, cave_glow, false))
		var cave_stone = preload("res://scripts/interior_architecture.gd").stone(9, false, false, true)
		_try(func(): _single(card, cave_stone, false))
		_try(func(): _multi(card, cave_stone, false))
		# Railgun lightning arcs (additive vertex-coloured ribbons).
		var arc_material := StandardMaterial3D.new()
		arc_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; arc_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		arc_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; arc_material.cull_mode = BaseMaterial3D.CULL_DISABLED; arc_material.vertex_color_use_as_albedo = true
		var ribbon := ImmediateMesh.new()
		ribbon.surface_begin(Mesh.PRIMITIVE_TRIANGLES, arc_material)
		for corner in [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0)]:
			ribbon.surface_set_color(Color(1, 1, 1, 0.01)); ribbon.surface_add_vertex(corner)
		ribbon.surface_end()
		_try(func(): _single(ribbon, arc_material, false))
		var motes := ShaderMaterial.new(); motes.shader = Presentation.MOTE
		_try(func(): _multi(presentation._mesh("spark"), motes, false, true))
		var smoke := ShaderMaterial.new(); smoke.shader = Presentation.SMOKE
		_try(func(): _multi(presentation._mesh("quad"), smoke, false, true, true))


func _try(step: Callable) -> void:
	step.call()


func _place() -> Transform3D:
	var column := _slot % 8; var row := _slot / 8
	_slot += 1
	return Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.01), Vector3((column - 3.5) * 0.02, (row - 2.0) * 0.02, 0))


func _multi(mesh: Mesh, material: Material, shadows: bool, colors := false, custom := false) -> void:
	if mesh == null: return
	var holder := MultiMeshInstance3D.new()
	holder.multimesh = MultiMesh.new()
	holder.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	holder.multimesh.use_colors = colors
	holder.multimesh.use_custom_data = custom
	holder.multimesh.mesh = mesh
	holder.multimesh.instance_count = 1
	holder.multimesh.set_instance_transform(0, Transform3D.IDENTITY)
	if colors: holder.multimesh.set_instance_color(0, Color(1, 1, 1, 0.01))
	holder.material_override = material
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.transform = _place()
	add_child(holder)


func _single(mesh: Mesh, material: Material, shadows: bool) -> void:
	if mesh == null: return
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.material_override = material
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	piece.transform = _place()
	add_child(piece)
