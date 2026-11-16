extends SceneTree
## Plans Barrowback's walk: a long slow loop through the open country of Mosswake Valley,
## Windbell Plains, Prismere, the Sunspire Dunes and S'morewood, steering wide of towns,
## villages, caves, dungeons and other sites, and of Hollowmourn and the Ashfall Caldera.
## Writes assets/world/barrowback_route.json (a closed loop of points, metres).
##   godot --headless --path . --script res://tools/barrowback_route.gd

const RegionSites = preload("res://scripts/region_sites.gd")
const RegionalSettlements = preload("res://scripts/regional_settlements.gd")
const OUT := "res://assets/world/barrowback_route.json"
const ANCHORS := [Vector2(700, -900), Vector2(1900, -650), Vector2(2900, -300), Vector2(3900, 400), Vector2(5200, 1300),
	Vector2(5600, 2400), Vector2(3800, 2700), Vector2(2500, 2000), Vector2(1200, 1500), Vector2(300, 400)]
const AVOID_REGIONS := [13, 14]
const CLEARANCE := 75.0
const STEP := 60.0

var atlas


func _initialize() -> void:
	atlas = load("res://scripts/world_atlas.gd").new()
	var route: Array = []
	var moved := 0
	for k in range(ANCHORS.size()):
		var a: Vector2 = ANCHORS[k]; var b: Vector2 = ANCHORS[(k + 1) % ANCHORS.size()]
		var count := maxi(1, int(a.distance_to(b) / STEP))
		var across := (b - a).normalized().orthogonal()
		for i in range(count):
			var p := a.lerp(b, float(i) / count)
			if not _clear(p):
				var found := false
				for reach in range(40, 520, 40):
					for side in [1.0, -1.0]:
						var q: Vector2 = p + across * reach * side
						if _clear(q): p = q; found = true; break
					if found: break
				moved += 1
			route.append(p)
	# Smooth the line so its turns are gentle.
	for pass_i in range(4):
		var smoothed: Array = []
		for i in range(route.size()):
			var prev: Vector2 = route[(i - 1 + route.size()) % route.size()]
			var next: Vector2 = route[(i + 1) % route.size()]
			var q: Vector2 = (prev + route[i] * 2.0 + next) * 0.25
			smoothed.append(q if _clear(q) else route[i])
		route = smoothed
	var length := 0.0; var blocked := 0
	for i in range(route.size()):
		length += route[i].distance_to(route[(i + 1) % route.size()])
		if not _clear(route[i]): blocked += 1
	var points: Array = []
	for p in route: points.append([snappedf(p.x, 0.1), snappedf(p.y, 0.1)])
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string(JSON.stringify({"points": points, "length": snappedf(length, 1.0)}))
	print("ROUTE points=%d length=%.0f m moved=%d still_blocked=%d" % [route.size(), length, moved, blocked])
	quit()


func _clear(p: Vector2) -> bool:
	if int(atlas.region_at(p)) in AVOID_REGIONS: return false
	if atlas.reserved(p, CLEARANCE) or RegionSites.reserved(atlas, p, CLEARANCE) or RegionalSettlements.reserved(atlas, p, CLEARANCE): return false
	return true
