extends Node3D

const B = preload("res://scripts/build.gd")
const Art = preload("res://scripts/roadlife_art.gd")
const Resident = preload("res://scripts/resident.gd")
const P = preload("res://scripts/locations.gd")
const MAX_TRAVELERS = 8
const MAX_STOPS = 3
const SPAWN_DISTANCE = 105.0
const RETIRE_DISTANCE = 145.0
var game
var routes: Array = []
var travelers: Array = []
var stops: Array = []
var live: Dictionary = {}
var live_stops: Dictionary = {}
var clock = 0.0
var select_clock = 0.0
var rest_times: Dictionary = {}
var fish_node: Node3D
var fish_age = 0.0
var fish_bite = 0.0
var fish_announced = false
var fishing_visual: Node3D
func setup(context) -> void:
 name = "RoadsideLife"; game = context; clock = game.state.journey_time
 var previous = ""; var line: Dictionary = {}
 for road in game.world.atlas.roads():
  if str(road.name) == "Fizzpeak summit trail": continue
  if str(road.name) != previous or line.points[-1].distance_to(road.a) > 0.1:
   if not line.is_empty(): _finish_route(line)
   line = {"name": str(road.name), "points": [road.a], "lengths": [0.0], "length": 0.0}; previous = str(road.name)
  line.length += road.a.distance_to(road.b); line.points.append(road.b); line.lengths.append(line.length)
 if not line.is_empty(): _finish_route(line)
 _plan_docks()
 set_meta("traveler_count", travelers.size()); set_meta("stop_count", stops.size())
func _finish_route(line: Dictionary) -> void:
 if line.length < 80: return
 var index = routes.size(); routes.append(line)
 var count = maxi(3, ceili(line.length / 280.0))
 for i in count:
  var kind = "trader" if i % 4 == 0 else "rider" if i % 3 == 0 else "walker"
  travelers.append({"id": "road_%d_%d" % [index, i], "route": index, "offset": line.length * (i + 0.25) / count, "kind": kind, "speed": 1.05 if kind == "trader" else 2.3 if kind == "rider" else 0.9})

 for fraction in [0.38, 0.62, 0.24, 0.76]:
  var sample = sample_route(index, line.length * fraction); var normal = Vector2(-sample.direction.y, sample.direction.x)
  var point: Vector2 = sample.point + normal * 12
  if _camp_safe(point):
   stops.append({"id": "waystop_%d" % index, "kind": "camp", "point": point, "direction": sample.direction, "name": line.name + " waystop"}); break
func _camp_safe(p: Vector2) -> bool:
 if game.world.atlas.reserved(p, 7) or not game.world.dry_surface_at(p, 4): return false
 var h = game.world.surface_height_at(p.x, p.y)
 for offset in [Vector2(3, 3), Vector2(-3, 3), Vector2(3, -3), Vector2(-3, -3)]:
  if absf(h - game.world.surface_height_at(p.x + offset.x, p.y + offset.y)) > 1.8: return false
 var fixed = preload("res://scripts/fixed_world.gd")
 for z in range(floori((p.y - 6) / 48), floori((p.y + 6) / 48) + 1):
  for x in range(floori((p.x - 6) / 48), floori((p.x + 6) / 48) + 1):
   for tree in fixed.chunk(Vector2i(x, z)).get("trees", []):
    if tree is Dictionary and tree.has("pos") and Vector2(tree.pos.x, tree.pos.z).distance_to(p) < 5: return false
 return true
func _plan_docks() -> void:
 var index = 0
 for lake in game.world.atlas.lakes():
  if lake.kind == "lava" or float(lake.height) > 700: continue
  var best = {}; var score = INF
  for edge in lake.outline:
   var out: Vector2 = (edge - lake.pos).normalized()
   for distance in [2.0, 5.0, 9.0, 14.0]:
    var p: Vector2 = edge + out * distance; var h = game.world.surface_height_at(p.x, p.y)
    var inner: Vector2 = p - out * 8.0
    if not game.world.dry_surface_at(p, 0.6) or absf(h - lake.height) > 2.4: continue
    if preload("res://scripts/water_profile.gd").liquid_at(inner).is_empty(): continue
    if game.world.atlas.reserved(p, 3): continue
    var road_distance = game.world.atlas.path_distance(p)
    var cost = (road_distance if is_finite(road_distance) else 10000.0 + p.distance_to(lake.pos) * 0.01) + absf(h - lake.height) * 8
    if cost < score: score = cost; best = {"id": "fishing_%d" % index, "kind": "dock", "point": p, "direction": -out, "water_height": float(lake.height), "name": "Cola Lake angling outpost" if lake.kind == "cola" else "Lakeside angling outpost"}
  if not best.is_empty(): stops.append(best); index += 1
