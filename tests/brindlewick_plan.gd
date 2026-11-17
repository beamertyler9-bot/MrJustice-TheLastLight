extends SceneTree
var failures: Array[String] = []
func expect(ok: bool, label: String):
 if not ok: failures.append(label); print("FAIL: ", label)
func _initialize():
 var atlas = load("res://scripts/world_atlas.gd").new()
 var site: Dictionary = atlas.sites().filter(func (s): return s.id == "brindlewick")[0]
 var plots = load("res://scripts/locations.gd").city_plots(site, 64127)
 var approved = JSON.parse_string(FileAccess.get_file_as_string("res://docs/settlement-revamps/brindlewick-proposal-v1.json"))
 expect(plots.size() == 12, "twelve approved buildings")
 for row in approved.plots:
  var plot: Dictionary = plots[int(row.number) - 1]
  expect(plot.p.distance_to(Vector2(row.position[0], row.position[1])) < 0.01, "approved position %d" % row.number)
  expect(plot.get("title", "") == row.title, "approved title %d" % row.number)
 var master = load("res://scripts/brindlewick_masterplan.gd")
 var fixed = load("res://scripts/fixed_world.gd")
 for plot in plots:
  var direction = Vector2(sin(plot.heading), cos(plot.heading))
  var front = plot.p + direction * (plot.d * 0.5 + 1.5)
  var near = INF
  for road in master.streets(): near = minf(near, plot.approach.distance_to(Geometry2D.get_closest_point_to_segment(plot.approach, road.a, road.b)))
  expect(near < 0.01, "approach connected %d" % plot.index)
  for other in plots:
   if other.index == plot.index: continue
   var rect = Rect2(other.p - other.footprint * 0.5, other.footprint).grow(0.4)
   for i in range(21): expect(not rect.has_point(front.lerp(plot.approach, float(i) / 20)), "clear approach %d" % plot.index)
  var center_height: float = fixed.height_at(site.pos + plot.p)
  for dx in [-0.5, 0.5]:
   for dz in [-0.5, 0.5]: expect(absf(fixed.height_at(site.pos + plot.p + Vector2(dx * plot.footprint.x, dz * plot.footprint.y)) - center_height) < 0.025, "level full pad %d" % plot.index)
 for mine in [Vector2(-65, -75), Vector2(-65, -78), Vector2(-65, -84)]: expect(absf(fixed.height_at(mine) - fixed._original_height(mine)) < 0.001, "preserve mine profile at %s" % mine)
 for remote in [Vector2(500, -500), Vector2(-500, 200)]: expect(absf(fixed.height_at(remote) - fixed._original_height(remote)) < 0.001, "unaffected remote terrain")
 expect(atlas.path_distance(site.pos + Vector2(39, -10)) > 3, "old Valley Road removed below shop")
 for endpoint in [Vector2(-78, -64), Vector2(68, -16)]: expect(atlas.path_distance(site.pos + endpoint) < 0.01, "regional road connection")
 if not failures.is_empty(): quit(1); return
 print("BRINDLEWICK_PLAN_PASS"); quit()
