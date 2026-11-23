class_name CSPGenerator
extends RefCounted

@export var min_forest_count: int = 3
@export var max_forest_count: int = 8
@export var min_wall_count: int = 2
@export var max_wall_count: int = 6

const MAX_BACKTRACK_STEPS: int = 2500

## Generates a constrained tactical map using backtracking search with
## forward-checking / connectivity & spawn-clearance constraints.
## Supports presets: "standard", "chokepoint", "dense_stress".
static func generate_map(
	width: int = 8,
	height: int = 8,
	wall_count: int = 8,
	forest_count: int = 6,
	seed_val: int = -1,
	preset: String = "standard",
	min_walls: int = -1,
	max_walls: int = -1,
	min_forests: int = -1,
	max_forests: int = -1
) -> BoardState:
	var rng := RandomNumberGenerator.new()
	if seed_val >= 0:
		rng.seed = seed_val
	else:
		rng.randomize()

	var normalized_preset: String = preset.strip_edges().to_lower()
	var effective_walls: int = wall_count
	var effective_forests: int = forest_count

	match normalized_preset:
		"chokepoint":
			effective_walls = maxi(wall_count, 10)
			effective_forests = mini(forest_count, 5)
		"dense_stress":
			effective_walls = maxi(wall_count + 4, 12)
			effective_forests = maxi(forest_count + 4, 10)
		_:
			normalized_preset = "standard"

	var wall_low: int = min_walls if min_walls >= 0 else maxi(0, effective_walls - 3)
	var wall_high: int = max_walls if max_walls >= 0 else effective_walls + 2
	wall_low = maxi(0, wall_low)
	wall_high = maxi(wall_low, wall_high)

	var forest_low: int = min_forests if min_forests >= 0 else maxi(0, effective_forests - 2)
	var forest_high: int = max_forests if max_forests >= 0 else effective_forests + 3
	forest_low = maxi(0, forest_low)
	forest_high = maxi(forest_low, forest_high)

	var protected_tiles: Dictionary = _get_protected_spawns(width, height)
	var max_allowed_special: int = maxi(0, candidates_capacity(width, height, protected_tiles) - 4)

	var target_walls: int = rng.randi_range(wall_low, wall_high)
	var target_forests: int = rng.randi_range(forest_low, forest_high)

	if target_walls + target_forests > max_allowed_special:
		target_forests = maxi(0, max_allowed_special - target_walls)
		if target_walls > max_allowed_special:
			target_walls = max_allowed_special

	var board := BoardState.new(width, height, BoardState.TERRAIN_PLAIN)
	var reserved_tiles: Dictionary = protected_tiles.duplicate()
	var remaining_walls: int = target_walls

	if normalized_preset == "chokepoint":
		remaining_walls = _apply_chokepoint_walls(board, target_walls, protected_tiles, reserved_tiles)

	var candidates: Array[Vector2i] = []
	for y: int in range(height):
		for x: int in range(width):
			var pos := Vector2i(x, y)
			if not reserved_tiles.has(pos):
				candidates.append(pos)

	# Fisher-Yates shuffle using deterministic RNG
	for i: int in range(candidates.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp

	var step_counter: Array[int] = [0]
	var solved: bool = _backtrack(
		board,
		candidates,
		0,
		remaining_walls,
		target_forests,
		protected_tiles,
		rng,
		step_counter
	)

	if not solved:
		var fallback := BoardState.new(width, height, BoardState.TERRAIN_PLAIN)
		if normalized_preset == "chokepoint":
			var fb_reserved: Dictionary = protected_tiles.duplicate()
			var fb_rem_walls: int = _apply_chokepoint_walls(fallback, target_walls, protected_tiles, fb_reserved)
			_place_safe_obstacles(fallback, candidates, fb_rem_walls, target_forests, protected_tiles)
		else:
			_place_safe_obstacles(fallback, candidates, target_walls, target_forests, protected_tiles)
		return fallback

	return board


static func candidates_capacity(width: int, height: int, protected_tiles: Dictionary) -> int:
	return maxi(0, (width * height) - protected_tiles.size())

static func _apply_chokepoint_walls(
	board: BoardState,
	target_walls: int,
	spawn_protected: Dictionary,
	reserved_tiles: Dictionary
) -> int:
	# Carve central vertical choke barrier(s) with a 1-tile gap while checking spawn connectivity
	var mid_x: int = int(board.width / 2.0)
	if mid_x <= 0 or mid_x >= board.width - 1:
		return target_walls

	var cols: Array[int] = [mid_x]
	if mid_x - 1 > 0:
		cols.append(mid_x - 1)

	var gap_y: int = int(board.height / 2.0)
	var placed: int = 0

	for col: int in cols:
		for y: int in range(board.height):
			if placed >= target_walls:
				break
			if y == gap_y:
				continue
			var pos := Vector2i(col, y)
			if reserved_tiles.has(pos):
				continue
			if board.get_terrain(pos) != BoardState.TERRAIN_WALL:
				board.set_terrain(pos, BoardState.TERRAIN_WALL)
				if _spawns_connected(board, spawn_protected):
					reserved_tiles[pos] = true
					placed += 1
				else:
					board.set_terrain(pos, BoardState.TERRAIN_PLAIN)

	return maxi(0, target_walls - placed)

static func _get_protected_spawns(width: int, height: int) -> Dictionary:
	var left_x: int = 0
	var right_x: int = width - 1
	var mid_y: int = int(height / 2.0)
	var top_y: int = max(0, mid_y - 2)
	var bot_y: int = min(height - 1, mid_y + 2)

	var spawns: Array[Vector2i] = [
		Vector2i(left_x, top_y),
		Vector2i(left_x, bot_y),
		Vector2i(right_x, top_y),
		Vector2i(right_x, bot_y),
	]

	var protected: Dictionary = {}
	for s: Vector2i in spawns:
		protected[s] = true
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = s + d
			if n.x >= 0 and n.x < width and n.y >= 0 and n.y < height:
				protected[n] = true

	return protected

static func _backtrack(
	board: BoardState,
	candidates: Array[Vector2i],
	idx: int,
	walls_left: int,
	forests_left: int,
	protected: Dictionary,
	rng: RandomNumberGenerator,
	step_counter: Array[int]
) -> bool:
	step_counter[0] += 1
	if step_counter[0] > MAX_BACKTRACK_STEPS:
		return false

	if walls_left == 0 and forests_left == 0:
		return _is_valid_board(board, protected)

	if idx >= candidates.size():
		return false

	var pos: Vector2i = candidates[idx]
	var remaining_slots: int = candidates.size() - idx
	if walls_left + forests_left > remaining_slots:
		return false

	var choices: Array[int] = [BoardState.TERRAIN_PLAIN]
	if walls_left > 0:
		choices.append(BoardState.TERRAIN_WALL)
	if forests_left > 0:
		choices.append(BoardState.TERRAIN_FOREST)

	if choices.size() > 1 and rng.randf() < 0.5:
		choices.reverse()

	for t: int in choices:
		board.set_terrain(pos, t)
		var next_walls: int = walls_left - (1 if t == BoardState.TERRAIN_WALL else 0)
		var next_forests: int = forests_left - (1 if t == BoardState.TERRAIN_FOREST else 0)

		if t != BoardState.TERRAIN_WALL or _spawns_connected(board, protected):
			if _backtrack(board, candidates, idx + 1, next_walls, next_forests, protected, rng, step_counter):
				return true

		board.set_terrain(pos, BoardState.TERRAIN_PLAIN)

	return false

static func _is_valid_board(board: BoardState, protected: Dictionary) -> bool:
	if not _spawns_connected(board, protected):
		return false

	for y: int in range(board.height - 1):
		for x: int in range(board.width - 1):
			if (
				board.get_terrain(Vector2i(x, y)) == BoardState.TERRAIN_WALL
				and board.get_terrain(Vector2i(x + 1, y)) == BoardState.TERRAIN_WALL
				and board.get_terrain(Vector2i(x, y + 1)) == BoardState.TERRAIN_WALL
				and board.get_terrain(Vector2i(x + 1, y + 1)) == BoardState.TERRAIN_WALL
			):
				return false

	return true

static func _spawns_connected(board: BoardState, protected: Dictionary) -> bool:
	var walkables: Array[Vector2i] = []
	for p: Vector2i in protected.keys():
		if board.get_terrain(p) != BoardState.TERRAIN_WALL:
			walkables.append(p)

	if walkables.size() <= 1:
		return true

	var start: Vector2i = walkables[0]
	var visited: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d: Vector2i in dirs:
			var nxt: Vector2i = cur + d
			if board.in_bounds(nxt) and not visited.has(nxt):
				if board.get_terrain(nxt) != BoardState.TERRAIN_WALL:
					visited[nxt] = true
					queue.append(nxt)

	for w: Vector2i in walkables:
		if not visited.has(w):
			return false

	return true

static func _place_safe_obstacles(
	board: BoardState,
	candidates: Array[Vector2i],
	wall_count: int,
	forest_count: int,
	protected: Dictionary
) -> void:
	var placed_walls: int = 0
	var placed_forests: int = 0

	for pos: Vector2i in candidates:
		if placed_walls < wall_count:
			board.set_terrain(pos, BoardState.TERRAIN_WALL)
			if _spawns_connected(board, protected):
				placed_walls += 1
			else:
				board.set_terrain(pos, BoardState.TERRAIN_PLAIN)
		elif placed_forests < forest_count:
			board.set_terrain(pos, BoardState.TERRAIN_FOREST)
			placed_forests += 1
