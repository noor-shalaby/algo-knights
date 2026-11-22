class_name UnitView
extends Node2D

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hp_bar: ProgressBar = $HPBar

var unit_id: int = -1
var is_dying: bool = false

func setup(unit_data: Dictionary, world_pos: Vector2) -> void:
	unit_id = unit_data["id"]
	is_dying = false
	position = world_pos
	hp_bar.max_value = max(1, unit_data.get("max_hp", unit_data["hp"]))
	update_from_data(unit_data)

	if unit_data["team"] == 0:
		anim_sprite.modulate = Color(0.45, 0.75, 1.0) # Blue tint for Player
		anim_sprite.flip_h = false
	else:
		anim_sprite.modulate = Color(1.0, 0.45, 0.45) # Red tint for AI
		anim_sprite.flip_h = true

	play_idle()

func update_from_data(unit_data: Dictionary) -> void:
	hp_bar.value = max(0, unit_data["hp"])
	if is_dying:
		return
	visible = unit_data["hp"] > 0

func play_idle() -> void:
	if is_dying:
		return
	if anim_sprite.sprite_frames != null and anim_sprite.sprite_frames.has_animation("idle"):
		anim_sprite.play("idle")

func play_attack() -> void:
	if is_dying:
		return
	if anim_sprite.sprite_frames != null and anim_sprite.sprite_frames.has_animation("attack"):
		anim_sprite.play("attack")
		await anim_sprite.animation_finished
		play_idle()

func play_die() -> void:
	if is_dying:
		return
	is_dying = true
	hp_bar.visible = false

	if anim_sprite.sprite_frames != null and anim_sprite.sprite_frames.has_animation("die"):
		anim_sprite.play("die")
		await anim_sprite.animation_finished

	# Optional subtle fade-out after the death frames finish
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.2)
	await fade.finished

	visible = false
	modulate.a = 1.0
	hp_bar.visible = true

func move_along_path(path: Array, layer: TileMapLayer, step_duration: float = 0.12) -> void:
	if path.size() <= 1 or is_dying:
		return

	if anim_sprite.sprite_frames != null and anim_sprite.sprite_frames.has_animation("walk"):
		anim_sprite.play("walk")

	var tween := create_tween()
	for i in range(1, path.size()):
		var grid_pos: Vector2i = path[i]
		var target_px: Vector2 = layer.map_to_local(grid_pos)
		tween.tween_property(self, "position", target_px, step_duration)

	await tween.finished
	play_idle()
