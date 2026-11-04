extends RefCounted

const N = preload("res://scripts/creature_anatomy_mesh.gd")
const G = preload("res://scripts/creature_shape.gd")
const F = preload("res://scripts/creature_facets.gd")

static func body(parent: Node3D, form: String, y: float, size: Vector3, head_at: Vector3, coat: Material) -> void:
	var w = size.x * 0.5; var h = size.y; var l = size.z
	var rows: Array[Vector4]
	if form in ["deer", "goat", "antelope", "camel"]:
		rows = [Vector4(head_at.z + 0.025, w * 0.33, head_at.y + 0.025, head_at.y - 0.23), Vector4(-l * 0.35, w * 0.57, head_at.y - 0.08, y - h * 0.28), Vector4(-l * 0.23, w * 0.95, y + h * 0.48, y - h * 0.49), Vector4(-l * 0.02, w, y + h * 0.5, y - h * 0.43), Vector4(l * 0.19, w * 0.75, y + h * 0.41, y - h * 0.24), Vector4(l * 0.36, w * 0.88, y + h * 0.39, y - h * 0.42), Vector4(l * 0.48, w * 0.57, y + h * 0.2, y - h * 0.31)]
		if form == "camel":
			rows[1] = Vector4(-l * 0.35, w * 0.5, head_at.y - 0.15, y - h * 0.2)
			rows[3].z += 0.38; rows[4].z += 0.34
	elif form in ["hare", "rodent"]:
		rows = [Vector4(head_at.z + 0.045, w * 0.52, head_at.y + 0.04, head_at.y - 0.15), Vector4(-l * 0.29, w * 0.71, y + h * 0.41, y - h * 0.39), Vector4(-l * 0.08, w * 0.82, y + h * 0.48, y - h * 0.37), Vector4(l * 0.16, w * 0.99, y + h * 0.51, y - h * 0.42), Vector4(l * 0.37, w, y + h * 0.39, y - h * 0.46), Vector4(l * 0.48, w * 0.6, y + h * 0.12, y - h * 0.31)]
	elif form == "otter":
		rows = [Vector4(head_at.z + 0.03, w * 0.52, head_at.y + 0.07, head_at.y - 0.13), Vector4(-l * 0.31, w * 0.86, y + h * 0.42, y - h * 0.45), Vector4(-l * 0.08, w, y + h * 0.5, y - h * 0.42), Vector4(l * 0.21, w * 0.89, y + h * 0.44, y - h * 0.36), Vector4(l * 0.43, w * 0.57, y + h * 0.24, y - h * 0.24), Vector4(l * 0.52, w * 0.3, y + h * 0.08, y - h * 0.17)]
	elif form in ["bird", "crane"]:
		rows = [Vector4(-l * 0.45, w * 0.38, y + h * 0.32, y - h * 0.13), Vector4(-l * 0.22, w * 0.84, y + h * 0.47, y - h * 0.45), Vector4(l * 0.02, w, y + h * 0.46, y - h * 0.5), Vector4(l * 0.27, w * 0.65, y + h * 0.26, y - h * 0.23), Vector4(l * 0.48, w * 0.23, y + h * 0.02, y - h * 0.1)]
	elif form == "lizard":
		rows = [Vector4(-l * 0.51, w * 0.5, y + h * 0.26, y - h * 0.31), Vector4(-l * 0.3, w * 0.93, y + h * 0.42, y - h * 0.45), Vector4(-l * 0.05, w, y + h * 0.48, y - h * 0.46), Vector4(l * 0.22, w * 0.91, y + h * 0.4, y - h * 0.39), Vector4(l * 0.46, w * 0.5, y + h * 0.2, y - h * 0.23)]
	elif form == "frog":
		rows = [Vector4(-l * 0.43, w * 0.67, y + h * 0.4, y - h * 0.35), Vector4(-l * 0.2, w * 0.94, y + h * 0.49, y - h * 0.48), Vector4(l * 0.12, w, y + h * 0.4, y - h * 0.46), Vector4(l * 0.36, w * 0.76, y + h * 0.23, y - h * 0.36), Vector4(l * 0.47, w * 0.33, y + h * 0.08, y - h * 0.2)]
	elif form == "fish":
		rows = [Vector4(-l * 0.48, w * 0.38, y + h * 0.16, y - h * 0.18), Vector4(-l * 0.25, w * 0.9, y + h * 0.42, y - h * 0.4), Vector4(-l * 0.02, w, y + h * 0.5, y - h * 0.5), Vector4(l * 0.22, w * 0.67, y + h * 0.35, y - h * 0.35), Vector4(l * 0.48, w * 0.18, y + h * 0.12, y - h * 0.12)]
	elif form in ["beetle", "hopper", "bee", "moth"]:
		rows = [Vector4(-l * 0.46, w * 0.44, y + h * 0.2, y - h * 0.24), Vector4(-l * 0.29, w * 0.77, y + h * 0.42, y - h * 0.41), Vector4(-l * 0.04, w * 0.66, y + h * 0.28, y - h * 0.25), Vector4(l * 0.12, w, y + h * 0.5, y - h * 0.48), Vector4(l * 0.34, w * 0.81, y + h * 0.36, y - h * 0.37), Vector4(l * 0.48, w * 0.3, y + h * 0.12, y - h * 0.16)]
	else:
		rows = [Vector4(-l * 0.48, w * 0.45, y + h * 0.2, y - h * 0.27), Vector4(-l * 0.27, w * 0.89, y + h * 0.42, y - h * 0.46), Vector4(l * 0.03, w, y + h * 0.49, y - h * 0.46), Vector4(l * 0.31, w * 0.84, y + h * 0.37, y - h * 0.39), Vector4(l * 0.48, w * 0.48, y + h * 0.13, y - h * 0.25)]
	N.z_loft(parent, rows, coat, "ConnectedRibcage")
	if form == "sheep":
		N.segment(parent, Vector3(0, y, -l * 0.34), head_at + Vector3(0, -0.025, 0.065), 0.34, 0.25, 0.31, 0.24, coat)
	elif form == "crane":
		N.z_loft(parent, [Vector4(-0.41, 0.057, head_at.y - 0.04, head_at.y - 0.17), Vector4(-0.32, 0.07, head_at.y - 0.08, y + 0.16), Vector4(-0.18, 0.095, y + 0.24, y - 0.09)], coat, "LongNeck")
	elif form == "bird": N.segment(parent, Vector3(0, y + 0.08, -0.15), head_at + Vector3(0, -0.04, 0.045), 0.17, 0.14, 0.16, 0.13, coat)

