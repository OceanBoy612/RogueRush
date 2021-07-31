extends RigidBody2D


var i = 0

func _on_Timer_timeout():
	if i == 0:
		$Tween.interpolate_property(self, "modulate", modulate, Color(0,0,0,0), 
				$Timer.wait_time, Tween.TRANS_BACK, Tween.EASE_IN)
		$Tween.start()
		$Timer.start()
		i += 1
	else:
		queue_free()
	pass # Replace with function body.
