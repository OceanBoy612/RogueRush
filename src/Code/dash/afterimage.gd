extends Sprite


export var fade_duration: float = 1.0


func _ready():
	$Tween.interpolate_property(self, "modulate", modulate, Color(1,1,1,0), fade_duration, Tween.TRANS_LINEAR, Tween.EASE_IN)
	$Tween.start()



func _on_Tween_tween_all_completed():
	queue_free()
