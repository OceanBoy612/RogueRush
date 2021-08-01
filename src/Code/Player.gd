extends KinematicBody2D


signal collided
signal landed
signal jumped
signal attacked
signal dashed


export var speed: float = 55
export var jump_height: float = 220
export var attack_force: float = 35
export var dash_force: float = 260
export var gravity: float = 11
var gravity_scale
export var friction: float = 0.7
export var time_between_stomps: int = 2700
export var coyote_time_frames: int = 8


var decaying_forces = []
var vel: Vector2 = Vector2()
var prev_vel: Vector2 = Vector2()
var playerattack_tscn = preload("res://Prefabs/PlayerAttack.tscn")
var on_floor: bool = false

var in_coyote_time = false
var time_since_on_floor: float = 0


enum {
	MOVE,
	ATTACK,
	JUMP,
	DASH,
}
var state = MOVE

### Main ###


func _physics_process(delta):
	if Global.time_scale == 0:
		return

	vel += get_forces()
	vel += get_gravity()
	if state == MOVE or state == JUMP:
		vel += get_user_input()
#	print(vel * delta * Global.time_scale)

	var temp = vel
	vel = move_and_slide(vel * Global.time_scale, Vector2(0, -1))

	handle_checks()
	handle_animations()

	if on_floor: time_since_on_floor = 0
	else: time_since_on_floor += delta
	in_coyote_time = time_since_on_floor < 0.01667 * coyote_time_frames # four frames

	for i in get_slide_count():
		var collision: KinematicCollision2D = get_slide_collision(i)
		if (temp-vel).length() > 5: # real collisions:
			emit_signal("collided", collision)

	vel.x *= friction
	prev_vel = vel


func _input(event):
	if state == ATTACK:
		return

	if event.is_action_pressed("jump") and in_coyote_time and state != JUMP:
		# jump
		state = JUMP
		print("changeing state: ", state)
		decaying_forces.append(
			DecayingForce.new(jump_height, Vector2(0, -1), 5, 1.0)
		)
	if event.is_action_pressed("attack") and is_on_floor() and state == MOVE:
		state = ATTACK
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

	# on floor not on floor
	if not on_floor and is_on_floor() and .is_on_floor(): #landed
		on_floor = true
		state = MOVE
		print("changeing state: ", state)

		$sprite.play("Jump land")
		animation_lock = true

		emit_signal("landed")
		return
	elif on_floor and not is_on_floor(): # jumped
		on_floor = false
		emit_signal("jumped")

		$sprite.play("Jump")
		animation_lock = true
		return

	if animation_lock:
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
	return $UI/DashCooldown.value == $UI/DashCooldown.max_value


func dash():
	state = DASH
	print("changeing state: ", state)
#	$DashSound.play()
	decaying_forces.append(
		DecayingForce.new(dash_force, get_user_input(true).normalized(), 10, 0.8, "dashed")
	)
	vel = Vector2()
	$sprite.play("Dash on")
	animation_lock = true
	empty_dash_meter()


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
		state = MOVE
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
	state = MOVE
	print("changeing state: ", state)



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
		return impulse * Vector2(1, 0.2)
