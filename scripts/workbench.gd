extends Node3D
const B = preload("res://scripts/build.gd")
func _ready() -> void:
	add_to_group("interactable")
	add_to_group("workbench")
	set_meta("kind", "workbench")
	set_meta("label", "Use crafting table · 3 × 3")
	var art = load("res://scripts/world_overhaul.gd").fit(self, "interior_mdvl_interiors_workbench_01", Vector3.ZERO, Vector3(1.65, 1.1, 1.16))
	art.name = "CraftingWorkbenchArt"


	var support = BoxShape3D.new(); support.size = Vector3(1.65, 0.18, 1.16)
	B.solid(self, Vector3(0, 0.98, 0), support)
	set_meta("replacement_art", 29)
	B.batch_static(self)
