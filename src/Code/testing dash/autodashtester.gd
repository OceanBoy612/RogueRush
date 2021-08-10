extends Node2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

onready var start_pos = $Player.position



func _on_Timer_timeout():
	$Player.position = start_pos
#	$Player.dash(Vector2(1,0)) # right
#	$Player.dash(Vector2(0,-1)) # up
#	$Player.dash(Vector2(1,-1)) # upright
	
	$Player.jump()
	
	pass # Replace with function body.
