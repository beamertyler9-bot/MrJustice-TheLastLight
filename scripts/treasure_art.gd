extends Node3D

static var scene: PackedScene
var opened = false
var elapsed = 0.0
var from_angle = 0.0
var retire = false
const DURATION = 0.72
static func build(parent: Node3D, size: Vector3 = Vector3(1.45, 0.85, 1.05)) -> Node3D:
	if scene == null: scene = load("res://assets/replacements/treasure_chest.scn")
	var art = scene.instantiate(); art.set_script(load("res://scripts/treasure_art.gd"))
	var bounds: Vector3 = art.get_meta("closed_bounds")
	art.scale = Vector3(size.x, size.y * 1.22, size.z) / bounds
	art.position = Vector3(0, -size.y * 0.5, 0)
	parent.add_child(art); art.add_to_group("batch_dynamic"); art.set_process(false)
	parent.set_meta("replacement_art", 29)
	return art
static func open(parent: Node3D, animate: bool = true, dispose: bool = false):
	var art = parent.get_node_or_null("TreasureChest")
	if art == null: return
	art.retire = dispose
	if dispose: parent.remove_from_group("interactable")
	art.set_open(true, animate)
func set_open(value: bool, animate: bool = true):
	if opened == value and elapsed == 0: return
	opened = value
	if not animate:
		get_node("Lid").rotation.x = -1.25 if opened else 0.0; elapsed = 0; set_process(false); return
	from_angle = get_node("Lid").rotation.x; elapsed = DURATION; set_process(true)
func _process(dt: float):
	elapsed = maxf(0, elapsed - dt)
	var progress = 1.0 - elapsed / DURATION; var eased = 1.0 - pow(1.0 - progress, 3)
	get_node("Lid").rotation.x = lerpf(from_angle, -1.25 if opened else 0.0, eased)
	if elapsed == 0:
		set_process(false)
		if retire: get_parent().queue_free()
