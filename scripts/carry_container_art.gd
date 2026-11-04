extends RefCounted

const Art = preload("res://scripts/cast_art.gd")
const Imported = preload("res://scripts/imported_assets.gd")
const ASSET := "p32_pirate_barrel"
static func build(parent: Node3D) -> Node3D:
	var art = Imported.place(parent, ASSET, Vector3(0, -0.35, 0), 0.7)
	assert(art != null, "The supplied replacement barrel must be available")


	var source: Mesh = Imported.mesh(ASSET)
	var bounds = source.get_aabb()
	art.scale = Vector3(0.7 / bounds.size.x, 0.7 / bounds.size.y, 0.7 / bounds.size.z)
	art.position = -bounds.get_center() * art.scale
	for mesh in art.find_children("*", "GeometryInstance3D", true, false):
		mesh.visibility_range_end = 0.0
		mesh.remove_from_group("imported_detail")


	var loops = Node3D.new(); loops.name = "RopeLiftingLoops"; loops.scale.x = 0.985; parent.add_child(loops)
	var rope = Art.material("cloth", Color("#8d7952"))
	for side in [-1.0, 1.0]:
		Art.tube(loops, PackedVector3Array([
			Vector3(side * 0.17, 0.025, 0.27), Vector3(side * 0.195, -0.048, 0.342),
			Vector3(side * 0.325, -0.055, 0.342), Vector3(side * 0.34, -0.155, 0.343),
			Vector3(side * 0.34, -0.29, 0.343), Vector3(side * 0.34, -0.33, 0.34),
			Vector3(side * 0.18, -0.28, 0.25)]), PackedFloat32Array([0.013, 0.017, 0.017, 0.017, 0.017, 0.015, 0.012]), rope, 7)
	Art.finish(loops)
	return art
