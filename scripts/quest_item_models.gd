extends RefCounted

const B = preload("res://scripts/build.gd")
const Items = preload("res://scripts/quest_items.gd")
static var _prepared: Dictionary = {}
static func build(parent: Node3D, id: String) -> Node3D:
	var root = Node3D.new(); root.name = "Keepsake_" + id; root.set_meta("item", id); root.set_meta("item_model", id); parent.add_child(root)
	if _prepared.has(id):
		for part in _prepared[id]:
			var visual = B.mesh(root, part.mesh, part.material)
			visual.transform = part.transform; visual.cast_shadow = part.shadow; visual.layers = part.layers
		return root
	var row: Dictionary = Items.ITEMS[id]; var ink = B.mat("#303039"); var color = B.mat(row.color); var brass = B.mat("#d6b675", 0.65); var pale = B.mat("#e6ddc1")
	match str(row.shape):
		"satchel":
			B.ball(root, Vector3(0, 0.18, 0), Vector3(0.39, 0.34, 0.27), color); B.ring(root, Vector3(0, 0.32, 0), 0.11, 0.025, brass); B.box(root, Vector3(0, 0.21, 0.14), Vector3(0.08, 0.13, 0.025), brass)
		"spindle":
			B.cyl(root, Vector3(0, 0.26, 0), 0.018, 0.5, brass); B.cyl(root, Vector3(0, 0.17, 0), 0.13, 0.05, pale); B.box(root, Vector3(0.075, 0.29, 0), Vector3(0.13, 0.035, 0.045), color).rotation.z = -0.6
		"book":
			B.beveled_box(root, Vector3(0, 0.12, 0), Vector3(0.35, 0.18, 0.27), color); B.box(root, Vector3(0.02, 0.12, 0.14), Vector3(0.29, 0.13, 0.02), pale); B.box(root, Vector3(0.12, 0.22, 0), Vector3(0.035, 0.025, 0.24), brass)
		"tube":
			B.cyl(root, Vector3(0, 0.26, 0), 0.075, 0.48, color); B.cyl(root, Vector3(0, 0.49, 0), 0.09, 0.04, brass); B.ring(root, Vector3(0, 0.15, 0), 0.08, 0.012, brass)
		"locket":
			B.ball(root, Vector3(-0.06, 0.13, 0), Vector3(0.18, 0.2, 0.06), color); B.ball(root, Vector3(0.06, 0.13, 0), Vector3(0.18, 0.2, 0.06), color); B.box(root, Vector3(0, 0.075, 0), Vector3(0.15, 0.15, 0.05), color).rotation.z = PI / 4; B.ring(root, Vector3(0, 0.29, 0), 0.1, 0.012, brass).rotation.x = PI / 2
		"fork":
			B.box(root, Vector3(0, 0.12, 0), Vector3(0.035, 0.24, 0.04), brass); B.box(root, Vector3(0, 0.24, 0), Vector3(0.21, 0.035, 0.04), brass)
			for x in [-0.09, 0.09]: B.box(root, Vector3(x, 0.35, 0), Vector3(0.035, 0.24, 0.04), brass)
			B.box(root, Vector3(0, 0.09, 0), Vector3(0.055, 0.08, 0.055), color)
		"kettle":
			B.ball(root, Vector3(0, 0.16, 0), Vector3(0.36, 0.28, 0.32), color); B.cyl(root, Vector3(0, 0.3, 0), 0.12, 0.03, brass); B.ring(root, Vector3(0, 0.36, 0), 0.14, 0.022, ink).rotation.x = PI / 2; B.cyl(root, Vector3(0.2, 0.22, 0), 0.035, 0.2, brass).rotation.z = -0.8
		"bellows":
			B.ball(root, Vector3(0, 0.1, 0), Vector3(0.27, 0.13, 0.4), color); B.box(root, Vector3(0, 0.18, 0), Vector3(0.24, 0.025, 0.36), brass); B.cyl(root, Vector3(0, 0.11, 0.27), 0.025, 0.23, brass).rotation.x = PI / 2
		"plumb":
			B.cyl(root, Vector3(0, 0.15, 0), 0.12, 0.23, brass, false, 0); B.cyl(root, Vector3(0, 0.36, 0), 0.008, 0.2, color); B.ring(root, Vector3(0, 0.45, 0), 0.07, 0.013, color)
		"star":
			for i in range(5): B.box(root, Vector3(0, 0.09, 0), Vector3(0.36, 0.12, 0.1), color).rotation.y = float(i) * TAU / 5
			B.cyl(root, Vector3(0, 0.16, 0), 0.08, 0.025, brass)
		"press":
			B.box(root, Vector3(0, 0.04, 0), Vector3(0.31, 0.06, 0.25), color)
			for x in [-0.13, 0.13]: B.box(root, Vector3(x, 0.22, 0), Vector3(0.04, 0.4, 0.05), brass)
			B.box(root, Vector3(0, 0.41, 0), Vector3(0.31, 0.045, 0.08), color); B.cyl(root, Vector3(0, 0.29, 0), 0.02, 0.25, ink); B.cyl(root, Vector3(0, 0.17, 0), 0.11, 0.04, pale)
		"die":
			B.beveled_box(root, Vector3(0, 0.16, 0), Vector3(0.29, 0.29, 0.29), color); B.cyl(root, Vector3(0, 0.31, 0), 0.085, 0.015, brass)
		"cup":
			B.cyl(root, Vector3(0, 0.15, 0), 0.12, 0.25, color); B.cyl(root, Vector3(0, 0.28, 0), 0.105, 0.01, ink); B.ring(root, Vector3(0.14, 0.16, 0), 0.09, 0.025, brass).rotation.x = PI / 2
		"tongs":
			for sign_value in [-1, 1]: B.box(root, Vector3(sign_value * 0.055, 0.27, 0), Vector3(0.025, 0.5, 0.035), brass).rotation.z = sign_value * 0.2
			B.ball(root, Vector3(0, 0.25, 0), Vector3(0.06, 0.06, 0.06), ink); B.box(root, Vector3(0, 0.12, 0), Vector3(0.14, 0.1, 0.04), color)
		"compass":
			B.cyl(root, Vector3(0, 0.06, 0), 0.18, 0.09, brass); B.cyl(root, Vector3(0, 0.11, 0), 0.15, 0.015, pale); B.box(root, Vector3(0, 0.13, 0), Vector3(0.025, 0.015, 0.25), color).rotation.y = 0.4; B.ring(root, Vector3(0, 0.06, 0.23), 0.06, 0.015, brass)
		"coil":
			B.cyl(root, Vector3(0, 0.23, 0), 0.105, 0.38, ink)
			for y in [0.09, 0.16, 0.23, 0.3, 0.37]: B.ring(root, Vector3(0, y, 0), 0.12, 0.025, color)
			for y in [0.025, 0.43]: B.cyl(root, Vector3(0, y, 0), 0.15, 0.04, brass)
		"chime":
			B.box(root, Vector3(0, 0.45, 0), Vector3(0.4, 0.04, 0.05), ink)
			for i in range(3): B.cyl(root, Vector3((i - 1) * 0.13, 0.25 + float(i) * 0.03, 0), 0.035, 0.3 - float(i) * 0.06, brass)
		"whistle":
			B.cyl(root, Vector3(0, 0.07, 0), 0.055, 0.43, color).rotation.x = PI / 2
			for z in [-0.06, 0.06]: B.cyl(root, Vector3(0, 0.124, z), 0.018, 0.008, ink)
		"musicbox":
			B.beveled_box(root, Vector3(0, 0.1, 0), Vector3(0.34, 0.18, 0.28), color); B.box(root, Vector3(0, 0.31, -0.1), Vector3(0.34, 0.22, 0.035), color).rotation.x = -0.25; B.cyl(root, Vector3(0, 0.2, 0), 0.1, 0.02, brass); B.box(root, Vector3(0.23, 0.1, 0), Vector3(0.13, 0.025, 0.025), brass); B.box(root, Vector3(0.29, 0.14, 0), Vector3(0.025, 0.1, 0.07), brass)



	B.merge_colored(root)
	var parts: Array = []
	for visual in root.get_children():
		if visual is MeshInstance3D:
			parts.append({"mesh": visual.mesh, "material": visual.material_override, "transform": visual.transform, "shadow": visual.cast_shadow, "layers": visual.layers})
	_prepared[id] = parts
	return root
