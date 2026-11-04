extends RefCounted

const Catalog = preload("res://scripts/crafting.gd")
const NORMAL_SLOTS: int = 36
const HOTBAR_SLOTS: int = 9
const PAGE_SLOTS: int = 27

static func valid_slots(value: Variant, retired_limits: Dictionary = {}) -> bool:
	if not value is Array or value.size() < NORMAL_SLOTS or value.size() > 10000 or (value.size() - NORMAL_SLOTS) % PAGE_SLOTS != 0:
		return false
	for cell in value:
		if not cell is Dictionary:
			return false
		if cell.is_empty():
			continue
		if cell.size() != 2 or not cell.get("item") is String or not cell.has("amount"):
			return false
		var amount = cell.amount
		if not (amount is int or amount is float) or not is_finite(float(amount)) or float(amount) != floorf(float(amount)):
			return false
		if int(amount) <= 0 or int(amount) > int(retired_limits.get(cell.item, Catalog.max_stack(cell.item))):
			return false
	return true



static func reconcile(layout: Array, totals: Dictionary, expand: bool = true) -> Array:
	var result: Array = []
	var remaining: Dictionary = totals.duplicate()
	var capacity: int = maxi(NORMAL_SLOTS, layout.size())
	for index in range(capacity):
		var cell: Dictionary = layout[index] if index < layout.size() else {}
		var id: String = str(cell.get("item", ""))
		var amount: int = mini(int(cell.get("amount", 0)), mini(int(remaining.get(id, 0)), Catalog.max_stack(id)))
		if amount > 0:
			result.append({"item": id, "amount": amount})
			remaining[id] = int(remaining[id]) - amount
		else:
			result.append({})
	for id in remaining:
		var left: int = int(remaining[id])
		var limit: int = Catalog.max_stack(id)
		if left <= 0:
			continue
		if limit <= 0:
			return []
		for cell in result:
			if cell.get("item", "") == id and int(cell.amount) < limit:
				var added: int = mini(left, limit - int(cell.amount))
				cell.amount = int(cell.amount) + added
				left -= added
				if left == 0:
					break
		while left > 0:
			var empty: int = -1
			for index in range(result.size()):
				if result[index].is_empty():
					empty = index
					break
			if empty < 0:
				if not expand:
					return []
				empty = result.size()
				for index in range(PAGE_SLOTS):
					result.append({})
			var added: int = mini(left, limit)
			result[empty] = {"item": id, "amount": added}
			left -= added
	return result

static func move(layout: Array, from: int, to: int, split: bool = false) -> bool:
	if from < 0 or to < 0 or from >= layout.size() or to >= layout.size() or from == to or layout[from].is_empty():
		return false
	var source: Dictionary = layout[from]
	var target: Dictionary = layout[to]
	var moving: int = (int(source.amount) + 1) / 2 if split else int(source.amount)
	if target.is_empty():
		layout[to] = {"item": source.item, "amount": moving}
	elif source.item == target.item:
		moving = mini(moving, Catalog.max_stack(source.item) - int(target.amount))
		if moving <= 0:
			return false
		target.amount = int(target.amount) + moving
	else:
		if split:
			return false
		layout[from] = target
		layout[to] = source
		return true
	source.amount = int(source.amount) - moving
	if int(source.amount) == 0:
		layout[from] = {}
	return true
