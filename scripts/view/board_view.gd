class_name BoardView
extends Node2D

signal tile_clicked(grid_pos: Vector2i)

const UNIT_VIEW_SCENE: PackedScene = preload("res://scenes/unit_view.tscn")

@onready var terrain_layer: TileMapLayer = $TerrainLayer
@onready var highlight_layer: TileMapLayer = $HighlightLayer
@onready var units_container: Node2D = $UnitsContainer

var _unit_views: Dictionary = {} # unit_id (int) -> UnitView

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
	highlight_layer.clear()

func highlight_moves(tiles: Array[Vector2i]) -> void:
	for pos: Vector2i in tiles:
		highlight_layer.set_cell(pos, 1, Vector2i(0, 0))

func highlight_attacks(tiles: Array[Vector2i]) -> void:
	for pos: Vector2i in tiles:
		highlight_layer.set_cell(pos, 1, Vector2i(1, 0))

func highlight_path(path: Array) -> void:
	clear_highlights()
	for p in path:
		if p is Vector2i:
			highlight_layer.set_cell(p, 1, Vector2i(2, 0))
