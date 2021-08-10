extends "res://Code/Player2/CelestePlayerController.gd"


signal attack_started
signal attack_ended
signal hurt


var can_attack = false
var attacking = false


func move(delta: float):
	can_attack = Input.is_action_just_pressed("attack")
	
	if can_attack:
		start_attack()
		pass
	elif attacking:
		move_and_slide()
		pass
	else:
		.move(delta)



func start_attack():
	attacking = true
	emit_signal("attack_started")
	
