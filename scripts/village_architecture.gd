extends RefCounted

const B = preload("res://scripts/build.gd")
const O = preload("res://scripts/world_overhaul.gd")
static var roof_meshes = {}
static func build(parent: Node3D, width: float, depth: float, region: int, identity: String, wall_color: String, roof_color: String, detail: bool = true) -> void:
	var variant = posmod(hash(identity), 4); var h = 3.15
	parent.add_to_group("housing_representation"); parent.set_meta("building_generation", "v25-replacement")
	parent.set_meta("wooden_floor", Vector2(width, depth) * 0.5); parent.set_meta("shelter_height", h); parent.set_meta("door_position", Vector3(0, 0, depth * 0.5))
	var art = Node3D.new(); art.name = "ReplacementArchitecture"; parent.add_child(art)
	var plaster = B.world_surface("plaster", Color(wall_color).lightened(0.09).to_html())
	var timber = B.world_surface("stone", "#a98c68" if region == 12 else "#8d96ac") if region in [12, 15] else B.world_surface("timber", ["#645346", "#584d40", "#71604d", "#60594c"][variant])
	var stone = B.world_surface("stone", "#bea884" if region == 12 else "#a09a87")
	B.box(art, Vector3(0, -0.13, 0), Vector3(width + 0.25, 0.32, depth + 0.25), stone, detail)
	for x in [-width * 0.5, width * 0.5]:
		B.box(art, Vector3(x, h * 0.5, 0), Vector3(0.24, h, depth), plaster, detail)
		B.box(art, Vector3(x, 0.32, 0), Vector3(0.29, 0.64, depth + 0.05), stone)
	B.box(art, Vector3(0, h * 0.5, -depth * 0.5), Vector3(width, h, 0.24), plaster, detail)
	for side in [-1, 1]:
		B.box(art, Vector3(side * (width * 0.25 + 0.5), h * 0.5, depth * 0.5), Vector3(width * 0.5 - 1, h, 0.24), plaster, detail)
		B.box(art, Vector3(side * (width * 0.25 + 0.5), 0.32, depth * 0.5 + 0.025), Vector3(width * 0.5 - 1, 0.64, 0.28), stone)
	B.box(art, Vector3(0, 2.77, depth * 0.5), Vector3(2, 0.76, 0.24), plaster, detail)
	# Occlusion: the solid walls hide what's behind the house (and the outside, from within).
	preload("res://scripts/occluders.gd").house(parent, width, depth, h)
	B.box(art, Vector3(0, 0.004, 0), Vector3(width, 0.06, depth), B.world_surface("timber", "#a99170")).name = "WalkableFloor"
	for x in [-width * 0.5, width * 0.5]:
		for z in [-depth * 0.5, depth * 0.5]: B.beveled_box(art, Vector3(x, h * 0.5, z), Vector3(0.19, h + 0.06, 0.22), timber)
	for z in [-depth * 0.5 - 0.14, depth * 0.5 + 0.14]:
		for y in [0.68, 2.6, h]:
			if z > 0 and y < 2:
				for side in [-1, 1]: B.box(art, Vector3(side * (width * 0.25 + 0.595), y, z), Vector3(width * 0.5 - 1.01, 0.13, 0.12), timber)
			else: B.box(art, Vector3(0, y, z), Vector3(width + 0.18, 0.13, 0.12), timber)
		for x in [-width * 0.28, width * 0.28]: B.box(art, Vector3(x, 1.9, z), Vector3(0.13, 2.45, 0.12), timber)
	for side in [-1, 1]:
		for z in [-depth * 0.18, depth * 0.18]: B.box(art, Vector3(side * (width * 0.5 + 0.14), 1.9, z), Vector3(0.12, 2.45, 0.13), timber)
		for y in [0.68, 2.6, h]: B.box(art, Vector3(side * (width * 0.5 + 0.14), y, 0), Vector3(0.12, 0.13, depth + 0.2), timber)
		if variant % 2 == 0: B.branch(art, Vector3(side * (width * 0.5 + 0.16), 0.75, -depth * 0.42), Vector3(side * (width * 0.5 + 0.16), 2.55, -depth * 0.21), 0.05, timber, 1)
	if region == 12:
		B.box(art, Vector3(0, h + 0.06, 0), Vector3(width + 0.5, 0.18, depth + 0.5), stone)
		for side in [-1, 1]:
			B.box(art, Vector3(side * (width * 0.5 + 0.1), h + 0.29, 0), Vector3(0.18, 0.4, depth + 0.4), stone)
			B.box(art, Vector3(0, h + 0.29, side * (depth * 0.5 + 0.1)), Vector3(width + 0.4, 0.4, 0.18), stone)
		B.ball(art, Vector3(0, h + 0.72, -0.15), Vector3(width * 0.58, 1.35, depth * 0.62), B.mat("#ceb58b"))
	elif region == 15:
		for side in [-1, 1]:
			var plane = B.box(art, Vector3(side * width * 0.25, h + 0.8, 0), Vector3(sqrt(width * width * 0.25 + 2.56) + 0.45, 0.16, depth + 0.65), B.mat("#8fa9ba", 0.3))
			plane.rotation.z = -side * atan2(1.6, width * 0.5)
		B.branch(art, Vector3(0, h + 1.63, -depth * 0.5 - 0.25), Vector3(0, h + 1.63, depth * 0.5 + 0.25), 0.055, B.mat("#c9bf8c", 0.5), 1)
		B.facet(art, Vector3(0, h + 1.78, -depth * 0.25), Vector3(0.55, 0.8, 0.55), B.mat("#a8c4d1", 0.25, 0.08))
	else:
		var roofs = ["qv_roof_roundtiles_6x8", "qv_roof_roundtiles_6x10", "qv_roof_roundtiles_8x8", "qv_roof_roundtiles_6x8"]
		var roof = O.fit(art, roofs[variant], Vector3(0, h - 0.03, 0), Vector3(width + 0.65, 1.55 + variant * 0.08, depth + 0.75))
		if roof:
			var key = roofs[variant] + ":" + roof_color
			if not roof_meshes.has(key):
				var mesh = roof.get_child(0).mesh.duplicate()
				for surface in range(mesh.get_surface_count()):
					var mat = mesh.surface_get_material(surface)
					if mat is ShaderMaterial: mat = mat.duplicate(); mat.set_shader_parameter("tint", Color(roof_color).lightened(0.13)); mesh.surface_set_material(surface, mat)
				roof_meshes[key] = mesh
			var leaf = roof.get_child(0); leaf.mesh = roof_meshes[key]
			if leaf.mesh.get_surface_count() == 1: leaf.material_override = leaf.mesh.surface_get_material(0)
			if region == 9 and parent.get_meta("purpose", "") in ["stores", "workshop", "bakery", "inn", "merchant_shop", "smith_shop"]:
				leaf.material_override = B.world_surface("stone", "#626973")
			O.structural(roof)
	if region != 12:
		for z in [-depth * 0.5, depth * 0.5]:
			B.mesh(art, B._flat_geometry([PackedVector3Array([Vector3(-width * 0.5, h, z), Vector3(width * 0.5, h, z), Vector3(0, h + 1.5, z)])]), plaster)
			for side in [-1, 1]: B.branch(art, Vector3(side * width * 0.48, h, z), Vector3(0, h + 1.48, z), 0.07, timber, 1)
	B.box(art, Vector3(0, h - 0.04, 0), Vector3(width, 0.1, depth), timber)
	var ww = minf(1.28, 2 * (width * 0.31 - 1.12))
	for side in [-1, 1]:
		var at = Vector3(side * width * 0.31, 1.05, depth * 0.5 + 0.15)
		O.fit(art, "qv_window_thin_round1" if variant % 2 else "qv_window_wide_flat1", at, Vector3(ww, 1.3, 0.18))
		O.fit(art, "qv_windowshutters_wide_round_open" if variant % 2 else "qv_windowshutters_wide_flat_open", at + Vector3(0, 0, 0.09), Vector3(minf(1.7, 2 * (width * 0.31 - 1.1)), 1.3, 0.16))
		O.fit(art, "qv_window_thin_round1", Vector3(side * (width * 0.5 + 0.16), 1.04, 0), Vector3(1.1, 1.3, 0.16), side * PI * 0.5)
		O.fit(art, "qv_window_thin_round1", Vector3(side * (width * 0.5 - 0.17), 1.04, 0), Vector3(1.1, 1.3, 0.12), -side * PI * 0.5)
		for y in [0.68, 2.6]: B.box(art, Vector3(side * (width * 0.5 - 0.15), y, 0), Vector3(0.1, 0.12, depth - 0.1), timber)
		B.box(art, Vector3(side * width * 0.28, 1.9, -depth * 0.5 + 0.15), Vector3(0.12, 2.45, 0.1), timber)
	for y in [0.68, 2.6]: B.box(art, Vector3(0, y, -depth * 0.5 + 0.15), Vector3(width - 0.1, 0.12, 0.1), timber)
	var inner = O.fit(art, "qv_window_thin_round1", Vector3(0, 1.05, -depth * 0.5 + 0.17), Vector3(1.1, 1.3, 0.12))
	if inner: inner.name = "InteriorWindow"
	O.fit(art, "qv_doorframe_flat_brick" if region == 12 else "qv_doorframe_round_wooddark", Vector3(0, 0.04, depth * 0.5 + 0.16), Vector3(2.25, 2.5, 0.25))
	O.fit(art, "qv_prop_chimney2" if variant % 2 else "qv_prop_chimney", Vector3(-width * 0.28, 3.65, -depth * 0.2), Vector3(0.65, 1.55, 0.65))
	B.box(art, Vector3(0, 2.58, depth * 0.5 + 0.5), Vector3(2.7, 0.12, 1.12), timber).rotation.x = -0.1
	for side in [-1, 1]:
		B.branch(art, Vector3(side * 1.28, 2.55, depth * 0.5 + 0.9), Vector3(side * 1.28, 1.9, depth * 0.5 + 0.15), 0.05, timber, 1)
		B.box(art, Vector3(side * width * 0.31, 0.93, depth * 0.5 + 0.28), Vector3(ww + 0.12, 0.14, 0.38), timber)
	O.structural(art)
	load("res://scripts/static_surfaces.gd").bake(art, "%s:%s:%s:%s:%s:%s:%s" % [width, depth, region, variant, wall_color, roof_color, parent.get_meta("purpose", "home")])
	if detail:
		load("res://scripts/household_details.gd").windows(parent, width, depth, region, variant)
		load("res://scripts/building_access.gd").attach_building(parent, width, depth, identity)
