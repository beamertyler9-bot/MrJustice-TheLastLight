extends RefCounted


const N = preload("res://scripts/creature_anatomy_mesh.gd")
const F = preload("res://scripts/creature_facets.gd")
const A = preload("res://scripts/cast_art.gd")
static var bell_art: PackedScene

static func clear_meshes(node: Node3D) -> void:
	for child in node.get_children():
		if child is MeshInstance3D: child.free()
static func feature(parent: Node3D, label: String) -> Node3D:
	var node = Node3D.new(); node.name = label; parent.add_child(node)
	node.set_meta("regional_joint", true); node.add_to_group("batch_dynamic"); return node
static func spike(parent: Node3D, a: Vector3, b: Vector3, width: float, mat: Material) -> void:
	N.segment(parent, a, b, width, 0.008, width * 0.8, 0.008, mat)
static func slab(parent: Node3D, at: Vector3, size: Vector3, mat: Material, tilt: float = 0) -> MeshInstance3D:
	var mesh = F.beveled_box(parent, at, size, mat); mesh.rotation.z = tilt; return mesh
static func hollow(head: Node3D, mat: Material, dark: Material, width: float = 0.21) -> void:

	N.y_loft(head, [Vector4(-0.29, 0.07, -0.17, 0.06), Vector4(-0.13, width, -0.19, 0.1), Vector4(0.12, width, -0.17, 0.14), Vector4(0.3, width * 0.55, -0.09, 0.1)], dark, "HollowFace", 6)
	for s in [-1, 1]:
		spike(head, Vector3(s * width, -0.18, -0.17), Vector3(s * width * 0.85, 0.19, -0.19), 0.105, mat)
		slab(head, Vector3(s * 0.1, 0.14, -0.19), Vector3(0.22, 0.075, 0.11), mat, s * 0.14)
		spike(head, Vector3(s * 0.15, -0.12, -0.17), Vector3(s * 0.045, -0.3, -0.17), 0.085, mat)
