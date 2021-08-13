extends AnimatedSprite


func _ready():
	play("Ouch")


func _on_DamageEffect_animation_finished():
	queue_free()
