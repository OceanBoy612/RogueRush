extends KinematicBody2D

signal died


onready var fragment_tscn = preload("res://Code/fragment/Fragment.tscn")


var move_dir = Vector2(1,0)
export var move_speed = 100
export var attack_move_speed = 175
var gravity = Vector2(0,300)
var timer = 0

enum {
	SHAMBLE,
	CHARGE,
	ATTACK,
}

var state = SHAMBLE


func _physics_process(delta):
	
	$sprite.flip_h = move_dir.x > 0
	$PlayerDetector.cast_to.x = abs($PlayerDetector.cast_to.x) if $sprite.flip_h else -abs($PlayerDetector.cast_to.x)
	$DamageArea.position.x = abs($DamageArea.position.x) if $sprite.flip_h else -abs($DamageArea.position.x)
	
	if $PlayerDetector.is_colliding() and state == SHAMBLE:
		state = CHARGE
	
	match state:
		SHAMBLE:
			shamble(delta)
		CHARGE:
			charge()
		ATTACK:
			attack(delta)


func _is_animation_complete(sprite: AnimatedSprite):
	return sprite.frame >= sprite.frames.get_frame_count(sprite.animation) - 1


func charge():
	if not $sprite.animation == "Charge": # enter the charge state
		$sprite.play("Charge")
#		print("entering the charge state")
	if _is_animation_complete($sprite): # exit the charge state
		state = ATTACK


func attack(delta):
	
	if not $sprite.animation == "Attack": # enter the attack state
		$sprite.play("Attack")
		$ZombieAttackSound.play()
		$DamageArea/CollisionShape2D.disabled = false
#		print("entering the attack state")
	
	move_and_slide((gravity*0.4) + move_dir * attack_move_speed * Global.time_scale)
	
	if _is_animation_complete($sprite): # exit the attack state
		state = SHAMBLE
		$DamageArea/CollisionShape2D.disabled = true
	

func shamble(delta):
	
	$sprite.play("Shamble")
	
	timer += delta
	move_and_slide(gravity + move_dir * move_speed * Global.time_scale)
	
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
	print("SPLAT!!!")
	$Splat.play()
#	Engine.time_scale = 0.1
	yield(get_tree().create_timer(0.04), "timeout")
#	Engine.time_scale = 1
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
#			frag.apply_central_impulse(rand_range(500, 1000) * Vector2(0, -rand_range(0.7,2)))
			frag.apply_central_impulse(rand_range(500, 1000) * Vector2(rand_range(0.7,2), 0).rotated(-rand_range(PI/4, 3*PI/4)))
			get_parent().add_child(frag)


func _on_DamageArea_body_entered(body):
	if body.has_method("damage"):
		body.damage(self)
		$DamageArea/CollisionShape2D.set_deferred("disabled", true)
		

