class_name DamageLabel
extends Label

@export var float_distance: float = 12.0
@export var duration: float = 0.55

func play(amount: int, color: Color = Color(1.0, 0.25, 0.25, 1.0)) -> void:
	if amount <= 0:
		queue_free()
		return

	text = "-%d" % amount
	modulate = color
	z_index = 20

	# Center horizontally over the anchor point once text size is ready
	await get_tree().process_frame
	if not is_inside_tree():
		return
	position.x -= size.x * 0.5

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - float_distance, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
