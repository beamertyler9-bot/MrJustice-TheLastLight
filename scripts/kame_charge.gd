extends Node3D
## The charging ball in Mr. Justice's palm before a beam: a white-hot orb in the shared
## energy look, a swirling aura around it and sparks spiralling inward, all swelling with
## the charge and throbbing once it is full.

const BODY = preload("res://shaders/magic/kame_beam.gdshader")
const GLOW = preload("res://shaders/magic/kame_glow.gdshader")
const MOTE = preload("res://shaders/magic/mote.gdshader")
const SPARKS := 10

var body_color := Color("2a98ff")
var core_color := Color("90efff")
var _core: MeshInstance3D
var _aura: MeshInstance3D
var _sparks: MultiMeshInstance3D
var _core_material: ShaderMaterial
var _aura_material: ShaderMaterial
var _clock := 0.0
var _element_material: ShaderMaterial


func _ready() -> void:
	name = "BeamCharge"
	var sphere := SphereMesh.new(); sphere.radius = 0.5; sphere.height = 1.0; sphere.radial_segments = 14; sphere.rings = 7
	_core_material = _material(BODY); _core_material.set_shader_parameter("wave", 0.0); _core_material.set_shader_parameter("tube", false)
	_aura_material = _material(GLOW); _aura_material.set_shader_parameter("turns", 1.0); _aura_material.set_shader_parameter("spiral", 1.0); _aura_material.set_shader_parameter("tube", false)
	_core = _part(sphere, _core_material)
	_aura = _part(sphere, _aura_material)
	var spark := SphereMesh.new(); spark.radius = 0.5; spark.height = 1.0; spark.radial_segments = 4; spark.rings = 2
	var spark_material := ShaderMaterial.new(); spark_material.shader = MOTE
	_sparks = MultiMeshInstance3D.new()
	_sparks.multimesh = MultiMesh.new(); _sparks.multimesh.transform_format = MultiMesh.TRANSFORM_3D; _sparks.multimesh.use_colors = true
	_sparks.multimesh.mesh = spark; _sparks.multimesh.instance_count = SPARKS
	_sparks.material_override = spark_material; _sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sparks)


## Spell charges grow a ball of the element itself (fire, water, lightning...) instead of
## plain energy, using the element core material from spell_presentation.
func use_element_core(material: ShaderMaterial) -> void:
	if _core == null: return
	_core.material_override = material if material != null else _core_material
	_element_material = material

## Recolour (spell charges use their element's colours; the hand beam keeps blue).
func set_colors(body: Color, core: Color) -> void:
	body_color = body; core_color = core
	if _core_material == null: return
	for material in [_core_material, _aura_material]:
		material.set_shader_parameter("body_color", body_color)
		material.set_shader_parameter("core_color", core_color)

func _material(shader: Shader) -> ShaderMaterial:
	var material := ShaderMaterial.new(); material.shader = shader
	material.set_shader_parameter("body_color", body_color)
	material.set_shader_parameter("core_color", core_color)
	return material


func _part(mesh: Mesh, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new(); part.mesh = mesh; part.material_override = material
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(part)
	return part


## charge: 0..1. full: the beam is fully charged.
func update_charge(dt: float, charge: float, full: bool, gentle: bool) -> void:
	_clock += dt
	var beat := 1.0 + (sin(_clock * (12.0 if gentle else 24.0)) * 0.13 if full else sin(_clock * 9.0) * 0.04)
	var size := lerpf(0.14, 0.5, charge) * beat
	_core.scale = Vector3.ONE * size
	_aura.scale = Vector3.ONE * size * 1.9
	_aura.rotation = Vector3(_clock * 1.7, _clock * 2.9, 0)
	for material in [_core_material, _aura_material]:
		material.set_shader_parameter("age", _clock)
		material.set_shader_parameter("opacity", lerpf(0.65, 1.0, charge))
		material.set_shader_parameter("low_flash", 1.0 if gentle else 0.0)
	_core_material.set_shader_parameter("brightness", 1.0 + (0.35 if full else charge * 0.15))
	if _element_material != null:
		_element_material.set_shader_parameter("age", _clock)
		_element_material.set_shader_parameter("opacity", 1.0)
		_element_material.set_shader_parameter("brightness", 1.0 + (0.3 if full else 0.0))
		_core.scale = Vector3.ONE * size * 1.25
	var tone := body_color.lerp(core_color, 0.45)
	for i in range(SPARKS):
		var seed := float(i) * 2.39996
		var fall := fposmod(_clock * 1.8 + float(i) / float(SPARKS), 1.0)
		var reach := lerpf(0.75, 0.05, fall) * (0.6 + charge * 0.6)
		var angle := seed + fall * 4.0
		var point := Vector3(cos(angle) * reach, sin(seed * 1.7) * reach * 0.6, sin(angle) * reach)
		var color := tone; color.a = smoothstep(0.0, 0.25, fall) * (1.0 - smoothstep(0.85, 1.0, fall))
		_sparks.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.035 * (1.0 - fall * 0.5)), point))
		_sparks.multimesh.set_instance_color(i, color)
