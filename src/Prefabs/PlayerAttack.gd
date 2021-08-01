extends Area2D

var creator

func _ready():
	$AnimatedSprite.play("Impact")
	yield(get_tree().create_timer(0.1), "timeout")
	Global.time_scale = 1


func _process(delta):
	for body in get_overlapping_bodies():
		if body.has_method("damage"):
			body.damage()
			if creator and creator.has_method("killed"):
				creator.killed(body)
#	$CollisionShape2D.set_deferred("disabled", true)
#	set_process(false)


func _on_AnimatedSprite_animation_finished():
	queue_free()
