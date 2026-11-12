extends Node



signal changed
const MAX_ENTRIES := 64
var entries: Dictionary = {}
var density := Vector2.ZERO
var oversampling := 0.0
var bake_count := 0
var _serial := 0

class PaintLayer extends Control:
	var paint: Callable
	var bounds: Rect2
	var density: Vector2
	func _draw() -> void:
		draw_set_transform(-bounds.position * density, 0, density)
		paint.call(self)

func lookup(key: String):
	return entries[key].texture if entries.has(key) else null

func prepare(key: String, bounds: Rect2, pixel_density: Vector2, paint: Callable) -> void:
	if DisplayServer.get_name() == "headless": return
	var font_sampling := get_viewport().get_oversampling()
	if not pixel_density.is_equal_approx(density) or not is_equal_approx(oversampling, font_sampling):
		entries.clear()
		for child in get_children(): child.queue_free()
		density = pixel_density
		oversampling = font_sampling
	if entries.has(key): return
	while entries.size() >= MAX_ENTRIES:
		entries.erase(entries.keys()[0])
	_serial += 1
	entries[key] = {"texture": null, "serial": _serial}
	_bake.call_deferred(key, bounds, pixel_density, paint, _serial)

func _bake(key: String, bounds: Rect2, pixel_density: Vector2, paint: Callable, serial: int) -> void:
	if not entries.has(key) or entries[key].serial != serial: return
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.oversampling_override = oversampling
	viewport.transparent_bg = true


	viewport.size = Vector2i((bounds.size * pixel_density).round())
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	var layer := PaintLayer.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.paint = paint
	layer.bounds = bounds
	layer.density = pixel_density
	viewport.add_child(layer)
	add_child(viewport)
	await RenderingServer.frame_post_draw
	if is_instance_valid(viewport):
		if entries.has(key) and entries[key].serial == serial:
			var image := viewport.get_texture().get_image()


			image.convert(Image.FORMAT_RGBA8)
			var pixels := image.get_data()
			for i in range(0, pixels.size(), 4):
				var alpha := int(pixels[i + 3])
				if alpha > 0 and alpha < 255:
					for c in range(3): pixels[i + c] = mini(255, roundi(float(pixels[i + c]) * 255.0 / alpha))
			image = Image.create_from_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, pixels)
			entries[key].texture = ImageTexture.create_from_image(image)
			bake_count += 1
			changed.emit()
		viewport.queue_free()
