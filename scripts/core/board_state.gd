class_name BoardState
extends RefCounted

var width: int = 8
var height: int = 8
# 0 = plain (cost 1), 1 = rough/forest (cost 2), 2 = wall (impassable)
var terrain: Array[int] = []
# Each unit dict: { "id": int, "team": int, "pos": Vector2i, "hp": int, "move_pts": int, "atk": int, "range": int }
var units: Array[Dictionary] = []
var current_team: int = 0

func clone() -> BoardState:
	var copy := BoardState.new()
	copy.width = width
	copy.height = height
	copy.terrain = terrain.duplicate()
	copy.current_team = current_team
	copy.units.clear()
	for u in units:
		copy.units.append(u.duplicate(true))
	return copy

func is_inside(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height

func get_terrain_cost(pos: Vector2i) -> int:
	if not is_inside(pos):
		return -1
	match terrain[pos.y * width + pos.x]:
		0:
			return 1
		1:
			return 2
		_:
			return -1

func get_unit_at(pos: Vector2i) -> Dictionary:
	for u in units:
		if u["hp"] > 0 and u["pos"] == pos:
			return u
	return {}
