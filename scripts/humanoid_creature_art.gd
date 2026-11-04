extends RefCounted


const N = preload("res://scripts/creature_anatomy_mesh.gd")
const F = preload("res://scripts/creature_facets.gd")

static func _joint(parent: Node3D, at: Vector3, label: String) -> Node3D:
	var joint = Node3D.new(); joint.name = label; joint.position = at
	joint.set_meta("regional_joint", true); joint.add_to_group("batch_dynamic")
	parent.add_child(joint); return joint

static func _hand(parent: Node3D, side: float, surface: Material, detail: Material, thin: bool = false, grasped: bool = false) -> void:
	var width = 0.095 if thin else 0.113
	var palm = N.y_loft(parent, [Vector4(-0.485, width * 0.8, -0.145, -0.035), Vector4(-0.425, width, -0.155, -0.02), Vector4(-0.355, width * 0.78, -0.13, -0.025), Vector4(-0.315, width * 0.53, -0.115, -0.035)], surface, "HumanPalm")
	palm.position.x = side * 0.025
	for finger in range(4):
		if grasped:
			var root = Vector3(side * 0.1, -0.344 - finger * 0.049, -0.08)
			var bend = Vector3(side * 0.055, root.y - 0.005, -0.204)
			var tip = Vector3(-side * 0.025, root.y - 0.011, -0.178)
			N.segment(parent, root, bend, 0.043, 0.037, 0.052, 0.043, surface).name = "CurledFingerBase" + str(finger)
			N.segment(parent, bend, tip, 0.037, 0.027, 0.043, 0.034, surface).name = "CurledFingerTip" + str(finger)
			continue
		var x = side * 0.025 + (finger - 1.5) * width * 0.49
		var length = [0.15, 0.174, 0.163, 0.122][finger if side > 0 else 3 - finger]
		var knuckle = Vector3(x, -0.463, -0.094)
		var middle = knuckle + Vector3((finger - 1.5) * 0.004, -length * 0.57, -0.018)
		var tip = knuckle + Vector3((finger - 1.5) * 0.007, -length, -0.051)
		N.segment(parent, knuckle, middle, 0.041 if not thin else 0.031, 0.036, 0.067, 0.055, surface).name = "FingerProximal" + str(finger)
		N.segment(parent, middle, tip, 0.036 if not thin else 0.028, 0.026, 0.054, 0.035, surface).name = "FingerDistal" + str(finger)
		F.beveled_box(parent, tip + Vector3(0, 0.012, -0.019), Vector3(0.021, 0.029, 0.009), detail).name = "Fingernail" + str(finger)
	var root = Vector3(-side * 0.069, -0.372, -0.08)
	var bend = Vector3(-side * 0.145, -0.42, -0.126)
	N.segment(parent, root, bend, 0.065, 0.051, 0.082, 0.06, surface).name = "OpposedThumbBase"
	N.segment(parent, bend, Vector3(-side * 0.121, -0.491, -0.16), 0.051, 0.032, 0.06, 0.039, surface).name = "OpposedThumbTip"

