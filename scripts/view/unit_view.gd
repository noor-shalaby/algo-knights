class_name UnitView
extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var hp_bar: ProgressBar = $HPBar

var unit_id: int = -1

func setup(unit_data: Dictionary, world_pos: Vector2) -> void:
	unit_id = unit_data["id"]
	position = world_pos
	hp_bar.max_value = max(1, unit_data.get("max_hp", unit_data["hp"]))
	update_from_data(unit_data)

	if unit_data["team"] == 0:
		sprite.modulate = Color(0.45, 0.75, 1.0) # Blue tint for Player
	else:
		sprite.modulate = Color(1.0, 0.45, 0.45) # Red tint for AI
		sprite.flip_h = true

func update_from_data(unit_data: Dictionary) -> void:
	hp_bar.value = max(0, unit_data["hp"])
	visible = unit_data["hp"] > 0

func move_along_path(path: Array, layer: TileMapLayer, step_duration: float = 0.12) -> void:
	if path.is_empty():
		return
	var tween := create_tween()
	for step in path:
		var grid_pos: Vector2i = step
		var target_px: Vector2 = layer.map_to_local(grid_pos)
		tween.tween_property(self, "position", target_px, step_duration)
	await tween.finished
