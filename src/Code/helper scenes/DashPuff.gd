extends AnimatedSprite


func _ready():
	play("Puff")


func flip(val):
	offset.x = offset.x * (-1 if val else 1)
	flip_h = val


func _on_DashPuff_animation_finished():
	queue_free()
