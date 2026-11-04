extends RefCounted

const COMMON = ["wood", "stick", "stone", "herb", "planks", "coffee_bean", "iron"]
const WEIGHTS = ["wood", "wood", "wood", "wood", "stick", "stick", "stick", "stone", "stone", "stone", "herb", "herb", "planks", "coffee_bean", "iron"]
const LIMIT = 2048
static func barrel_items(id: String, seed_value: int) -> Array:
	var rng = RandomNumberGenerator.new(); rng.seed = hash("barrel-loot:%s:%s" % [seed_value, id])
	var items = []
	for i in range(rng.randi_range(1, 3)): items.append(WEIGHTS[rng.randi_range(0, WEIGHTS.size() - 1)])
	return items
static func valid_record(row: Variant, max_amount: int) -> bool:
	if not row is Dictionary: return false
	if not row.get("id") is String or row.id.is_empty() or row.id.length() > 256: return false
	if row.get("item", "") not in COMMON and row.get("item", "") != "shard": return false
	var amount = row.get("amount", 0)
	if not (amount is int or amount is float) or not is_finite(float(amount)) or float(amount) != floorf(float(amount)) or amount < 1 or amount > max_amount: return false
	var point = row.get("position")
	if not point is Array or point.size() != 3: return false
	for n in point:
		if not (n is int or n is float) or not is_finite(float(n)) or absf(float(n)) > 100000: return false
	return true
static func valid(rows: Variant, max_amount: int) -> bool:
	if not rows is Array or rows.size() > LIMIT: return false
	var ids = {}
	for row in rows:
		if not valid_record(row, max_amount) or ids.has(row.id): return false
		ids[row.id] = true
	return true



const CRATE_WEIGHTS = ["wood", "planks", "planks", "iron", "iron", "stone", "herb", "coffee_bean", "stick"]
static func crate_items(id: String, seed_value: int) -> Array:
	var rng = RandomNumberGenerator.new(); rng.seed = hash("scrapper-crate-loot:%s:%s" % [seed_value, id])
	var items = []
	for i in range(rng.randi_range(2, 4)): items.append(CRATE_WEIGHTS[rng.randi_range(0, CRATE_WEIGHTS.size() - 1)])
	return items