static func face(head: Node3D, surface: Material, pale: Material, dark: Material, reaper: bool = false) -> void:


	N.y_loft(head, [Vector4(-0.23, 0.083, -0.145, 0.045), Vector4(-0.194, 0.135, -0.181, 0.08), Vector4(-0.112, 0.172, -0.183, 0.119), Vector4(-0.02, 0.201, -0.191, 0.153), Vector4(0.098, 0.207, -0.18, 0.17), Vector4(0.205, 0.165, -0.143, 0.143), Vector4(0.268, 0.082, -0.063, 0.075)], pale if reaper else surface, "HumanSkull", 10)
	for side in [-1.0, 1.0]:
		var cheek = N.y_loft(head, [Vector4(-0.145, 0.055, -0.16, -0.085), Vector4(-0.072, 0.068, -0.196, -0.09), Vector4(-0.025, 0.06, -0.178, -0.073)], pale, "Cheekbone", 6)
		cheek.position.x = side * 0.128
		var brow = F.beveled_box(head, Vector3(side * 0.106, 0.092, -0.179), Vector3(0.166, 0.047, 0.075), surface)
		brow.rotation.z = side * 0.12; brow.name = "SupraorbitalBrow"
		if not reaper:
			N.segment(head, Vector3(side * 0.194, 0.04, 0.018), Vector3(side * 0.219, -0.062, -0.012), 0.064, 0.049, 0.082, 0.069, surface).name = "HumanEar"
	N.y_loft(head, [Vector4(-0.073, 0.046, -0.24, -0.155), Vector4(-0.018, 0.039, -0.263, -0.166), Vector4(0.082, 0.023, -0.211, -0.154)], pale, "NoseBridge", 6)
	F.beveled_box(head, Vector3(0, -0.132, -0.183), Vector3(0.154, 0.014, 0.016), dark).name = "MouthSeam"
	N.y_loft(head, [Vector4(-0.224, 0.08, -0.148, -0.063), Vector4(-0.193, 0.108, -0.194, -0.08), Vector4(-0.153, 0.114, -0.182, -0.085)], pale, "Chin", 8)
	if reaper:
		F.beveled_box(head, Vector3(0, -0.032, -0.251), Vector3(0.038, 0.05, 0.018), dark).name = "NasalCavity"
		for tooth in range(6):
			F.beveled_box(head, Vector3((tooth - 2.5) * 0.025, -0.129, -0.194), Vector3(0.019, 0.045, 0.024), pale).name = "SkullTooth"

