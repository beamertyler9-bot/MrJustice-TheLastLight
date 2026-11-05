extends OmniLight3D
## A hearth fire's light: breathes and flickers, but only does any work when close by.

var _clock := 0.0
var _base := -1.0

func _process(dt: float) -> void:
	if _base < 0.0: _base = light_energy
	_clock += dt
	if not is_visible_in_tree(): return
	light_energy = _base * (0.86 + 0.09 * sin(_clock * 7.3) + 0.05 * sin(_clock * 17.1 + 1.3))
