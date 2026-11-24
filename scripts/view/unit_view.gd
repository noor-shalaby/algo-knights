class_name UnitView
extends Node2D

const HIT_FLASH_SHADER_AND_DISSOLVE: Shader = preload("res://shaders/hit_flash_and_dissolve.gdshader")
const TEAM_0_FRAMES: SpriteFrames = preload("res://assets/sprites/team0_frames.tres")
const TEAM_1_FRAMES: SpriteFrames = preload("res://assets/sprites/team1_frames.tres")

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hp_bar: ProgressBar = $HPBar

var unit_id: int = -1
var is_dying: bool = false
var _flash_mat: ShaderMaterial
var _hp_tween: Tween

func _ready() -> void:
	_flash_mat = ShaderMaterial.new()
	_flash_mat.shader = HIT_FLASH_SHADER_AND_DISSOLVE
	_flash_mat.set_shader_parameter("flash_amount", 0.0)
	anim_sprite.material = _flash_mat

func setup(unit_data: Dictionary, world_pos: Vector2) -> void:
	unit_id = unit_data["id"]
	is_dying = false
	position = world_pos
	anim_sprite.position = Vector2.ZERO
	modulate = Color.WHITE
	anim_sprite.modulate = Color.WHITE
	hp_bar.visible = true
	hp_bar.max_value = max(1, unit_data.get("max_hp", unit_data["hp"]))
	update_from_data(unit_data)

	if unit_data["team"] == 0:
		anim_sprite.sprite_frames = TEAM_0_FRAMES
		anim_sprite.flip_h = false
	else:
		anim_sprite.sprite_frames = TEAM_1_FRAMES
		anim_sprite.flip_h = true

	if _flash_mat != null:
		_flash_mat.set_shader_parameter("flash_amount", 0.0)

	play_idle()

func update_from_data(unit_data: Dictionary) -> void:
	var target_hp: float = float(max(0, unit_data["hp"]))
	if hp_bar != null and not is_equal_approx(hp_bar.value, target_hp):
		if _hp_tween != null and _hp_tween.is_valid():
			_hp_tween.kill()
		_hp_tween = create_tween()
		_hp_tween.tween_property(hp_bar, "value", target_hp, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if is_dying or unit_data["hp"] <= 0:
		if hp_bar != null:
			hp_bar.visible = false
		return

	visible = true

func play_hit_impact(strength: float = 1.5, duration: float = 0.14) -> void:
	anim_sprite.position = Vector2.ZERO

	var tween := create_tween()
	tween.set_parallel(true)

	if _flash_mat != null:
		tween.tween_method(
			func(val: float): _flash_mat.set_shader_parameter("flash_amount", val),
			1.0,
			0.0,
			duration
		)

	var shake_tween := create_tween()
	var step_time: float = duration / 4.0
	shake_tween.tween_property(anim_sprite, "position:x", strength, step_time * 0.5)
	shake_tween.tween_property(anim_sprite, "position:x", -strength, step_time)
	shake_tween.tween_property(anim_sprite, "position:x", strength * 0.5, step_time)
	shake_tween.tween_property(anim_sprite, "position:x", 0.0, step_time * 1.5)

	await tween.finished
	anim_sprite.position = Vector2.ZERO

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

func play_disintegrate(duration: float = 0.2) -> void:
	if anim_sprite == null or not (anim_sprite.material is ShaderMaterial):
		visible = false
		return

	var mat := anim_sprite.material as ShaderMaterial
	mat.set_shader_parameter("flash_amount", 0.0)
	mat.set_shader_parameter("dissolve_progress", 0.0)

	if hp_bar != null:
		hp_bar.visible = false

	var tween := create_tween()
	tween.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("dissolve_progress", v),
		0.0,
		1.0,
		duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished

	visible = false

func play_die() -> void:
	if is_dying:
		return
	is_dying = true
	if hp_bar != null:
		hp_bar.visible = false
	if anim_sprite != null:
		anim_sprite.position = Vector2.ZERO
		if anim_sprite.sprite_frames != null and anim_sprite.sprite_frames.has_animation("die"):
			anim_sprite.play("die")
			await anim_sprite.animation_finished

	modulate.a = 1.0
	await play_disintegrate()

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

func reset_visuals(unit_data: Dictionary) -> void:
	if _hp_tween != null and _hp_tween.is_valid():
		_hp_tween.kill()

	is_dying = false
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	visible = unit_data.get("hp", 0) > 0

	if anim_sprite != null:
		anim_sprite.position = Vector2.ZERO
		anim_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		if anim_sprite.sprite_frames != null and anim_sprite.sprite_frames.has_animation("idle"):
			anim_sprite.play("idle")

	if anim_sprite != null and anim_sprite.material is ShaderMaterial:
		var mat := anim_sprite.material as ShaderMaterial
		mat.set_shader_parameter("flash_amount", 0.0)
		mat.set_shader_parameter("dissolve_progress", 0.0)

	if hp_bar != null:
		var max_hp: float = float(unit_data.get("max_hp", unit_data.get("hp", 100)))
		hp_bar.max_value = max_hp
		hp_bar.value = float(max(0, unit_data.get("hp", 0)))
		hp_bar.visible = visible
