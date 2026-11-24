extends OmniLight3D
## Storm light round the Stormhorn Matriarch's antlers: a steady glow broken now and then by a
## bright double flash, like lightning arcing between the tines.

var base_energy := 1.4
var clock := 0.0
var next_flash := 1.5
var flash := 0.0


func _ready() -> void:
	base_energy = light_energy
	next_flash = randf_range(0.8, 2.6)


func _process(delta: float) -> void:
	clock += delta
	next_flash -= delta
	if next_flash <= 0.0:
		flash = 1.0
		next_flash = randf_range(1.2, 3.4)
	flash = maxf(flash - delta * 5.0, 0.0)
	var double := 1.0 if flash > 0.55 or (flash > 0.1 and flash < 0.3) else 0.0
	light_energy = base_energy * (0.8 + 0.12 * sin(clock * 7.0) + double * 1.6)