func sample_route(index: int, distance: float) -> Dictionary:
 var route: Dictionary = routes[index]; var phase = fposmod(distance, route.length * 2); var reverse = phase > route.length
 var d = route.length * 2 - phase if reverse else phase
 var lo = 0; var hi = route.points.size() - 2
 while lo < hi:
  var mid = (lo + hi) / 2
  if route.lengths[mid + 1] < d: lo = mid + 1
  else: hi = mid
 var a: Vector2 = route.points[lo]; var b: Vector2 = route.points[lo + 1]
 var t = (d - route.lengths[lo]) / maxf(0.001, route.lengths[lo + 1] - route.lengths[lo])
 var direction = (b - a).normalized() * (-1 if reverse else 1)
 return {"point": a.lerp(b, t), "direction": direction, "distance": d}
func traveler_position(record: Dictionary) -> Dictionary:
 var sample = sample_route(record.route, record.offset + clock * record.speed)
 sample.point += Vector2(-sample.direction.y, sample.direction.x) * 0.7
 return sample
func _process(dt: float) -> void:
 if game == null or game.mode != "play" or not is_instance_valid(game.player): return
 clock += dt; select_clock -= dt
 if select_clock <= 0: select_clock = 0.25; refresh(game.player.global_position)
 for id in live:
  var item: Dictionary = live[id]; var record: Dictionary = item.record; var sample = traveler_position(record); var actor = item.actor
  var near = actor.global_position.distance_squared_to(game.player.global_position) < 3.2 * 3.2

  if near: record.offset -= dt * record.speed
  else:
   var p: Vector2 = sample.point; actor.position = Vector3(p.x, game.world.surface_height_at(p.x, p.y), p.y)
   actor.rotation.y = lerp_angle(actor.rotation.y, atan2(sample.direction.x, sample.direction.y), minf(1, dt * 8))
  item.debt += dt
  if item.debt < (1.0 / 15.0 if actor.position.distance_squared_to(game.player.position) > 45 * 45 else 1.0 / 30.0): continue
  var step = float(item.debt); item.debt = 0.0
  actor.animate(step, record.kind != "rider" and not near, near)
  if record.kind == "rider":
   _riding_pose(actor)
   var rig: Dictionary = item.mount
   for i in rig.legs.size(): rig.legs[i].rotation.x = sin(clock * 6.0 + (i % 2) * PI + (PI if i >= 2 else 0)) * 0.28 * (0 if near else 1)
   actor.visual.position.y = float(rig.saddle) - 0.85 + sin(clock * 12) * 0.025 * (0 if near else 1)
  for wheel in item.wheels: wheel.rotation.x = -(clock * record.speed) / 0.45
 for stop in live_stops.values():
  for child in stop.get_children():
   if child is AnimatableBody3D and child.has_method("animate"): child.animate(dt, false, false)
 _tick_fishing(dt)
func refresh(viewer: Vector3) -> void:
 if not game.world.interior_at(viewer).is_empty():
  for id in live: live[id].actor.queue_free()
  for id in live_stops: live_stops[id].queue_free()
  live.clear(); live_stops.clear(); _cancel_fishing(); return
 var choices = []
 for record in travelers:
  var p: Vector2 = traveler_position(record).point
  var d = Vector2(viewer.x, viewer.z).distance_squared_to(p)
  if d < RETIRE_DISTANCE * RETIRE_DISTANCE:
   var h = game.world.surface_height_at(p.x, p.y); d += pow(viewer.y - h, 2)
  if live.has(record.id) and d > RETIRE_DISTANCE * RETIRE_DISTANCE: live[record.id].actor.queue_free(); live.erase(record.id)
  if d < SPAWN_DISTANCE * SPAWN_DISTANCE and not live.has(record.id): choices.append({"record": record, "distance": d})
 choices.sort_custom(func (a, b): return a.distance < b.distance)
 if live.size() < MAX_TRAVELERS and not choices.is_empty(): _spawn(choices[0].record)
 choices = []
 for record in stops:
  var p: Vector2 = record.point; var d = Vector2(viewer.x, viewer.z).distance_squared_to(p)
  if d < RETIRE_DISTANCE * RETIRE_DISTANCE: d += pow(viewer.y - game.world.surface_height_at(p.x, p.y), 2)
  if live_stops.has(record.id) and d > RETIRE_DISTANCE * RETIRE_DISTANCE: live_stops[record.id].queue_free(); live_stops.erase(record.id)
  if d < SPAWN_DISTANCE * SPAWN_DISTANCE and not live_stops.has(record.id): choices.append({"record": record, "distance": d})
 choices.sort_custom(func (a, b): return a.distance < b.distance)
 if live_stops.size() < MAX_STOPS and not choices.is_empty(): _build_stop(choices[0].record)
