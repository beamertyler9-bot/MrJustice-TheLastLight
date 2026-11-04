extends Node3D


var renderer: WeakRef
var owner_id: int
func setup(target: Node3D, id: int) -> void:
	renderer = weakref(target); owner_id = id; set_notify_transform(true)
func _notification(what: int) -> void:
	if what != NOTIFICATION_TRANSFORM_CHANGED or renderer == null: return
	var target = renderer.get_ref()
	if is_instance_valid(target): target.owner_transform_changed(owner_id)
func detach() -> void:
	renderer = null; set_notify_transform(false); queue_free()
