extends AnimatedSprite


func _ready():
	play("Dust")


func _on_Dust_animation_finished():
	queue_free()