func _resident(parent: Node3D, id: String, title: String, shop: String, lines: Array) -> Node3D:
 var actor = Resident.new(); parent.add_child(actor)
 actor.configure({"id": id, "name": title, "shop": shop, "dialogue": lines, "race": "human", "role": "merchant" if shop != "" else "neighbor", "coat": "#8c9276"}, PackedVector3Array())
 return actor
func _spawn(record: Dictionary) -> void:
 var sample = traveler_position(record); var p: Vector2 = sample.point
 var camel = game.world.biome_at(p.x, p.y) == 12
 var title = "Caravan trader" if record.kind == "trader" else "Desert rider" if camel and record.kind == "rider" else "Road rider" if record.kind == "rider" else "Road traveler"
 var actor = _resident(self, record.id, title, "general" if record.kind == "trader" else "", ["I travel the " + str(routes[record.route].name) + ". Follow the road and you will find shelter.", "The waystop fires are free to use. At the lakes, wait for the float to dip before reeling in.", "Have a look at my cart. I buy lake fish, and carry food, camp kits and remedies." if record.kind == "trader" else "The roads have been safer since someone started pushing back the Scrappers."])
 actor.position = Vector3(p.x, game.world.surface_height_at(p.x, p.y), p.y); actor.rotation.y = atan2(sample.direction.x, sample.direction.y)
 var item = {"actor": actor, "record": record, "wheels": [], "mount": {}, "debt": 0.0}
 if record.kind == "trader": item.wheels = Art.cart(actor)
 if record.kind == "rider":
  item.mount = Art.mount(actor, camel); actor.visual.position.y = float(item.mount.saddle) - 0.85
  actor.get_node("ResidentCapsule").position.y += actor.visual.position.y
  _riding_pose(actor)
 live[record.id] = item
func _riding_pose(actor) -> void:
 var skeleton = actor.imported_actor.skeleton
 for side in ["L", "R"]:
  var thigh = skeleton.find_bone("Thigh_" + side); var calf = skeleton.find_bone("Calf_" + side)
  skeleton.set_bone_pose_rotation(thigh, Quaternion(Vector3.RIGHT, -1.05) * Quaternion(Vector3.FORWARD, 0.22 if side == "L" else -0.22))
  skeleton.set_bone_pose_rotation(calf, Quaternion(Vector3.RIGHT, 1.35))
func _build_stop(record: Dictionary) -> Node3D:
 var root = Node3D.new(); root.name = record.id; add_child(root); var p: Vector2 = record.point
 root.position = Vector3(p.x, game.world.surface_height_at(p.x, p.y), p.y); root.rotation.y = atan2(record.direction.x, record.direction.y)
 root.set_meta("roadlife_stop", record.kind)
 if record.kind == "camp":
  Art.campsite(root)
  var rest = P.interaction(root, record.id + "_rest", "waystop_rest", "Rest by the waystop fire", Vector3(-1.8, 0.4, 1.2)); rest.set_meta("title", record.name)
  P.interaction(root, record.id + "_cache", "waystop_cache", "Read the travel journal and check supplies", Vector3(1.5, 0.5, 0.8))
 else:
  var wy = float(record.water_height) - root.position.y; Art.dock(root, wy, Callable(game.world, "surface_height_at"))
  var actor = _resident(root, record.id + "_angler", "Lakeside angler", "", ["Craft a fishing rod with three timber planks and two string. Merchants sell string. Cast, then wait for the float to dip. Interact again as soon as you see REEL IN.", "Lake fish fetch a good price with the wandering traders. Every lake has a story; patience is how you hear it."])
  actor.position = Vector3(-0.5, wy + 0.74, 5.6); actor.rotation.y = 0.2
  var fish = P.interaction(root, record.id + "_cast", "fishing", "Cast a line", Vector3(0.35, wy + 0.9, 7.2))
  fish.set_meta("water_height", record.water_height)
  var bobber = B.ball(root, Vector3(0.4, wy + 0.05, 10), Vector3(0.12, 0.15, 0.12), B.mat("#e5cf88")); fish.set_meta("bobber_path", fish.get_path_to(bobber))
 live_stops[record.id] = root; return root
