extends RefCounted
## Combat feedback on enemies, whatever hit them (fists, weapons, spells, beams):
##  - the whole body flashes white for an instant;
##  - a damage number pops up, arcs and fades (rapid hits from one source add up in one
##    number instead of spamming);
##  - on defeat, a bright pop: a flash, a burst of sparks, a puff of dust and a ring;
##  - when an enemy first spots Mr. Justice, a "!" pops over its head and it hops.

const FLASH_TIME := 0.14


## A white flash over every mesh of the enemy's model.
static func flash(enemy: Node3D, strength: float = 1.0, tint: Color = Color(1, 0.98, 0.9), time: float = FLASH_TIME) -> void:
	var model = enemy.get("model")
	if not model is Node3D or not is_instance_valid(model): return
	var meshes: Array = enemy.get_meta("feel_meshes", [])
	if meshes.is_empty():
		for node in model.find_children("*", "GeometryInstance3D", true, false): meshes.append(node)
		enemy.set_meta("feel_meshes", meshes)
	var overlay: StandardMaterial3D = enemy.get_meta("feel_flash") if enemy.has_meta("feel_flash") else null
	if overlay == null:
		overlay = StandardMaterial3D.new()
		overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		overlay.albedo_color = Color(1, 0.98, 0.9, 0)
		enemy.set_meta("feel_flash", overlay)
	for node in meshes:
		if is_instance_valid(node): node.material_overlay = overlay
	var old: Tween = enemy.get_meta("feel_flash_tween") if enemy.has_meta("feel_flash_tween") else null
	if old != null and old.is_valid(): old.kill()
	overlay.albedo_color = Color(tint.r, tint.g, tint.b, clampf(0.72 * strength, 0.3, 0.85))
	var tween := enemy.create_tween()
	tween.tween_property(overlay, "albedo_color:a", 0.0, time).set_ease(Tween.EASE_IN)
	tween.tween_callback(func ():
		for node in meshes:
			if is_instance_valid(node) and node.material_overlay == overlay: node.material_overlay = null)
	enemy.set_meta("feel_flash_tween", tween)


## A popping damage number above the enemy.
static func number(enemy: Node3D, amount: int, height: float) -> void:
	var now := Engine.get_physics_frames()
	var label = enemy.get_meta("feel_number") if enemy.has_meta("feel_number") else null
	if is_instance_valid(label) and now - int(enemy.get_meta("feel_number_frame", -100)) < 14:
		# Still fresh: add this hit to it and pop it again.
		amount += int(label.get_meta("amount", 0))
	else:
		label = Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.fixed_size = false
		label.pixel_size = 0.0075
		label.font_size = 72
		label.outline_size = 18
		label.outline_modulate = Color(0.12, 0.06, 0.04, 0.95)
		label.render_priority = 12; label.outline_render_priority = 11
		label.top_level = true
		enemy.get_parent().add_child(label)
		var drift := Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0))
		label.global_position = enemy.global_position + Vector3.UP * (height + 0.35) + drift * 0.4
		label.set_meta("drift", drift)
	label.set_meta("amount", amount)
	enemy.set_meta("feel_number", label); enemy.set_meta("feel_number_frame", now)
	var heavy := amount >= 5
	label.text = str(amount)
	label.modulate = Color("#ffb347") if heavy else Color("#fff4d6")
	var old: Tween = label.get_meta("tween") if label.has_meta("tween") else null
	if old != null and old.is_valid(): old.kill()
	label.scale = Vector3.ONE * 0.5
	var start: Vector3 = label.global_position
	var drift: Vector3 = label.get_meta("drift", Vector3.ZERO)
	var peak := (1.45 if heavy else 1.15)
	var tween: Tween = label.create_tween()
	tween.tween_property(label, "scale", Vector3.ONE * peak, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector3.ONE * (peak * 0.82), 0.1)
	tween.parallel().tween_property(label, "global_position", start + Vector3.UP * 0.75 + drift * 0.6, 0.62).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.18)
	tween.parallel().tween_property(label, "outline_modulate:a", 0.0, 0.3).set_delay(0.18)
	tween.tween_callback(label.queue_free)
	label.set_meta("tween", tween)


## The defeat pop: flash, sparks and a puff of dust.
static func defeat(game, enemy: Node3D, height: float) -> void:
	flash(enemy, 1.2)
	var effects = game.get("effects")
	var center := enemy.global_position + Vector3.UP * height * 0.55
	if effects != null:
		effects.burst(center, Color("#fff1c4"), 18, 1.35)
		effects.burst(center, Color("#9c9488"), 10, 0.8)


## "!" over the head when an enemy first spots Mr. Justice.
static func notice(enemy: Node3D, height: float) -> void:
	var label := Label3D.new()
	label.text = "!"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.01; label.font_size = 96; label.outline_size = 20
	label.modulate = Color("#ffd24d"); label.outline_modulate = Color(0.25, 0.08, 0.02)
	label.render_priority = 12; label.outline_render_priority = 11
	label.position = Vector3.UP * (height + 0.55)
	label.scale = Vector3.ONE * 0.2
	enemy.add_child(label)
	var tween: Tween = label.create_tween()
	tween.tween_property(label, "scale", Vector3.ONE * 1.25, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector3.ONE, 0.08)
	tween.tween_interval(0.45)
	tween.tween_property(label, "modulate:a", 0.0, 0.2)
	tween.parallel().tween_property(label, "outline_modulate:a", 0.0, 0.2)
	tween.tween_callback(label.queue_free)


## A hot glint just before an enemy's blow lands: the cue to dodge.
static func warn(enemy: Node3D) -> void:
	flash(enemy, 0.62, Color("#ff7a3d"), 0.2)
