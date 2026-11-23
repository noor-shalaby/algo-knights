class_name BoardView
extends Node2D

signal tile_clicked(grid_pos: Vector2i)

const UNIT_VIEW_SCENE: PackedScene = preload("res://scenes/unit_view.tscn")

@onready var terrain_layer: TileMapLayer = $TerrainLayer
@onready var units_container: Node2D = $UnitsContainer
@onready var outline_overlay: Node2D = $OutlineOverlay

var _unit_views: Dictionary = {} # unit_id (int) -> UnitView
var _move_outline_tiles: Array[Vector2i] = []
var _attack_outline_tiles: Array[Vector2i] = []
var _path_tiles: Array[Vector2i] = []

func _ready() -> void:
	if outline_overlay != null and not outline_overlay.draw.is_connected(_on_outline_draw):
		outline_overlay.draw.connect(_on_outline_draw)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos: Vector2 = terrain_layer.to_local(get_global_mouse_position())
		var grid_pos: Vector2i = terrain_layer.local_to_map(local_pos)
		tile_clicked.emit(grid_pos)

func render_terrain(state: BoardState) -> void:
	terrain_layer.clear()
	for y: int in range(state.height):
		for x: int in range(state.width):
			var pos := Vector2i(x, y)
			var t_type: int = state.get_terrain(pos)
			match t_type:
				BoardState.TERRAIN_PLAIN:
					terrain_layer.set_cell(pos, 0, Vector2i(3, 2))
				BoardState.TERRAIN_FOREST:
					terrain_layer.set_cell(pos, 0, Vector2i(3, 0))
				BoardState.TERRAIN_WALL:
					terrain_layer.set_cell(pos, 0, Vector2i(2, 13))

func rebuild_units(state: BoardState) -> void:
	for child: Node in units_container.get_children():
		child.queue_free()
	_unit_views.clear()

	for u: Dictionary in state.units:
		var view: UnitView = UNIT_VIEW_SCENE.instantiate()
		units_container.add_child(view)
		var world_pos: Vector2 = terrain_layer.map_to_local(u["pos"])
		view.setup(u, world_pos)
		_unit_views[u["id"]] = view

func sync_units(state: BoardState) -> void:
	for u: Dictionary in state.units:
		var uid: int = u["id"]
		if not _unit_views.has(uid):
			continue
		var view: UnitView = _unit_views[uid]
		if view.is_dying:
			continue
		view.position = terrain_layer.map_to_local(u["pos"])
		view.update_from_data(u)

func get_unit_view(unit_id: int) -> UnitView:
	return _unit_views.get(unit_id, null)

func clear_highlights() -> void:
	_move_outline_tiles.clear()
	_attack_outline_tiles.clear()
	_path_tiles.clear()
	_redraw_overlay()

func highlight_moves(tiles: Array[Vector2i]) -> void:
	clear_highlights()
	_move_outline_tiles = tiles.duplicate()
	_redraw_overlay()

func highlight_attacks(tiles: Array[Vector2i]) -> void:
	_attack_outline_tiles = tiles.duplicate()
	_redraw_overlay()

func highlight_path(path: Array) -> void:
	clear_highlights()
	for p in path:
		if p is Vector2i:
			_path_tiles.append(p)
	_redraw_overlay()

func _redraw_overlay() -> void:
	if outline_overlay != null:
		outline_overlay.queue_redraw()

func _on_outline_draw() -> void:
	var tile_size: float = 16.0
	if terrain_layer != null and terrain_layer.tile_set != null:
		tile_size = float(terrain_layer.tile_set.tile_size.x)

	if not _move_outline_tiles.is_empty():
		_draw_outer_outline(_move_outline_tiles, Color(1.0, 1.0, 1.0, 0.9), tile_size)

	if not _attack_outline_tiles.is_empty():
		_draw_outer_outline(_attack_outline_tiles, Color(0.95, 0.25, 0.25, 0.95), tile_size)

	if not _path_tiles.is_empty():
		_draw_path_markers(_path_tiles, Color(0.95, 0.95, 0.25, 0.851), tile_size)

func _draw_outer_outline(tiles: Array[Vector2i], color: Color, tile_size: float = 16.0) -> void:
	var tile_set_map: Dictionary = {}
	for t: Vector2i in tiles:
		tile_set_map[t] = true

	var thickness: float = 1.0
	for t: Vector2i in tiles:
		var top_left: Vector2 = _tile_top_left(t, tile_size)

		if not tile_set_map.has(t + Vector2i(0, -1)):
			outline_overlay.draw_rect(Rect2(top_left, Vector2(tile_size, thickness)), color)
		if not tile_set_map.has(t + Vector2i(0, 1)):
			outline_overlay.draw_rect(Rect2(top_left + Vector2(0, tile_size - thickness), Vector2(tile_size, thickness)), color)
		if not tile_set_map.has(t + Vector2i(-1, 0)):
			outline_overlay.draw_rect(Rect2(top_left, Vector2(thickness, tile_size)), color)
		if not tile_set_map.has(t + Vector2i(1, 0)):
			outline_overlay.draw_rect(Rect2(top_left + Vector2(tile_size - thickness, 0), Vector2(thickness, tile_size)), color)

func _draw_path_markers(tiles: Array[Vector2i], color: Color, tile_size: float = 16.0) -> void:
	var inset: float = max(2.0, floor(tile_size * 0.25))
	var marker_size: float = max(2.0, tile_size - inset * 2.0)

	for t: Vector2i in tiles:
		var top_left: Vector2 = _tile_top_left(t, tile_size) + Vector2(inset, inset)
		outline_overlay.draw_rect(Rect2(top_left, Vector2(marker_size, marker_size)), color)

func _tile_top_left(grid_pos: Vector2i, tile_size: float) -> Vector2:
	var local_center: Vector2 = terrain_layer.map_to_local(grid_pos)
	return outline_overlay.to_local(terrain_layer.to_global(local_center)) - Vector2(tile_size * 0.5, tile_size * 0.5)
