extends RefCounted
const B = preload("res://scripts/build.gd")
static func cart(parent: Node3D) -> Array:
 var wood = B.mat("#735038"); var rim = B.mat("#34383d", 0.4); var wheels = []
 B.box(parent, Vector3(0, 0.7, -2.0), Vector3(1.65, 0.18, 2.0), wood)
 for side in [-1, 1]:
  B.box(parent, Vector3(side * 0.81, 1.0, -2.0), Vector3(0.1, 0.6, 2.0), wood)
  B.branch(parent, Vector3(side * 0.58, 0.72, -1.0), Vector3(side * 0.4, 0.82, 0.25), 0.04, wood)
  B.branch(parent, Vector3(side * 0.9, 0.5, -2), Vector3(-side * 0.9, 0.5, -2), 0.075, rim)
  var pivot = Node3D.new(); parent.add_child(pivot); pivot.position = Vector3(side * 0.94, 0.5, -2); wheels.append(pivot)
  B.ring(pivot, Vector3.ZERO, 0.45, 0.07, rim).rotation.z = PI / 2
  for i in 6:
   var a = TAU * i / 6.0; B.branch(pivot, Vector3.ZERO, Vector3(0, sin(a) * 0.43, cos(a) * 0.43), 0.025, wood)
 B.box(parent, Vector3(0, 1, -2.95), Vector3(1.65, 0.6, 0.1), wood)
 for i in 4:
  B.beveled_box(parent, Vector3((i % 2 - 0.5) * 0.65, 1.02, -1.6 - floori(i / 2.0) * 0.7), Vector3(0.57, 0.5, 0.57), B.mat(["#a58154", "#7d6346"][i % 2]))
 for i in 3: B.ball(parent, Vector3(-0.45 + i * 0.4, 1.37, -1.5), Vector3(0.3, 0.26, 0.3), B.mat(["#b9c47c", "#d4b07c", "#b57b66"][i]))
 return wheels
static func mount(parent: Node3D, camel: bool) -> Dictionary:
 var root = Node3D.new(); root.name = "RoadCamel" if camel else "RoadHorse"; parent.add_child(root)
 var rig = {"legs": [], "head": null, "root": root}
 if camel:
  var model = Node3D.new(); root.add_child(model); model.rotation.y = PI; model.scale = Vector3.ONE * 1.15
  var authored = load("res://scripts/regional_creature_models.gd").wildlife(model, "shadeback_camel")
  rig.legs = authored.get("legs", []); rig.head = authored.get("head"); rig.saddle = 1.7
 else:
  var coat = B.mat("#805943"); var dark = B.mat("#382e2b"); var pale = B.mat("#c4aa8b")
  B.ball(root, Vector3(0, 1.12, 0), Vector3(0.73, 0.82, 1.72), coat)
  B.ball(root, Vector3(0, 1.18, 0.55), Vector3(0.75, 0.88, 0.7), coat)
  B.branch(root, Vector3(0, 1.26, 0.58), Vector3(0, 1.92, 0.85), 0.24, coat, 0.62)
  var head = Node3D.new(); root.add_child(head); head.position = Vector3(0, 1.91, 0.85); rig.head = head
  B.ball(head, Vector3(0, 0, 0.15), Vector3(0.34, 0.42, 0.63), coat)
  B.ball(head, Vector3(0, -0.08, 0.4), Vector3(0.32, 0.28, 0.3), dark)
  for side in [-1, 1]:
   B.branch(head, Vector3(side * 0.12, 0.12, 0), Vector3(side * 0.15, 0.42, -0.05), 0.075, coat, 0.1)
   B.ball(head, Vector3(side * 0.173, 0.08, 0.16), Vector3(0.04, 0.045, 0.045), dark)
  for i in 4:
   var leg = Node3D.new(); root.add_child(leg); leg.position = Vector3((-1 if i % 2 == 0 else 1) * 0.25, 0.98, 0.53 if i < 2 else -0.56); rig.legs.append(leg)
   B.branch(leg, Vector3.ZERO, Vector3(0, -0.49, 0.03), 0.105, coat, 0.7)
   B.branch(leg, Vector3(0, -0.46, 0.03), Vector3(0, -0.86, 0), 0.07, pale, 0.8)
   B.beveled_box(leg, Vector3(0, -0.91, 0.025), Vector3(0.17, 0.16, 0.23), dark)
  B.branch(root, Vector3(0, 1.35, -0.7), Vector3(0, 0.53, -0.98), 0.1, dark, 0.35)
  for i in 7: B.ball(root, Vector3(0, 1.5 + i * 0.06, 0.55 + i * 0.035), Vector3(0.16, 0.22, 0.18), dark)
  rig.saddle = 1.43
 B.box(root, Vector3(0, rig.saddle - 0.12, -0.07), Vector3(0.76, 0.12, 0.68), B.mat("#4d4351"))
 B.beveled_box(root, Vector3(0, rig.saddle, -0.07), Vector3(0.55, 0.16, 0.52), B.mat("#534032"))
 return rig
