extends SceneTree
func _initialize():
 var atlas = preload("res://scripts/world_atlas.gd").new()
 var P = preload("res://scripts/locations.gd")
 var S = preload("res://scripts/regional_settlements.gd")
 for site in atlas.sites():
  if site.id not in ["alderhaven", "brindlewick"]: continue
  var plan = S.plan(atlas, site)
  print("SITE ", site, " PLOTS ", plan.plots.size())
  for plot in plan.plots:
   var p: Vector2 = site.pos + plot.p
   var liquid: Dictionary = atlas.liquid_at(p)
   if not liquid.is_empty(): print("WATER ", plot.index, " ", liquid, " GROUND ", atlas.height_at(p))
 print("VALIDATION_COMPLETE")
 quit()
