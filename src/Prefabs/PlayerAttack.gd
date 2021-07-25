extends Area2D


func _ready():
	yield(get_tree().create_timer(0.1), "timeout")
	Global.time_scale = 1
	queue_free()


func _process(delta):
	for body in get_overlapping_bodies():
		if body.has_method("damage"):
			body.damage()
