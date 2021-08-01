extends KinematicBody2D

signal died


onready var fragment_tscn = preload("res://Code/fragment/Fragment.tscn")


var move_dir = Vector2(1,0)
var move_speed = 100
var gravity = Vector2(0,100)
var timer = 0


func _ready():
	$sprite.play("Shamble")


func _physics_process(delta):
	
	move_and_slide(gravity + move_dir * move_speed * Global.time_scale)
	timer += delta
	
	$sprite.flip_h = move_dir.x > 0
	
	if timer > 0.1:
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
	_on_death()
	queue_free()


func _on_death():
	#spawn fragments
	var curr_text: Texture = $sprite.frames.get_frame($sprite.animation, $sprite.frame)
	if curr_text.get_width() != curr_text.get_height():
		push_error("sprite is not square for fragmentation")
		return
	
	randomize()
	var chunk_size = 8
	for i in range(curr_text.get_width() / chunk_size):
		for j in range(curr_text.get_height() / chunk_size):
			var frag = fragment_tscn.instance()
			var sprite: Sprite = frag.get_node("Sprite")
			frag.get_node("CollisionShape2D").shape.extents = scale * Vector2(chunk_size, chunk_size) / 2
			sprite.texture = curr_text
			sprite.region_rect = Rect2(chunk_size * i, chunk_size * j, chunk_size, chunk_size)
			sprite.scale = scale
			frag.global_position = $sprite.global_position + Vector2(chunk_size * i, chunk_size * j)
			# give a random impulse
			frag.apply_central_impulse(rand_range(500, 1000) * Vector2(rand_range(1,3), 0).rotated(rand_range(0, 7)))
			get_parent().add_child(frag)



