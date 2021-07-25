extends Particles2D


func _ready():
	one_shot = true
	emitting = true


func _on_Timer_timeout():
	queue_free()