static func head(parent: Node3D, form: String, coat: Material, pale: Material, dark: Material) -> Vector3:
	var rows: Array[Vector4]; var size = Vector3(0.35, 0.32, 0.55); var nose_z = -0.32
	if form in ["goat", "deer", "antelope", "camel", "sheep"]:
		nose_z = -0.37 if form == "camel" else -0.32 if form != "sheep" else -0.28
		rows = [Vector4(nose_z, 0.072, -0.016, -0.117), Vector4(nose_z + 0.075, 0.087, 0.021, -0.143), Vector4(-0.13, 0.112, 0.118, -0.145), Vector4(0.015, 0.163, 0.174, -0.131), Vector4(0.12, 0.137, 0.137, -0.078), Vector4(0.18, 0.081, 0.068, -0.046)]
	elif form in ["hare", "rodent", "otter"]:
		size = Vector3(0.26, 0.26, 0.36); nose_z = -0.215 if form != "otter" else -0.23
		rows = [Vector4(nose_z, 0.043, -0.012, -0.064), Vector4(nose_z + 0.05, 0.079, 0.025, -0.096), Vector4(-0.065, 0.119, 0.109, -0.117), Vector4(0.035, 0.13, 0.139, -0.104), Vector4(0.12, 0.092, 0.084, -0.064)]
	elif form == "lizard":
		size = Vector3(0.34, 0.2, 0.47); nose_z = -0.29
		rows = [Vector4(nose_z, 0.079, 0.015, -0.055), Vector4(-0.18, 0.123, 0.065, -0.084), Vector4(-0.015, 0.171, 0.104, -0.092), Vector4(0.12, 0.103, 0.073, -0.067)]
	elif form == "frog":
		size = Vector3(0.49, 0.29, 0.38); nose_z = -0.22
		rows = [Vector4(nose_z, 0.156, 0.025, -0.095), Vector4(-0.12, 0.232, 0.112, -0.145), Vector4(0.015, 0.245, 0.148, -0.132), Vector4(0.14, 0.155, 0.095, -0.095)]
	elif form in ["bird", "crane"]:
		size = Vector3(0.23, 0.24, 0.27); nose_z = -0.14
		rows = [Vector4(-0.14, 0.057, 0.035, -0.057), Vector4(-0.045, 0.104, 0.117, -0.103), Vector4(0.035, 0.112, 0.123, -0.104), Vector4(0.125, 0.061, 0.054, -0.051)]
	elif form in ["moth", "bee", "hopper", "beetle"]:
		size = Vector3(0.22, 0.22, 0.26); nose_z = -0.14
		rows = [Vector4(-0.14, 0.069, 0.041, -0.07), Vector4(-0.04, 0.11, 0.105, -0.105), Vector4(0.06, 0.095, 0.081, -0.083), Vector4(0.12, 0.045, 0.034, -0.037)]
	else:
		var width = 0.19 if form == "manta" else 0.12
		var height = 0.05 if form == "manta" else 0.13
		rows = [Vector4(-0.16, width * 0.48, height * 0.25, -height * 0.5), Vector4(-0.03, width, height, -height), Vector4(0.12, width * 0.61, height * 0.54, -height * 0.63)]
	N.z_loft(parent, rows, coat, "SkullBridgeAndJaw")
	if form in ["goat", "deer", "antelope", "camel", "sheep", "hare", "rodent", "otter", "lizard"]:
		var small = form in ["hare", "rodent", "otter"]
		var width = 0.043 if small else 0.069
		N.z_loft(parent, [Vector4(nose_z - 0.006, width, -0.02, -0.061 if small else -0.09), Vector4(nose_z + 0.024, width * 1.03, -0.014, -0.064 if small else -0.097)], dark, "NosePad")

		N.z_loft(parent, [Vector4(nose_z + 0.03, width * 1.1, -0.06 if small else -0.092, -0.074 if small else -0.11), Vector4(-0.07, 0.091 if small else 0.105, -0.099 if small else -0.133, -0.113 if small else -0.148)], pale, "LowerJaw")
		for side in [-1.0, 1.0]:
			if form in ["goat", "deer", "antelope", "camel", "sheep"]:
				G.shape(parent, Vector3(side * 0.043, -0.031, nose_z - 0.009), Vector3(0.019, 0.016, 0.012), pale, "plate")
			elif form in ["hare", "rodent", "otter"]:
				for i in range(2): F.tube(parent, PackedVector3Array([Vector3(side * 0.065, -0.043, nose_z + 0.057), Vector3(side * 0.19, -0.025 - i * 0.035, nose_z + 0.012)]), PackedFloat32Array([0.0035, 0.0015]), pale, 4)
	parent.set_meta("anatomical_skull", true)
	return size