static func guardians(e, rig: Dictionary, stone: Material, dark: Material, pale: Material) -> void:
	var id: String = e.species_id
	if id not in ["cliffwarden", "root_reaper", "shard_sentinel"]: return
	clear_meshes(e.model); clear_meshes(rig.head)
	var art = feature(e.model, "GuardianSilhouette"); rig.features.design = art
	if id == "cliffwarden":

		for row in range(5):
			var width = [0.55, 0.73, 1.02, 1.15, 0.85][row]
			slab(art, Vector3(-0.07, 0.67 + row * 0.19, 0.025), Vector3(width, 0.25, 0.6), stone if row % 2 == 0 else pale, -0.055 + row * 0.027)
		rig.head.position = Vector3(0.06, 1.69, -0.03)
		hollow(rig.head, pale, dark, 0.24)
		slab(rig.head, Vector3(-0.04, 0.24, 0.015), Vector3(0.58, 0.2, 0.42), stone, 0.1)
		for i in range(2):
			clear_meshes(e.arms[i]); clear_meshes(e.forearms[i])
			var s = -1 if i == 0 else 1
			var w = 0.7 if i == 0 else 0.33
			slab(e.arms[i], Vector3(s * 0.06, -0.11, 0.025), Vector3(w, 0.62, w * 0.84), stone, s * 0.13)
			for row in range(3): slab(e.forearms[i], Vector3(s * 0.03, -0.08 - row * 0.19, -0.04), Vector3(w * 1.08, 0.25, w * 0.93), pale if row == 1 else stone, s * 0.08)
			for finger in range(4): slab(e.forearms[i], Vector3((finger - 1.5) * w * 0.22, -0.61, -0.12), Vector3(w * 0.19, 0.24, 0.23), stone)
			clear_meshes(e.feet[i]); clear_meshes(e.knees[i])
			slab(e.feet[i], Vector3(0, -0.16, 0.02), Vector3(0.35, 0.44, 0.39), stone, s * 0.06)
			slab(e.knees[i], Vector3(0, -0.15, 0.015), Vector3(0.29, 0.35, 0.32), stone)
			N.paw(e.knees[i], Vector3(0, -0.368, -0.018), 0.36, 0.46, 0.15, pale)
	elif id == "root_reaper":

		F.tube(art, PackedVector3Array([Vector3(0, 0.61, 0.02), Vector3(0, 0.92, 0.1), Vector3(0, 1.29, 0.17), Vector3(0, 1.61, -0.04), Vector3(0, 1.72, -0.32)]), PackedFloat32Array([0.13, 0.095, 0.11, 0.09, 0.075]), stone, 7)
		for s in [-1, 1]:
			for row in range(4):
				var y = 1.02 + row * 0.145
				F.tube(art, PackedVector3Array([Vector3(0, y, 0.1), Vector3(s * (0.24 + row * 0.025), y - 0.055, 0.02), Vector3(s * 0.25, y - 0.17, -0.18), Vector3(s * 0.08, y - 0.2, -0.24)]), PackedFloat32Array([0.045, 0.055, 0.035, 0.012]), pale, 5)
			spike(art, Vector3(s * 0.23, 1.44, 0.025), Vector3(s * 0.55, 1.82, 0.22), 0.16, stone)
			spike(art, Vector3(s * 0.14, 0.65, 0.03), Vector3(s * 0.29, 0.81, -0.12), 0.13, stone)
		rig.head.position = Vector3(0, 1.66, -0.35); hollow(rig.head, pale, dark, 0.185)
		for s in [-1, 1]:
			spike(rig.head, Vector3(s * 0.13, 0.19, 0.02), Vector3(s * 0.3, 0.61, 0.18), 0.11, stone)
			spike(rig.head, Vector3(s * 0.23, 0.43, 0.12), Vector3(s * 0.45, 0.48, 0.06), 0.065, stone)
		for i in range(2):
			for joint in [e.arms[i], e.forearms[i], e.feet[i], e.knees[i]]:
				for part in joint.get_children():
					if part is MeshInstance3D and "Finger" not in part.name and "Shoe" not in part.name: part.scale.x *= 0.65; part.scale.z *= 0.7
			for finger in range(4):
				var x = (-1.0 if i == 0 else 1.0) * 0.025 + (finger - 1.5) * 0.0465
				F.tube(e.forearms[i], PackedVector3Array([Vector3(x, -0.47, -0.094), Vector3(x * 1.4, -0.77 - finger * 0.025, -0.16), Vector3(x * 1.5, -0.86 - finger * 0.025, -0.32)]), PackedFloat32Array([0.025, 0.02, 0.004]), pale, 5)
	else:
		N.y_loft(art, [Vector4(0.6, 0.22, -0.13, 0.16), Vector4(0.94, 0.18, -0.18, 0.18), Vector4(1.28, 0.46, -0.31, 0.28), Vector4(1.51, 0.32, -0.17, 0.2)], stone, "CrystalCuirass", 4)
		N.segment(art, Vector3(0, 1.43, -0.04), Vector3(0, 1.76, -0.055), 0.24, 0.2, 0.28, 0.24, stone)
		N.y_loft(rig.head, [Vector4(-0.25, 0.055, -0.23, 0.07), Vector4(-0.06, 0.22, -0.29, 0.18), Vector4(0.16, 0.2, -0.24, 0.17), Vector4(0.4, 0.015, -0.08, 0.05)], pale, "PrismHelm", 4)
		slab(rig.head, Vector3(0, 0.065, -0.261), Vector3(0.28, 0.037, 0.023), dark)
		for i in range(2):
			var s = -1 if i == 0 else 1
			for k in range(2): spike(e.arms[i], Vector3(s * 0.045, -0.04, 0.06 + k * 0.12), Vector3(s * (0.24 + k * 0.14), 0.45 - k * 0.08, 0.08 + k * 0.16), 0.29, pale)

		N.segment(e.forearms[0], Vector3(0, -0.2, -0.17), Vector3(0, -0.68, -0.17), 0.075, 0.075, 0.075, 0.075, dark)
		slab(e.forearms[0], Vector3(0, -0.62, -0.17), Vector3(0.64, 0.28, 0.37), pale)
		spike(e.forearms[1], Vector3(0.07, -0.3, -0.3), Vector3(0.07, 0.08, -0.38), 0.27, pale)

