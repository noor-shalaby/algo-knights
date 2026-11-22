class_name Pathfinder
extends RefCounted

const DIRS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]

static func _in_bounds(state: BoardState, pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < state.width and pos.y >= 0 and pos.y < state.height

static func _get_occupant_at(state: BoardState, pos: Vector2i) -> Dictionary:
	for u: Dictionary in state.units:
		if u["hp"] > 0 and u["pos"] == pos:
			return u
	return {}

## Returns all tiles reachable within max_move movement points from origin,
## mapped as { Vector2i_tile: int_cost }, including origin at cost 0.
static func get_reachable_tiles(
	state: BoardState,
	origin: Vector2i,
	max_move: int,
	moving_unit_id: int
) -> Dictionary:
	var cost_so_far: Dictionary = {origin: 0}
	var frontier: Array = [[0, origin]]

	while not frontier.is_empty():
		frontier.sort_custom(func(a, b): return a[0] < b[0])
		var current: Array = frontier.pop_front()
		var cur_cost: int = current[0]
		var cur_pos: Vector2i = current[1]

		if cur_cost > cost_so_far.get(cur_pos, 999999):
			continue

		for dir: Vector2i in DIRS:
			var next_pos: Vector2i = cur_pos + dir
			if not _in_bounds(state, next_pos):
				continue

			var step_cost: int = state.get_terrain_cost(next_pos)
			if step_cost < 0:
				continue

			var occupant: Dictionary = _get_occupant_at(state, next_pos)
			if not occupant.is_empty() and occupant["id"] != moving_unit_id:
				continue

			var new_cost: int = cur_cost + step_cost
			if new_cost <= max_move and new_cost < cost_so_far.get(next_pos, 999999):
				cost_so_far[next_pos] = new_cost
				frontier.append([new_cost, next_pos])

	return cost_so_far

## Finds a path from start to goal using "astar", "ucs", or "greedy".
## Returns { "found": bool, "path": Array[Vector2i], "cost": int, "nodes_expanded": int }.
static func find_path(
	state: BoardState,
	start: Vector2i,
	goal: Vector2i,
	mode: String = "astar",
	moving_unit_id: int = -1
) -> Dictionary:
	if not _in_bounds(state, start) or not _in_bounds(state, goal):
		return {"found": false, "path": [], "cost": -1, "nodes_expanded": 0}

	if state.get_terrain_cost(goal) < 0:
		return {"found": false, "path": [], "cost": -1, "nodes_expanded": 0}

	if start == goal:
		return {"found": true, "path": [start], "cost": 0, "nodes_expanded": 0}

	var open_list: Array = [] # [f_score, g_score, pos]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start: 0}
	var closed: Dictionary = {}
	var nodes_expanded: int = 0

	open_list.append([_heuristic(start, goal, mode), 0, start])

	while not open_list.is_empty():
		open_list.sort_custom(func(a, b): return a[0] < b[0])
		var entry: Array = open_list.pop_front()
		var current: Vector2i = entry[2]

		if closed.has(current):
			continue
		closed[current] = true
		nodes_expanded += 1

		if current == goal:
			var path: Array[Vector2i] = []
			var step: Vector2i = current
			while step != start:
				path.append(step)
				step = came_from[step]
			path.append(start)
			path.reverse()
			return {
				"found": true,
				"path": path,
				"cost": g_score[goal],
				"nodes_expanded": nodes_expanded,
			}

		for dir: Vector2i in DIRS:
			var neighbor: Vector2i = current + dir
			if not _in_bounds(state, neighbor) or closed.has(neighbor):
				continue

			var step_cost: int = state.get_terrain_cost(neighbor)
			if step_cost < 0:
				continue

			var occupant: Dictionary = _get_occupant_at(state, neighbor)
			if not occupant.is_empty() and occupant["id"] != moving_unit_id:
				continue

			var tentative_g: int = g_score[current] + step_cost
			if tentative_g < g_score.get(neighbor, 999999):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				var f_score: float = _priority(tentative_g, neighbor, goal, mode)
				open_list.append([f_score, tentative_g, neighbor])

	return {"found": false, "path": [], "cost": -1, "nodes_expanded": nodes_expanded}

static func _heuristic(a: Vector2i, b: Vector2i, mode: String) -> float:
	if mode == "ucs":
		return 0.0
	return float(abs(a.x - b.x) + abs(a.y - b.y))

static func _priority(g: int, pos: Vector2i, goal: Vector2i, mode: String) -> float:
	match mode:
		"ucs":
			return float(g)
		"greedy":
			return _heuristic(pos, goal, "greedy")
		_: # "astar"
			return float(g) + _heuristic(pos, goal, "astar")