func _tick_fishing(dt: float) -> void:
 if not is_instance_valid(fish_node): _cancel_fishing(); return
 if game.player.global_position.distance_to(fish_node.global_position) > 3.8: _cancel_fishing(); return
 fish_age += dt
 var bobber = fish_node.get_node_or_null(fish_node.get_meta("bobber_path", NodePath("")))
 if bobber != null: bobber.position.y = float(fish_node.get_meta("water_height")) - bobber.get_parent().global_position.y + 0.05 + sin(fish_age * 4) * 0.025 - (0.15 if fish_age >= fish_bite else 0.0)
 if fish_age >= fish_bite and not fish_announced:
  fish_announced = true; fish_node.set_meta("label", "REEL IN! Interact now"); game.toast("The float dipped! Interact now to reel in.", 1.1); game.audio.cue("collect")
 if fish_age > fish_bite + 1.15: game.toast("The fish slipped away. Cast again when ready."); _cancel_fishing()
func _cancel_fishing() -> void:
 if is_instance_valid(fishing_visual): fishing_visual.queue_free()
 fishing_visual = null
 if is_instance_valid(fish_node): fish_node.set_meta("label", "Cast a line")
 fish_node = null; fish_age = 0; fish_announced = false
func interact(node: Node3D) -> bool:
 var kind = str(node.get_meta("kind", "")); var state = game.state; var id = str(node.get_meta("id", ""))
 if kind == "fishing":
  if int(state.items.get("fishing_rod", 0)) < 1: game.toast("Craft a fishing rod: 3 timber planks + 2 string. Merchants sell string.", 4); return true
  if node != fish_node:
   _cancel_fishing(); fish_node = node; fishing_visual = load("res://scripts/fishing_visual.gd").new(); add_child(fishing_visual); fishing_visual.setup(game.player, node.get_node(node.get_meta("bobber_path"))); fish_bite = 2.3 + fposmod(clock * 0.37, 1.8); node.set_meta("label", "Wait for the float to dip…"); game.toast("Line cast. Watch for the bite, then interact again.")
  elif fish_age < fish_bite: game.toast("Too soon! Let the fish take the bait."); _cancel_fishing()
  elif fish_age <= fish_bite + 1.15:
   var items = state.items.duplicate(true); var slots = state.inventory_slots().duplicate(true)
   var caught = preload("res://scripts/fishing_catalog.gd").catch_at(game.world.biome_at(node.global_position.x, node.global_position.z), randi())
   if state.award_reward(caught, 1) == 1 and state.save_game():
    game.toast("Caught " + preload("res://scripts/crafting.gd").item_name(caught) + "!"); game.audio.cue("collect")
    if is_instance_valid(fishing_visual): fishing_visual.caught(caught); fishing_visual = null
   else: state.items = items; state._slots = slots; game.toast("No space or the catch could not be saved. Try again.")
   _cancel_fishing()
  return true
 if kind == "waystop_rest":
  if game.combat_target() != null: game.toast("Wait until the road is safe before resting."); return true
  var last = float(rest_times.get(id, -1000))
  if clock - last < 60: game.toast("You have already rested here. Enjoy the fire and return later."); return true
  var old = state.health; var flags = state.taken.duplicate(true)
  state.health = mini(state.max_health, state.health + 2); rest_times[id] = clock
  if state.save_game(): game.toast(str(node.get_meta("title")) + " — warmth restores two health."); game.audio.cue("collect")
  else: state.health = old; state.taken = flags; rest_times.erase(id); game.toast("Rest could not be saved. Try again.")
  return true
 if kind == "waystop_cache":
  if state.taken.has(id): game.toast("Journal: Leave a little for the next traveler. Follow the lake roads to find the anglers.", 5); return true
  var items = state.items.duplicate(true); var slots = state.inventory_slots().duplicate(true); var flags = state.taken.duplicate(true)
  var added = state.award_reward("coffee_bean", 2); state.taken[id] = true
  if added == 2 and state.save_game(): game.toast("Travel journal found: the lake anglers know these roads. Shared supplies: +2 coffee beans.", 5)
  else: state.items = items; state._slots = slots; state.taken = flags; game.toast("Make room for the shared supplies and try again.")
  return true
 return false
