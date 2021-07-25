extends KinematicBody2D

signal died



var move_dir = Vector2(1,0)
var move_speed = 100
var gravity = Vector2(0,100)
var timer = 0


func _physics_process(delta):
	
	move_and_slide(gravity + move_dir * move_speed * Global.time_scale)
	timer += delta
	
	if timer > 0.4:
		var l = int($left.is_colliding())
		var r = int($right.is_colliding())
		var rs = int($right_side.is_colliding())
		var ls = int($left_side.is_colliding())
		
		var over_ledge = l ^ r
		var against_wall = (l & r) & (rs ^ ls)
		
		if over_ledge or against_wall:
			move_dir *= -1
			timer = 0


func damage():
	emit_signal("died")
	queue_free()
