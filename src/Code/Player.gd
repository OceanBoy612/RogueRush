extends KinematicBody2D


signal collided
signal landed
signal jumped
signal attacked
signal dashed
signal started_to_dash
signal health_changed(_new, _max)
signal died


export var speed: float = 55
export var jump_height: float = 95
export var attack_force: float = 35
export var dash_force: float = 82
export var gravity: float = 11
var gravity_scale
export var friction: float = 0.7
export var time_between_stomps: int = 2700
export var coyote_time_frames: int = 8
export var knockback_force = 150



var decaying_forces = []
var vel: Vector2 = Vector2()
var prev_vel: Vector2 = Vector2()
var playerattack_tscn = preload("res://Prefabs/PlayerAttack.tscn")
var damage_effect_tscn = preload("res://Code/damageEffect/DamageEffect.tscn")
var on_floor: bool = false

var in_coyote_time = false
var time_since_on_floor: float = 0

var max_health = 3
var health = 3 setget set_health


enum {
	MOVE,
	ATTACK,
	JUMP,
	DASH,
}
var state = MOVE setget set_state

### Main ###


func _physics_process(delta):
	if Global.time_scale == 0:
		return

	vel += get_forces()
	if state != DASH:
		vel += get_gravity()
	if state == MOVE or state == JUMP:
		vel += get_user_input()
#	print(vel * delta * Global.time_scale)

	var temp = vel
	vel = move_and_slide(vel * Global.time_scale, Vector2(0, -1))

	handle_checks()
	handle_animations()
	
	
	if state == DASH:
		spawn_afterimage()

	if on_floor: time_since_on_floor = 0
	else: time_since_on_floor += delta
	in_coyote_time = time_since_on_floor < 0.01667 * coyote_time_frames # four frames

	for i in get_slide_count():
		var collision: KinematicCollision2D = get_slide_collision(i)
		if (temp-vel).length() > 5: # real collisions:
			emit_signal("collided", collision)
	
	if state != DASH:
		vel.x *= friction
	prev_vel = vel


func _input(event):
	if state == ATTACK:
		return

	if can_jump(event):
		jump()
	if event.is_action_pressed("attack") and (state == MOVE or state == JUMP):
		set_state(ATTACK)
		gravity_scale = 50
		print("changeing state: ", state)
		decaying_forces.append(
			DecayingForce.new(attack_force, vel.normalized(), 45, 0.95)
		)
		$sprite.playing = false
		$AnimationPlayer.play("Attack")
		animation_lock = true

	if event.is_action_pressed("dash") and can_dash():
		dash()


func _ready():
	print(gravity)
	gravity_scale = gravity
	connect("landed", self, "_on_landed")
	$AnimationPlayer.connect("animation_finished", self, "_on_animation_finished")


### Main ###

### Subroutines ###


func handle_checks():
	# left and right flipping
	if state != ATTACK: # prevent flipping during attack
		var user_dir: Vector2 = get_user_input().normalized()
		if user_dir.x > 0:
	#	if vel.x > 0:
			$sprite.flip_h = false
			$sprite.position.x = abs($sprite.position.x) * -1
			$AttackPosition.position.x = abs($AttackPosition.position.x)
		elif user_dir.x < 0:
			$sprite.flip_h = true
			$sprite.position.x = abs($sprite.position.x)
			$AttackPosition.position.x = abs($AttackPosition.position.x) * -1


func handle_animations():

	if state == DASH:
		if $sprite.animation == "Dash on":
			$sprite.play("Dashing")

		return

	if animation_lock:
		return
	# on floor not on floor
	if not on_floor and is_on_floor() and .is_on_floor(): #landed
		on_floor = true
		set_state(MOVE)
		print("changeing state: ", state)
		if animation_lock == false:
			$sprite.play("Jump land")
			animation_lock = true

		emit_signal("landed")
		return
	elif on_floor and not is_on_floor(): # jumped
		on_floor = false
		emit_signal("jumped")

		$sprite.play("Jump")
#		animation_lock = true
		return

	if not on_floor:
		if abs(vel.y) < 120: # near the top of the jump arc.
			$sprite.play("Jump air")
		elif vel.y < 0:
			$sprite.play("Jump up")
		elif vel.y > 0:
			$sprite.play("Jump down")
	else:
		# on the floor
		if abs(vel.x) > 1:
			$sprite.play("Run")
		else:
			if OS.get_system_time_msecs() - time_since_stomp < time_between_stomps:
				$sprite.play("Idle")
			else:
				$sprite.play("Idle Stomp")
				animation_lock = true
				time_since_stomp = OS.get_system_time_msecs()
#			$sprite.playing = false

var time_since_stomp = OS.get_system_time_msecs()

func spawn_attack():
	$SmashSound.play()
	var attackShape = playerattack_tscn.instance()
	attackShape.creator = self
	get_parent().add_child(attackShape)
	attackShape.global_position = $AttackPosition.global_position
	emit_signal("attacked")
	Global.time_scale = 0


