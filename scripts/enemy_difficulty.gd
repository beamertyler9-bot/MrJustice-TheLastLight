extends RefCounted


const HEALTH_SCALE := 2.0
const PURSUIT_SCALE := 1.22
const DAMAGE_SCALE := 1.5
const WINDUP_SCALE := 0.9
const RECOVERY_SCALE := 0.82
const COOLDOWN_SCALE := 0.78

static func health(base: int) -> int:
	return maxi(1, ceili(float(base) * HEALTH_SCALE))

static func damage(base: int) -> int:
	return maxi(1, ceili(float(base) * DAMAGE_SCALE))

static func profiles(authored: Dictionary) -> Dictionary:
	var result := {}
	for species in authored:
		var p: Dictionary = authored[species].duplicate()
		p.hp = health(int(p.hp))
		p.damage = damage(int(p.damage))
		p.speed = minf(4.4, float(p.speed) * PURSUIT_SCALE)
		p.windup = maxf(0.72 if bool(p.get("boss", false)) else 0.48, float(p.windup) * WINDUP_SCALE)
		p.recovery = maxf(0.4, float(p.recovery) * RECOVERY_SCALE)
		p.cooldown = maxf(1.15, float(p.cooldown) * COOLDOWN_SCALE)
		result[species] = p
	return result