static func beast_body(parent: Node3D, form: String, y: float, size: Vector3, coat: Material) -> void:
	var w = size.x * 0.5; var h = size.y; var l = size.z
	var rows: Array[Vector4]
	if form in ["hound", "cat", "boar", "deer", "armored"]:
		var deep = form in ["boar", "armored"]
		rows = [Vector4(-0.57, w * 0.48, y + 0.24, y - 0.12), Vector4(-l * 0.29, w * 0.9, y + h * 0.51, y - h * 0.48), Vector4(-l * 0.08, w, y + h * 0.49, y - h * 0.46), Vector4(l * 0.17, w * (0.88 if deep else 0.64), y + h * 0.36, y - h * (0.39 if deep else 0.12)), Vector4(l * 0.34, w * 0.87, y + h * 0.39, y - h * 0.42), Vector4(l * 0.48, w * 0.5, y + h * 0.2, y - h * 0.32)]
	elif form in ["crawler", "spider", "scorpion"]:
		rows = [Vector4(-l * 0.44, w * 0.48, y + h * 0.21, y - h * 0.22), Vector4(-l * 0.25, w * 0.76, y + h * 0.41, y - h * 0.43), Vector4(-l * 0.03, w * 0.56, y + h * 0.24, y - h * 0.23), Vector4(l * 0.18, w * 1.06, y + h * 0.59, y - h * 0.46), Vector4(l * 0.4, w * 0.89, y + h * 0.45, y - h * 0.37), Vector4(l * 0.55, w * 0.34, y + h * 0.15, y - h * 0.14)]
	elif form == "winged":
		rows = [Vector4(-l * 0.45, w * 0.4, y + h * 0.37, y - h * 0.12), Vector4(-l * 0.23, w * 0.91, y + h * 0.55, y - h * 0.43), Vector4(l * 0.02, w, y + h * 0.4, y - h * 0.5), Vector4(l * 0.29, w * 0.63, y + h * 0.22, y - h * 0.19), Vector4(l * 0.49, w * 0.2, y + h * 0.02, y - h * 0.09)]
	else:
		rows = [Vector4(-l * 0.49, w * 0.61, y + h * 0.37, y - h * 0.32), Vector4(-l * 0.27, w * 0.98, y + h * 0.49, y - h * 0.48), Vector4(l * 0.02, w, y + h * 0.43, y - h * 0.46), Vector4(l * 0.29, w * 0.82, y + h * 0.32, y - h * 0.33), Vector4(l * 0.49, w * 0.46, y + h * 0.18, y - h * 0.19)]
	N.z_loft(parent, rows, coat, "BeastRibcage")

