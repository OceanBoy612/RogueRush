extends KinematicBody2D


signal collided
signal landed
signal jumped


export var speed: float = 150
export var jump_height: float = 120
export var attack_force: float = 300
export var gravity_scale: float = 30
export var friction: float = 0.7


var decaying_forces = []
var vel: Vector2 = Vector2()
var prev_vel: Vector2 = Vector2()


var on_floor: bool = false


### Main ###


func _physics_process(delta):
	vel += get_forces()
	vel += get_gravity()
	vel += get_user_input()
#	print(vel * delta * Global.time_scale)
	
	var temp = vel
	vel = move_and_slide(vel * Global.time_scale, Vector2(0, -1))
	
	
	if not on_floor and is_on_floor():
		on_floor = true
		emit_signal("landed")
	if on_floor and not is_on_floor():
		on_floor = false
		emit_signal("jumped")
		
	
	
	
	for i in get_slide_count():
		var collision: KinematicCollision2D = get_slide_collision(i)
		if (temp-vel).length() > 5: # real collisions:
			emit_signal("collided", collision)
		
			
		
#		if collision.normal.is_equal_approx(Vector2(0, 1)) or collision.normal.is_equal_approx(Vector2(0, -1)):
#			continue
#
#		if collision.normal.dot(prev_vel.normalized()) < 0:
#			printt(collision.normal, vel.normalized(), collision.normal.dot(prev_vel.normalized()))
#			# get a kickback
#			decaying_forces.append(
#				DecayingForce.new(kick_back_force, prev_vel.normalized() * -1, 5, 0.7)
##				DecayingForce.new(kick_back_force, collision.normal, 1, 1.0)
#			)
##			vel = vel.bounce(collision.normal) # doesn't work?
#			print("!!!!!!!!!!!!!")
	
	vel.x *= friction
	prev_vel = vel


func _input(event):
	if event.is_action_pressed("ui_accept"):
		# jump
		if is_on_floor():
			decaying_forces.append(
				DecayingForce.new(jump_height, Vector2(0, -1), 5, 1.0)
			)
	if event.is_action_pressed("attack"):
		decaying_forces.append(
			DecayingForce.new(attack_force, vel.normalized(), 5, 0.5)
		)


### Main ###

### Subroutines ###

func get_user_input() -> Vector2:
	return Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		0
	) * speed


func get_gravity() -> Vector2:
	if not is_on_floor():
		return Vector2(0, 1) * gravity_scale
	else:
		return Vector2(0, 1) * gravity_scale * 0.01


func get_forces() -> Vector2:
	var forces = Vector2()
	
	var to_remove = []
	for d in decaying_forces:
		d = (d as DecayingForce)
		forces += d.get_impulse()
		if d.frames > d.max_frames:
			to_remove.append(d)
	
	for t in to_remove:
		decaying_forces.erase(t)
	
	return forces


### Subroutines ###














class DecayingForce:
	extends Reference
	
	var power: float
	var dir: Vector2
	var frames: int
	var max_frames: int
	var decay_rate: float
	
	func _init(p=0.0, d=Vector2(1,0), f=1, dr=1.0):
		power = p
		dir = d
		frames = 0
		max_frames = f
		decay_rate = dr
	
	func get_impulse() -> Vector2:
		var impulse = dir*power
		power *= decay_rate
		frames += 1
		return impulse
