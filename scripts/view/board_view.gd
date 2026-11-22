class_name BoardView
extends Node2D

signal tile_clicked(grid_pos: Vector2i)

const UNIT_SCENE: PackedScene = preload("res://scenes/unit_view.tscn")

# Replace these atlas coords with the exact coordinates in your TileSet
const TERRAIN_ATLAS := {
	0: Vector2i(1, 2), # Plain (cost 1)
	1: Vector2i(1, 0), # Forest (cost 2)
	2: Vector2i(2, 13), # Wall (impassable)
}

# Overlay tileset source_id = 1
const OVERLAY_SOURCE_ID: int = 1
const OVERLAY_MOVE: Vector2i = Vector2i(0, 0)
const OVERLAY_ATTACK: Vector2i = Vector2i(1, 0)
const OVERLAY_PATH: Vector2i = Vector2i(2, 0)

@onready var terrain_layer: TileMapLayer = $TerrainLayer
@onready var overlay_layer: TileMapLayer = $OverlayLayer
@onready var units_container: Node2D = $UnitsContainer

var _unit_views: Dictionary = {} # unit_id -> UnitView

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos: Vector2 = terrain_layer.to_local(get_global_mouse_position())
		var grid_pos: Vector2i = terrain_layer.local_to_map(local_pos)
		tile_clicked.emit(grid_pos)

func render_terrain(state: BoardState) -> void:
	terrain_layer.clear()
	for y in range(state.height):
		for x in range(state.width):
			var t_id: int = state.terrain[y * state.width + x]
			var coords: Vector2i = TERRAIN_ATLAS.get(t_id, Vector2i.ZERO)
			terrain_layer.set_cell(Vector2i(x, y), 0, coords)

func rebuild_units(state: BoardState) -> void:
	for child in units_container.get_children():
		child.queue_free()
	_unit_views.clear()

	for u in state.units:
		var view: UnitView = UNIT_SCENE.instantiate()
		units_container.add_child(view)
		var world_pos: Vector2 = terrain_layer.map_to_local(u["pos"])
		view.setup(u, world_pos)
		_unit_views[u["id"]] = view

func sync_units(state: BoardState) -> void:
	for u in state.units:
		var uid: int = u["id"]
		if _unit_views.has(uid):
			var view: UnitView = _unit_views[uid]
			view.update_from_data(u)
			if u["hp"] > 0:
				view.position = terrain_layer.map_to_local(u["pos"])

func get_unit_view(unit_id: int) -> UnitView:
	return _unit_views.get(unit_id, null)

func clear_overlays() -> void:
	overlay_layer.clear()

func highlight_moves(positions: Array[Vector2i]) -> void:
	for pos in positions:
		overlay_layer.set_cell(pos, OVERLAY_SOURCE_ID, OVERLAY_MOVE)

func highlight_attacks(positions: Array[Vector2i]) -> void:
	for pos in positions:
		overlay_layer.set_cell(pos, OVERLAY_SOURCE_ID, OVERLAY_ATTACK)

func highlight_path(path: Array) -> void:
	for step in path:
		overlay_layer.set_cell(step, OVERLAY_SOURCE_ID, OVERLAY_PATH)