func get_user_input(up_aswell: bool = false) -> Vector2:
	return Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up") if up_aswell else 0
	) * speed


func get_gravity() -> Vector2:
	if not .is_on_floor():
		return Vector2(0, 1) * gravity_scale
	else:
		return Vector2(0, 1) * gravity_scale# * 0.01


func get_forces() -> Vector2:
	var forces = Vector2()
	
	var to_remove = []
	for d in decaying_forces:
		d = (d as DecayingForce)
		forces += d.get_impulse()
		if d.frames > d.max_frames:
			to_remove.append(d)

	for t in to_remove:
		if has_signal(t._signal):
			emit_signal(t._signal)
			print_debug("emitting: ", t._signal)
		decaying_forces.erase(t)

	return forces


func is_on_floor():
	return $floorDetector.is_colliding()


func can_dash():
	return $UI/DashCooldown.value == $UI/DashCooldown.max_value and get_user_input(true).length() > 0


func dash(override_dir=null):
	set_state(DASH)
	print("changeing state: ", state)
	$DashSound.play()
	var dash_dir = override_dir if override_dir else get_user_input(true).normalized()
	decaying_forces.append(
		DecayingForce.new(dash_force, dash_dir, 10, 0.8, "dashed")
	)
	emit_signal("started_to_dash")
	vel = Vector2()
	$sprite.play("Dash on")
	afterimage_index = 0
#	animation_lock = true
	empty_dash_meter()


func can_jump(event) -> bool:
	return event.is_action_pressed("jump") and in_coyote_time and state != JUMP

func jump():
	# jump
	set_state(JUMP)
	print("changeing state: ", state)
	decaying_forces.append(
		DecayingForce.new(jump_height, Vector2(0, -1), 5, 1.0)
	)


func fill_dash_meter():
	$UI/DashCooldown.value = $UI/DashCooldown.max_value


func empty_dash_meter():
	$UI/DashCooldown.value = $UI/DashCooldown.min_value


func killed(body):
	fill_dash_meter()


### Subroutines ###

### Signal functions ###

func _on_landed():
	# spawn dust cloud
	var dust = load("res://Prefabs/Dust.tscn").instance()
	dust.global_position = global_position
	get_parent().add_child(dust)
	$LandSound.play()
	vel.y = 0


func _on_animation_finished(anim_name: String):
	if anim_name == "Attack":
		gravity_scale = gravity
		set_state(MOVE)
		print("changeing state: ", state)
		animation_lock = false


var animation_lock = false
func _on_sprite_animation_finished():
	if animation_lock:
		animation_lock = false
#		print("animation finished: ", $sprite.animation)


func _on_Player_dashed():
	$sprite.play("Dash off")
	var puff: AnimatedSprite = load("res://Code/helper scenes/DashPuff.tscn").instance()
	puff.global_position = global_position
	puff.flip($sprite.flip_h)
	get_parent().add_child(puff)
	animation_lock = true
	set_state(MOVE)
	print("changeing state: ", state)

var Afterimage_tscn = preload("res://Code/dash/afterimage.tscn")
var afterimage_index = 0

func spawn_afterimage():
	if afterimage_index % 4 == 0:
		var afterimage: Sprite = Afterimage_tscn.instance()
		print("hello")
		afterimage.texture = $sprite.frames.get_frame($sprite.animation, $sprite.frame)
		afterimage.global_position = $sprite.global_position
		afterimage.flip_h = $sprite.flip_h
		get_parent().add_child(afterimage)
		get_parent().move_child(afterimage, get_index()-1)
	
	afterimage_index += 1


func set_health(v):
	health = v
	if health <= 0:
		emit_signal("died")
	emit_signal("health_changed", health, max_health)


func damage(damage_source: Node2D):
	var effect = damage_effect_tscn.instance()
	effect.position = $DamagePosition.position
	$HurtSound.play()
	add_child(effect)
	set_health(health - 1)
	
	# knockback
	decaying_forces.append(
		DecayingForce.new(knockback_force, (global_position - damage_source.global_position).normalized(), 6, 0.85)
	)
	
	flash_white()


func flash_white():
	$sprite.self_modulate = Color(100,100,100,1)
	yield(get_tree().create_timer(0.1), "timeout")
	$sprite.self_modulate = Color(1,1,1,1)
	

func set_state(new_state):
	state = new_state
	match new_state:
		DASH:
			set_collision_mask_bit(2, false) # don't collide with zombies when dashing
		_:
			set_collision_mask_bit(2, true)



### Signal functions ###


class DecayingForce:
	extends Reference

	var power: float
	var dir: Vector2
	var frames: int
	var max_frames: int
	var decay_rate: float
	var _signal: String

	func _init(p=0.0, d=Vector2(1,0), f=1, dr=1.0, s=""):
		power = p
		dir = d
		frames = 0
		max_frames = f
		decay_rate = dr
		_signal = s

	func get_impulse() -> Vector2:
		var impulse = dir*power
		power *= decay_rate
		frames += 1
		return impulse * Vector2(1, 0.7)
