extends TextureProgress


func _on_Player_health_changed(_new, _max):
	value = _new
	max_value = _max
