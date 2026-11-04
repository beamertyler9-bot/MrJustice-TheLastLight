extends RefCounted

static var sphere: SphereMesh
static var gold: StandardMaterial3D
const GLOW = preload("res://assets/items/light-essence.svg")
static func build(parent: Node3D) -> Node3D:
	var root = Node3D.new(); root.name = "LightEssence"; root.set_meta("item_model", "shard"); parent.add_child(root)
	if sphere == null:
		sphere = SphereMesh.new(); sphere.radius = 0.105; sphere.height = 0.21; sphere.radial_segments = 16; sphere.rings = 8
		gold = StandardMaterial3D.new(); gold.albedo_color = Color("#ffd260"); gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gold.emission_enabled = true; gold.emission = Color("#ffbd3f"); gold.emission_energy_multiplier = 2.5
	var ball = MeshInstance3D.new(); ball.name = "GoldenCore"; ball.mesh = sphere; ball.material_override = gold; ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; ball.position.y = 0.1; root.add_child(ball)
	var halo = Sprite3D.new(); halo.name = "SoftGoldenGlow"; halo.texture = GLOW; halo.pixel_size = 0.0028; halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED; halo.shaded = false; halo.no_depth_test = false; halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; halo.position.y = 0.1; root.add_child(halo)
	return root