static func haunted(e, rig: Dictionary, stone: Material, dark: Material, pale: Material) -> void:
	if int(e.profile.get("region", 0)) != 14 or e.species_id == "root_reaper": return
	var bone = F.material("bone", Color("#b4b5a0"))
	var shade = F.material("bark", Color("#26282f"))
	var art = feature(e.model, "HauntedSilhouette"); rig.features.design = art



	for child in e.model.get_children():
		if child is MeshInstance3D and not child.is_in_group("batch_dynamic"):
			child.reparent(art, false)
	match e.species_id:
		"wraithhart":

			rig.head.position.y += 0.1; rig.head.scale = Vector3(0.86, 1.08, 1.2)
			for s in [-1, 1]:
				F.tube(rig.head, PackedVector3Array([Vector3(s * 0.13, 0.17, 0.06), Vector3(s * 0.29, 0.57, 0.09), Vector3(s * 0.55, 0.82, -0.04), Vector3(s * 0.74, 0.91, -0.2)]), PackedFloat32Array([0.09, 0.06, 0.035, 0.005]), shade, 6)
				for k in range(3): spike(rig.head, Vector3(s * (0.29 + k * 0.12), 0.54 + k * 0.1, 0.05), Vector3(s * (0.24 + k * 0.2), 0.92 + k * 0.1, 0.03), 0.055, bone)
			for k in range(6): spike(art, Vector3(0, 0.8, 0.45 - k * 0.16), Vector3(0, 1.09, 0.43 - k * 0.16), 0.095, bone)
		"hollow_hound":

			for k in range(5): spike(art, Vector3(0, 0.8, 0.46 - k * 0.2), Vector3(0, 1.12 + k * 0.055, 0.5 - k * 0.2), 0.16, shade)
			N.z_loft(rig.head, [Vector4(-0.5, 0.13, -0.13, -0.24), Vector4(-0.26, 0.21, -0.15, -0.34), Vector4(0.03, 0.13, -0.05, -0.16)], bone, "UnhingedJaw", 6)
			for s in [-1, 1]: slab(rig.head, Vector3(s * 0.14, 0.075, -0.24), Vector3(0.16, 0.13, 0.035), shade, s * 0.28)
		"grave_creeper":

			slab(art, Vector3(0, 0.61, 0.19), Vector3(0.69, 0.3, 0.9), shade, 0.12)
			for k in range(4):
				spike(art, Vector3((k - 1.5) * 0.14, 0.62, 0.3), Vector3((k - 1.5) * 0.23, 1.1 - k * 0.06, 0.48), 0.1, bone)
			for s in [-1, 1]:
				F.tube(art, PackedVector3Array([Vector3(s * 0.22, 0.53, 0.25), Vector3(s * 0.65, 0.35, 0.55), Vector3(s * 0.83, 0.12, 0.82)]), PackedFloat32Array([0.1, 0.055, 0.01]), stone, 6)
		"veil_moth":

			for i in range(2):
				var s = -1 if i == 0 else 1; var wing = rig.wings[i]
				for k in range(4):
					var x = s * (0.28 + k * 0.2)
					spike(wing, Vector3(x, 0, 0.17), Vector3(x + s * 0.12, -0.03, 0.71 + (k % 2) * 0.22), 0.16, pale)
			N.z_loft(art, [Vector4(-0.49, 0.12, 0.72, 0.51), Vector4(-0.24, 0.14, 0.91, 0.48), Vector4(0.1, 0.1, 0.77, 0.46)], shade, "DeathsHeadThorax", 6)
			for s in [-1, 1]: slab(art, Vector3(s * 0.07, 0.82, -0.27), Vector3(0.075, 0.025, 0.12), bone)
		"thorn_widow":

			N.y_loft(art, [Vector4(0.35, 0.21, 0.03, 0.55), Vector4(0.72, 0.38, -0.04, 0.68), Vector4(1.02, 0.17, 0.17, 0.54), Vector4(1.22, 0.025, 0.27, 0.34)], stone, "WidowAbdomen", 6)
			for s in [-1, 1]:
				for k in range(3): spike(art, Vector3(s * 0.24, 0.7, 0.1 + k * 0.17), Vector3(s * 0.54, 1.02, 0.08 + k * 0.2), 0.09, bone)
				F.tube(rig.head, PackedVector3Array([Vector3(s * 0.13, -0.02, -0.12), Vector3(s * 0.38, -0.05, -0.44), Vector3(s * 0.25, 0.03, -0.59)]), PackedFloat32Array([0.08, 0.045, 0.005]), bone, 6)
		"mourning_knight":

			clear_meshes(rig.head); hollow(rig.head, pale, shade, 0.19)
			for s in [-1, 1]:
				spike(art, Vector3(s * 0.29, 1.44, 0.14), Vector3(s * 0.6, 1.21, 0.2), 0.2, dark)
				for k in range(3): spike(art, Vector3(s * (0.12 + k * 0.085), 1.25, 0.24), Vector3(s * (0.18 + k * 0.12), 0.27 + k * 0.1, 0.52), 0.16, dark)
		"pale_watcher":

			clear_meshes(rig.head); hollow(rig.head, bone, shade, 0.18)
			spike(rig.head, Vector3(0, 0.19, 0.05), Vector3(0, 0.7, 0.2), 0.38, stone)
			for s in [-1, 1]:
				spike(art, Vector3(s * 0.21, 1.42, 0.15), Vector3(s * 0.42, 0.41, 0.4), 0.21, stone)
				for k in range(3): spike(e.forearms[0 if s < 0 else 1], Vector3((k - 1) * 0.065, -0.46, -0.1), Vector3((k - 1) * 0.1, -0.88, -0.14), 0.033, bone)
		"blackthorn_regent":

			clear_meshes(rig.head); hollow(rig.head, bone, shade, 0.2)
			for s in [-1, 1]:
				F.tube(art, PackedVector3Array([Vector3(s * 0.21, 0.73, 0.18), Vector3(s * 0.44, 1.47, 0.27), Vector3(s * 0.72, 1.92, 0.29), Vector3(s * 0.61, 2.18, 0.25)]), PackedFloat32Array([0.11, 0.09, 0.05, 0.008]), shade, 6)
				for k in range(3): spike(art, Vector3(s * (0.41 + k * 0.09), 1.4 + k * 0.17, 0.27), Vector3(s * (0.77 + k * 0.12), 1.66 + k * 0.19, 0.29), 0.065, stone)
				spike(art, Vector3(s * 0.17, 0.8, 0.18), Vector3(s * 0.44, 0.08, 0.56), 0.22, stone)