static func campsite(root: Node3D) -> void:
 var wood = B.mat("#73513e"); var canvas = B.mat("#a99c7d"); var stone = B.mat("#6d6b62")

 for side in [-1, 1]:
  var panel = B.box(root, Vector3(side * 0.65, 0.85, -1.6), Vector3(0.1, 2.1, 2.6), canvas); panel.rotation.z = side * 0.65
 B.branch(root, Vector3(0, 0, -3), Vector3(0, 1.7, -3), 0.045, wood)
 B.branch(root, Vector3(0, 1.7, -3), Vector3(0, 1.7, -0.2), 0.045, wood)
 B.box(root, Vector3(0, 0.13, -1.6), Vector3(0.72, 0.2, 1.75), B.mat("#736f7c"))
 for i in 9:
  var a = TAU * i / 9; B.ball(root, Vector3(cos(a) * 0.62, 0.14, sin(a) * 0.62 + 1), Vector3(0.3, 0.25, 0.26), stone)
 for side in [-1, 1]: B.branch(root, Vector3(side * 0.35, 0.13, 0.7), Vector3(-side * 0.35, 0.15, 1.3), 0.095, wood)
 B.flame(root, Vector3(0, 0.25, 1), Vector3(0.4, 0.7, 0.4))
 B.branch(root, Vector3(-1.8, 0.3, 0.7), Vector3(-1.8, 0.3, 2), 0.22, wood)
 B.beveled_box(root, Vector3(1.5, 0.3, 0.8), Vector3(0.65, 0.6, 0.65), wood)
static func dock(root: Node3D, water_y: float, ground) -> void:
 var wood = B.mat("#836647"); var iron = B.mat("#454a4e", 0.35)
 for i in 28:
  var z = i * 0.3; var y = lerpf(0.08, water_y + 0.65, smoothstep(0, 4, z))
  B.box(root, Vector3(0, y, z), Vector3(2.3, 0.15, 0.28), wood, true)
 for z in [1.0, 4.0, 7.6]:
  var y = lerpf(0.08, water_y + 0.65, smoothstep(0, 4, z))
  for side in [-1, 1]:
   var p = root.to_global(Vector3(side * 1.03, 0, z)); var bottom = ground.call(p.x, p.z) - root.position.y - 0.15
   B.cyl(root, Vector3(side * 1.03, (y + 0.8 + bottom) * 0.5, z), 0.09, y + 0.8 - bottom, wood)
   B.ring(root, Vector3(side * 1.03, y + 0.6, z), 0.1, 0.025, iron)
 B.beveled_box(root, Vector3(-0.6, water_y + 0.96, 4.8), Vector3(0.62, 0.6, 0.62), wood)
 B.branch(root, Vector3(-0.9, water_y + 0.9, 5.4), Vector3(-0.9, water_y + 2.6, 7.5), 0.025, wood, 0.4)
 B.branch(root, Vector3(-0.9, water_y + 2.6, 7.5), Vector3(-0.9, water_y + 0.05, 8.5), 0.004, B.mat("#d2c3a3"))
 B.ball(root, Vector3(-0.9, water_y + 0.05, 8.5), Vector3(0.12, 0.14, 0.12), B.mat("#e6b875"))
