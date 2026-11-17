extends SceneTree
var failures: Array[String] = []
func expect(value: bool, message: String) -> void:
 if not value: failures.append(message)
func _initialize():
 var atlas = preload("res://scripts/world_atlas.gd").new()
 var site: Dictionary
 for s in atlas.sites():
  if s.id == "alderhaven": site = s
 expect(site.pos.is_equal_approx(Vector2(1088, 2430)), "approved town origin")
 var plan = preload("res://scripts/regional_settlements.gd").plan(atlas, site)
 expect(plan.plots.size() == 36, "36 plots")
 expect(plan.districts.size() == 6, "six wards")
 var first: Dictionary = plan.plots[0]
 expect(first.p.is_equal_approx(Vector2(-26, -13)), "plot 01 matches blueprint")
 expect(is_equal_approx(first.w, 10.0) and is_equal_approx(first.d, 14.0), "east-facing footprint swaps local width/depth")
 expect(Vector2(sin(first.heading), cos(first.heading)).dot(Vector2.RIGHT) > 0.99, "plot 01 entrance faces east")
 for i in range(plan.plots.size()):
  var plot: Dictionary = plan.plots[i]
  expect(plot.index == i, "stable plot index %d" % i)
  expect(plot.has("approach") and plot.has("title"), "authored approach and title %d" % i)
 var master = preload("res://scripts/alderhaven_masterplan.gd")
 var roads = master.roads(site.pos)
 for plot in plan.plots:
  var end: Vector2 = site.pos + plot.approach
  var nearest = INF
  for road in roads: nearest = minf(nearest, end.distance_to(Geometry2D.get_closest_point_to_segment(end, road[0], road[1])))
  expect(nearest < 0.01, "approach joins network %d" % plot.index)
  var direction = Vector2(sin(plot.heading), cos(plot.heading))
  var entry: Vector2 = plot.p + direction * (plot.d * 0.5 + 1.5)
  for other in plan.plots:
   if plot.index == other.index: continue
   var rect = Rect2(other.p - other.footprint * 0.5, other.footprint).grow(0.25)
   for i in range(21): expect(not rect.has_point(entry.lerp(plot.approach, float(i) / 20.0)), "approach crosses plot %d->%d" % [plot.index, other.index])
 expect(atlas.path_distance(site.pos + Vector2(0, -100)) > 5.0, "no obsolete trail through civic buildings")
 var fixed = preload("res://scripts/fixed_world.gd")
 for p in [site.pos + Vector2(-115, -40), site.pos + Vector2(-90, 28), Vector2(500, -500)]:
  expect(absf(fixed.height_at(p) - fixed._original_height(p)) < 0.001, "river and distant terrain unchanged at %s" % p)
 expect(fixed.spawn().is_equal_approx(Vector2(13, 72)) if bool(ProjectSettings.get_setting("application/config/brindlewick_preview", false)) else fixed.spawn().is_equal_approx(site.pos + Vector2(0, 112)), "selected settlement preview spawn")
 if failures.is_empty(): print("ALDERHAVEN_PLAN_PASS"); quit(0)
 else:
  for message in failures: print("FAIL: ", message)
  quit(1)