static func bellkeeper(actor) -> void:


	for child in actor.head.get_children():
		if child is MeshInstance3D and child != actor.core and child != actor.phase_crown: child.free()
	var stone = F.material("metal", Color("#606577"), 0.32)
	var dark = F.material("metal", Color("#202631"), 0.32)
	var pale = F.material("metal", Color("#b2b3a2"), 0.32)

	actor.core.scale *= Vector3(0.3, 0.12, 0.3)
	actor.core.position = Vector3(0, 0.06, -0.205)
	if bell_art != null:
		actor.head.add_child(bell_art.instantiate()); return
	var art = feature(actor.head, "HauntedBelfry")
	hollow(art, stone, dark, 0.3)
	for s in [-1, 1]:
		spike(art, Vector3(s * 0.27, -0.2, 0.04), Vector3(s * 0.39, 0.43, 0.04), 0.17, stone)
		spike(art, Vector3(s * 0.39, 0.37, 0.04), Vector3(s * 0.18, 0.76, 0.06), 0.14, pale)
		slab(art, Vector3(s * 0.14, 0.08, -0.2), Vector3(0.1, 0.19, 0.04), dark)
		F.tube(art, PackedVector3Array([Vector3(s * 0.18, 0.7, 0.06), Vector3(s * 0.48, 0.92, 0.05), Vector3(s * 0.48, 1.1, 0.05)]), PackedFloat32Array([0.065, 0.042, 0.022]), stone, 6)
	for k in range(5): spike(art, Vector3((k - 2) * 0.1, -0.21, -0.1), Vector3((k - 2) * 0.13, -0.55, -0.04), 0.055, pale)
	art.remove_from_group("batch_dynamic"); A.finish(art); art.add_to_group("batch_dynamic", true)
	for child in art.get_children(): child.owner = art
	bell_art = PackedScene.new(); assert(bell_art.pack(art) == OK)