static func build(e, rig: Dictionary, form: String, stone: Material, dark: Material, pale: Material, accent: Material) -> void:
	var lean = form in ["reaper", "wraith"]
	var breadth = 0.74 if form == "reaper" else 0.86 if form == "wraith" else 1.0
	N.y_loft(e.model, [Vector4(0.775, 0.215 * breadth, -0.178, 0.16), Vector4(0.915, 0.205 * breadth, -0.172, 0.165), Vector4(1.095, 0.285 * breadth, -0.225, 0.19), Vector4(1.295, 0.381 * breadth, -0.242, 0.213), Vector4(1.425, 0.398 * breadth, -0.196, 0.197), Vector4(1.515, 0.242 * breadth, -0.12, 0.139)], stone, "RibcageToWaist", 10)
	N.y_loft(e.model, [Vector4(0.565, 0.174 * breadth, -0.124, 0.139), Vector4(0.652, 0.294 * breadth, -0.172, 0.192), Vector4(0.766, 0.303 * breadth, -0.189, 0.177), Vector4(0.842, 0.215 * breadth, -0.16, 0.153)], dark, "PelvicGirdle", 10)
	N.segment(e.model, Vector3(0, 1.465, 0.017), Vector3(0, 1.724, -0.02), 0.206, 0.164, 0.204, 0.17, stone).name = "Neck"
	for side in [-1.0, 1.0]:
		N.segment(e.model, Vector3(side * 0.052, 1.466, -0.102), Vector3(side * 0.332 * breadth, 1.424, -0.069), 0.065, 0.095, 0.083, 0.12, pale).name = "Clavicle"
	rig.head = _joint(e.model, Vector3(0, 1.79, -0.045), "Head")
	face(rig.head, stone, pale, dark, form == "reaper")
	if form == "knight":
		N.y_loft(rig.head, [Vector4(-0.187, 0.123, -0.216, -0.118), Vector4(-0.125, 0.185, -0.251, -0.112), Vector4(0.016, 0.214, -0.265, -0.108), Vector4(0.15, 0.204, -0.231, -0.106)], accent, "ClosedVisor", 10)
		F.beveled_box(rig.head, Vector3(0, 0.058, -0.264), Vector3(0.327, 0.034, 0.022), dark).name = "VisorSlit"
		F.beveled_box(rig.head, Vector3(0, 0.02, -0.278), Vector3(0.036, 0.198, 0.034), pale).name = "NasalGuard"
		N.segment(rig.head, Vector3(0, 0.177, -0.08), Vector3(0, 0.285, 0.091), 0.058, 0.05, 0.162, 0.17, pale).name = "HelmetRidge"
		for side in [-1.0, 1.0]:
			for slot in range(3): F.beveled_box(rig.head, Vector3(side * (0.073 + slot * 0.038), -0.083, -0.244 + slot * 0.012), Vector3(0.016, 0.059, 0.016), dark).name = "VisorBreathSlot"
	if form != "wraith":
		for i in range(2):
			var side = -1.0 if i == 0 else 1.0
			var leg = _joint(e.model, Vector3(side * 0.22, 0.72, 0.025), "Leg" + str(i)); e.feet.append(leg)
			var knee = _joint(leg, Vector3(0, -0.34, -0.015), "Knee"); e.knees.append(knee)
			N.segment(leg, Vector3(0, 0.025, 0.005), knee.position, 0.273 * breadth, 0.201 * breadth, 0.285, 0.198, stone).name = "Thigh"
			N.y_loft(knee, [Vector4(-0.085, 0.088, -0.108, 0.079), Vector4(0.025, 0.112, -0.128, 0.091), Vector4(0.08, 0.087, -0.089, 0.068)], accent, "Kneecap")
			N.segment(knee, Vector3(0, -0.027, 0.015), Vector3(0, -0.277, 0.025), 0.184 * breadth, 0.126 * breadth, 0.211, 0.133, stone).name = "ShinAndCalf"
			N.paw(knee, Vector3(0, -0.368, -0.018), 0.251 * breadth, 0.367, 0.132, dark).name = "HumanShoe"
	for i in range(2):
		var side = -1.0 if i == 0 else 1.0
		var arm = _joint(e.model, Vector3(side * 0.44 * breadth, 1.44, 0), "Arm" + str(i)); e.arms.append(arm)
		var forearm = _joint(arm, Vector3(side * 0.1, -0.4, -0.015), "Forearm"); e.forearms.append(forearm)
		N.segment(arm, Vector3(-side * 0.018, 0.02, 0.013), Vector3(side * 0.073, -0.17, 0.02), 0.283 * breadth, 0.239 * breadth, 0.302, 0.244, stone).name = "Deltoid"
		N.segment(arm, Vector3(side * 0.045, -0.105, 0.018), forearm.position, 0.224 * breadth, 0.161 * breadth, 0.242, 0.163, stone).name = "UpperArm"
		N.segment(forearm, Vector3(0, 0.019, 0.009), Vector3(side * 0.025, -0.318, -0.063), 0.207 * breadth, 0.119 * breadth, 0.221, 0.127, stone).name = "ForearmToWrist"
		_hand(forearm, side, stone, pale, lean, form == "knight")
		if form == "knight" and i == 0:
			if e.species_id != "shard_sentinel":
				N.segment(forearm, Vector3(0, -0.565, -0.171), Vector3(0, -0.285, -0.171), 0.062, 0.062, 0.062, 0.062, dark).name = "SwordGrip"
				N.segment(forearm, Vector3(-0.18, -0.255, -0.171), Vector3(0.18, -0.255, -0.171), 0.062, 0.052, 0.062, 0.052, accent).name = "SwordGuard"
				N.y_loft(forearm, [Vector4(-0.23, 0.052, -0.19, -0.15), Vector4(0.47, 0.053, -0.19, -0.15), Vector4(0.59, 0.005, -0.183, -0.155)], accent, "SwordBlade", 4)
		elif form == "knight":
			var shield = N.y_loft(forearm, [Vector4(-0.59, 0.04, -0.322, -0.23), Vector4(-0.47, 0.181, -0.34, -0.218), Vector4(-0.18, 0.246, -0.35, -0.21), Vector4(0.074, 0.184, -0.322, -0.23)], pale, "Shield", 8)
			shield.position.x = side * 0.066
