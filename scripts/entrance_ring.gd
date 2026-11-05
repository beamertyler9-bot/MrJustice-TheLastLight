extends Node3D


const RADIUS = 0.75
const BOB_HEIGHT = 0.018
const RIM_HEIGHT = 0.064
const CULL_DISTANCE = 85.0
static var trace_mesh: TorusMesh
static var rim_mesh: TorusMesh
static var trace_material: StandardMaterial3D
static var rim_material: StandardMaterial3D
var rim: MeshInstance3D
var phase = 0.0
var exact_ground = false

static func build_marker(marker: Node3D) -> void:
	marker.set_meta("ring_only", true)
	marker.add_to_group("batch_dynamic")
	if marker.get_node_or_null("EntranceRing") != null: return
	_shared_resources()
	var visual = load("res://scripts/entrance_ring.gd").new()
	visual.name = "EntranceRing"
	visual.add_to_group("batch_dynamic")
	visual.exact_ground = marker.has_meta("ring_ground_offset")
	visual.position.y = float(marker.get_meta("ring_ground_offset", -0.35))
	visual.phase = float(posmod(hash(str(marker.name)), 6283)) * 0.001
	var trace = _mesh("GroundTrace", trace_mesh, trace_material)
	trace.position.y = 0.018; visual.add_child(trace)
	visual.rim = _mesh("LuminousRim", rim_mesh, rim_material)
	visual.rim.position.y = RIM_HEIGHT; visual.add_child(visual.rim)
	marker.add_child(visual)

static func _shared_resources() -> void:
	if rim_mesh != null: return
	trace_mesh = TorusMesh.new(); trace_mesh.inner_radius = RADIUS - 0.018; trace_mesh.outer_radius = RADIUS + 0.018; trace_mesh.rings = 32; trace_mesh.ring_segments = 6
	rim_mesh = TorusMesh.new(); rim_mesh.inner_radius = RADIUS - 0.028; rim_mesh.outer_radius = RADIUS + 0.028; rim_mesh.rings = 40; rim_mesh.ring_segments = 8
	trace_material = _material(Color(0.42, 0.95, 0.62, 0.2), 0.3)
	rim_material = _material(Color(0.5, 1.0, 0.68, 0.42), 0.75)

static func _material(tint: Color, energy: float) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = tint
	material.emission_enabled = true; material.emission = Color(0.4, 1.0, 0.6); material.emission_energy_multiplier = energy
	material.roughness = 0.6
	return material

static func _mesh(title: String, shape: Mesh, material: Material) -> MeshInstance3D:
	var mesh = MeshInstance3D.new(); mesh.name = title; mesh.mesh = shape; mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.visibility_range_end = CULL_DISTANCE; mesh.visibility_range_end_margin = 8.0
	return mesh

func _ready() -> void:
	if not exact_ground: _request_support.call_deferred()

func _request_support() -> void:
	if not is_inside_tree() or is_queued_for_deletion(): return


	get_tree().physics_frame.connect(_snap_to_support, CONNECT_ONE_SHOT)

func _snap_to_support() -> void:

	if not is_inside_tree() or is_queued_for_deletion(): return
	var marker = get_parent() as Node3D
	var origin = marker.global_position
	var query = PhysicsRayQueryParameters3D.create(origin + Vector3.UP * 0.25, origin - Vector3.UP * 2.5, 1)
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.position.y <= origin.y + 0.02 and hit.normal.y > 0.55:
		position.y = marker.to_local(hit.position).y
		return
	var owner = marker.get_parent()
	while owner != null:
		if owner.has_method("surface_height_at"):
			var height: float = owner.surface_height_at(origin.x, origin.z)
			if height <= origin.y + 0.02 and height >= origin.y - 2.5:
				position.y = marker.to_local(Vector3(origin.x, height, origin.z)).y
			return
		owner = owner.get_parent()

func _process(dt: float) -> void:
	phase = fposmod(phase + dt * 0.75, TAU)
	var camera = get_viewport().get_camera_3d()
	if camera != null and camera.global_position.distance_squared_to(global_position) > CULL_DISTANCE * CULL_DISTANCE: return
	if rim != null: rim.position.y = RIM_HEIGHT + sin(phase) * BOB_HEIGHT
