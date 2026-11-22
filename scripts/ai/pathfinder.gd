class_name Pathfinder
extends RefCounted

const DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
]

static func heuristic(a: Vector2i, b: Vector2i) -> float:
	return float(abs(a.x - b.x) + abs(a.y - b.y))

# mode: "astar" (f = g + h), "ucs" (f = g), "greedy" (f = h)
static func find_path(state: BoardState, start: Vector2i, goal: Vector2i, mode: String = "astar") -> Dictionary:
	var open: Array[Dictionary] = [{
		"pos": start,
		"g": 0,
		"f": heuristic(start, goal) if mode != "ucs" else 0.0,
		"path": [start]
	}]
	var best_g: Dictionary = {start: 0}
	var nodes_expanded: int = 0

	while not open.is_empty():
		open.sort_custom(func(a, b): return a["f"] < b["f"])
		var current: Dictionary = open.pop_front()
		var pos: Vector2i = current["pos"]
		var g: int = current["g"]
		nodes_expanded += 1

		if pos == goal:
			return {
				"found": true,
				"path": current["path"],
				"cost": g,
				"nodes_expanded": nodes_expanded
			}

		for d in DIRS:
			var nxt: Vector2i = pos + d
			var step_cost := state.get_terrain_cost(nxt)
			if step_cost < 0:
				continue
			if not state.get_unit_at(nxt).is_empty() and nxt != goal:
				continue

			var new_g: int = g + step_cost
			if not best_g.has(nxt) or new_g < best_g[nxt]:
				best_g[nxt] = new_g
				var h: float = heuristic(nxt, goal)
				var f: float = float(new_g)
				if mode == "astar":
					f = float(new_g) + h
				elif mode == "greedy":
					f = h

				var next_path: Array = current["path"].duplicate()
				next_path.append(nxt)
				open.append({"pos": nxt, "g": new_g, "f": f, "path": next_path})

	return {"found": false, "path": [], "cost": -1, "nodes_expanded": nodes_expanded}
