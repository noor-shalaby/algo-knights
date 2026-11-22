class_name CSPGenerator
extends RefCounted

static func generate_map(width: int, height: int, obstacle_count: int, min_spawn_dist: int) -> BoardState:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for _attempt in range(200):
		var state := BoardState.new()
		state.width = width
		state.height = height
		state.terrain.resize(width * height)
		state.terrain.fill(0)

		# Place obstacles with basic backtracking/retry if invalid
		var placed := 0
		var guard := 0
		while placed < obstacle_count and guard < obstacle_count * 10:
			guard += 1
			var x := rng.randi_range(0, width - 1)
			var y := rng.randi_range(0, height - 1)
			var idx := y * width + x
			if state.terrain[idx] == 0:
				state.terrain[idx] = 2
				placed += 1

		var spawn_a := Vector2i(0, rng.randi_range(0, height - 1))
		var spawn_b := Vector2i(width - 1, rng.randi_range(0, height - 1))
		state.terrain[spawn_a.y * width + spawn_a.x] = 0
		state.terrain[spawn_b.y * width + spawn_b.x] = 0

		# Constraint 1: Minimum distance between spawns
		if abs(spawn_a.x - spawn_b.x) + abs(spawn_a.y - spawn_b.y) < min_spawn_dist:
			continue

		# Constraint 2: Connectivity check via A* / BFS
		var path_check := Pathfinder.find_path(state, spawn_a, spawn_b, "astar")
		if path_check["found"]:
			state.set_meta("spawn_a", spawn_a)
			state.set_meta("spawn_b", spawn_b)
			return state

	# Fallback clean grid if tight constraints need relaxation
	var fallback := BoardState.new()
	fallback.width = width
	fallback.height = height
	fallback.terrain.resize(width * height)
	fallback.terrain.fill(0)
	return fallback