static func beast_head(parent: Node3D, form: String, coat: Material, pale: Material, dark: Material) -> void:
	var rows: Array[Vector4]; var nose = -0.46
	if form in ["hound", "cat", "deer", "boar", "armored"]:
		var cat = form == "cat"; var broad = form in ["boar", "armored"]
		nose = -0.33 if cat else -0.46
		rows = [Vector4(nose, 0.14 if broad else 0.085, -0.028, -0.155), Vector4(nose + 0.09, 0.16 if broad else 0.115, 0.012, -0.19), Vector4(-0.15, 0.21 if broad else 0.16, 0.157, -0.205), Vector4(0.005, 0.25 if broad else 0.22, 0.231, -0.18), Vector4(0.15, 0.18, 0.163, -0.122), Vector4(0.22, 0.1, 0.08, -0.07)]
		N.z_loft(parent, rows, coat, "BeastSkullAndMuzzle")
		N.z_loft(parent, [Vector4(nose - 0.012, 0.12 if broad else 0.075, -0.025, -0.099), Vector4(nose + 0.025, 0.13 if broad else 0.082, -0.015, -0.105)], dark, "Nose")
		N.z_loft(parent, [Vector4(nose + 0.03, 0.115 if broad else 0.085, -0.128, -0.16), Vector4(-0.11, 0.173, -0.181, -0.212), Vector4(0.08, 0.12, -0.136, -0.16)], pale, "Mandible")
		return
	if form == "frog":
		rows = [Vector4(-0.32, 0.25, 0.03, -0.14), Vector4(-0.14, 0.42, 0.17, -0.23), Vector4(0.06, 0.43, 0.21, -0.2), Vector4(0.2, 0.25, 0.11, -0.13)]
	elif form in ["spider", "crawler", "scorpion"]:
		rows = [Vector4(-0.28, 0.14, 0.02, -0.12), Vector4(-0.12, 0.25, 0.18, -0.19), Vector4(0.08, 0.23, 0.17, -0.17), Vector4(0.22, 0.11, 0.06, -0.09)]
	elif form == "winged":
		rows = [Vector4(-0.27, 0.1, 0.02, -0.13), Vector4(-0.09, 0.2, 0.2, -0.2), Vector4(0.07, 0.22, 0.23, -0.19), Vector4(0.19, 0.11, 0.11, -0.11)]
	elif form == "wyrm":
		rows = [Vector4(-0.37, 0.17, 0.02, -0.15), Vector4(-0.2, 0.24, 0.12, -0.22), Vector4(0.02, 0.29, 0.23, -0.21), Vector4(0.21, 0.18, 0.16, -0.14)]
	else:
		rows = [Vector4(-0.28, 0.16, 0.06, -0.16), Vector4(-0.12, 0.27, 0.22, -0.23), Vector4(0.1, 0.24, 0.2, -0.2), Vector4(0.23, 0.12, 0.09, -0.1)]
	N.z_loft(parent, rows, coat, "MonsterSkull")
