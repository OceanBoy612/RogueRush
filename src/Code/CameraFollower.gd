extends Node2D



export var player_path: NodePath
export(float, 0, 1, 0.02) var follow_speed: float = 1


onready var player: KinematicBody2D = get_node(player_path)


func _process(delta):
	global_position = lerp(global_position, player.global_position, follow_speed)
#	global_position = player.global_position
