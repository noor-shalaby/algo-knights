class_name BoardState
extends RefCounted

const TERRAIN_PLAIN: int = 0
const TERRAIN_FOREST: int = 1
const TERRAIN_WALL: int = 2

var width: int = 8
var height: int = 8
var grid: Array = [] # Array[Array[int]] -> grid[y][x]
var units: Array = [] # Array[Dictionary]
var current_team: int = 0

func _init(w: int = 8, h: int = 8, fill_terrain: int = TERRAIN_PLAIN) -> void:
	width = w
	height = h
	grid.clear()
	for y: int in range(height):
		var row: Array[int] = []
		row.resize(width)
		row.fill(fill_terrain)
		grid.append(row)

func in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height

func get_terrain(pos: Vector2i) -> int:
	if not in_bounds(pos):
		return TERRAIN_WALL
	return grid[pos.y][pos.x]

func set_terrain(pos: Vector2i, terrain_type: int) -> void:
	if in_bounds(pos):
		grid[pos.y][pos.x] = terrain_type

func get_terrain_cost(pos: Vector2i) -> int:
	match get_terrain(pos):
		TERRAIN_PLAIN:
			return 1
		TERRAIN_FOREST:
			return 2
		TERRAIN_WALL:
			return -1
		_:
			return 1

func get_unit_at(pos: Vector2i) -> Dictionary:
	for u: Dictionary in units:
		if u["hp"] > 0 and u["pos"] == pos:
			return u
	return {}

func get_unit_by_id(unit_id: int) -> Dictionary:
	for u: Dictionary in units:
		if u["id"] == unit_id:
			return u
	return {}

func clone() -> BoardState:
	var copy := BoardState.new(width, height, TERRAIN_PLAIN)
	copy.current_team = current_team

	for y: int in range(height):
		for x: int in range(width):
			copy.grid[y][x] = grid[y][x]

	copy.units.clear()
	for u: Dictionary in units:
		copy.units.append(u.duplicate(true))

	return copy
