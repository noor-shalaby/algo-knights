class_name CSPGenerator
extends RefCounted

@export var min_forest_count: int = 3
@export var max_forest_count: int = 8
@export var min_wall_count: int = 2
@export var max_wall_count: int = 6

## Generates a constrained tactical map using backtracking search with
## forward-checking / connectivity & spawn-clearance constraints.
static func generate_map(
	width: int = 8,
	height: int = 8,
	wall_count: int = 8,
	forest_count: int = 6,
	seed_val: int = -1,
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

	var wall_low: int = min_walls if min_walls >= 0 else maxi(0, wall_count - 3)
	var wall_high: int = max_walls if max_walls >= 0 else wall_count + 2
	wall_low = maxi(0, wall_low)
	wall_high = maxi(wall_low, wall_high)

	var forest_low: int = min_forests if min_forests >= 0 else maxi(0, forest_count - 2)
	var forest_high: int = max_forests if max_forests >= 0 else forest_count + 3
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

	var candidates: Array[Vector2i] = []
	for y: int in range(height):
		for x: int in range(width):
			var pos := Vector2i(x, y)
			if not protected_tiles.has(pos):
				candidates.append(pos)

	# Shuffle candidates once per attempt
	for i: int in range(candidates.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp

	var board := BoardState.new(width, height, BoardState.TERRAIN_PLAIN)
	var solved: bool = _backtrack(
		board,
		candidates,
		0,
		target_walls,
		target_forests,
		protected_tiles,
		rng
	)

	if not solved:
		# Fallback to a guaranteed open/connected layout if constraints are too tight
		var fallback := BoardState.new(width, height, BoardState.TERRAIN_PLAIN)
		_place_safe_obstacles(fallback, candidates, target_walls, target_forests, protected_tiles)
		return fallback

	return board


static func candidates_capacity(width: int, height: int, protected_tiles: Dictionary) -> int:
	return maxi(0, (width * height) - protected_tiles.size())

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
		# Keep immediate 4-way neighbors clear so units aren't trapped on spawn
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
	rng: RandomNumberGenerator
) -> bool:
	if walls_left == 0 and forests_left == 0:
		return _is_valid_board(board, protected)

	if idx >= candidates.size():
		return false

	var pos: Vector2i = candidates[idx]
	var remaining_slots: int = candidates.size() - idx
	if walls_left + forests_left > remaining_slots:
		return false

	# Ordered domain choices (randomized slightly per node for variety)
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

		# Prune early if walls block connectivity among protected spawn tiles
		if t != BoardState.TERRAIN_WALL or _spawns_connected(board, protected):
			if _backtrack(board, candidates, idx + 1, next_walls, next_forests, protected, rng):
				return true

		board.set_terrain(pos, BoardState.TERRAIN_PLAIN)

	return false

static func _is_valid_board(board: BoardState, protected: Dictionary) -> bool:
	if not _spawns_connected(board, protected):
		return false

	# Avoid 2x2 solid wall clumps that look awkward on small grids
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
