extends RefCounted

const O = preload("res://scripts/world_overhaul.gd")
static func build(camp: Node3D):
	var tent = Node3D.new(); tent.name = "CampShelter"; tent.position = Vector3(-2, 0, -2); tent.rotation.y = -0.2; camp.add_child(tent)
	O.fit(tent, "u29_survival_tent_canvas", Vector3.ZERO, Vector3(2.4, 1.6, 2.75))
	O.fit(tent, "u29_survival_bedroll", Vector3(0, 0.03, -0.15), Vector3(0.85, 0.3, 1.9))
	O.fit(camp, "u29_survival_campfire_pit", Vector3.ZERO, Vector3(1.55, 0.35, 1.5))
	var seat = O.fit(camp, "u29_survival_tree_log_small", camp.REST_SPOT, Vector3(0.26, 0.26, 1.4), atan2(camp.REST_SPOT.x, camp.REST_SPOT.z) + PI * 0.5)
	seat.name = "FittedLog"
	O.fit(camp, "interior_mdvl_interiors_potcrane_01", Vector3(-0.95, 0, -0.1), Vector3(0.15, 1.1, 0.75), PI * 0.5)
	O.fit(camp, "interior_mdvl_interiors_pot_01", Vector3(-0.48, 0.41, -0.12), Vector3(0.42, 0.34, 0.38))
	O.fit(camp, "qprop_crate_wooden", Vector3(2.1, 0, -0.8), Vector3(0.75, 0.55, 0.7))
	O.fit(camp, "qprop_mug", Vector3(1.96, 0.56, -0.8), Vector3(0.18, 0.16, 0.18))
	O.fit(camp, "treat_cookie", Vector3(2.22, 0.56, -0.8), Vector3(0.21, 0.07, 0.2))
	camp.set_meta("replacement_art", 29)
