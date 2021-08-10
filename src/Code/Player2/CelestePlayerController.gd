extends "res://Code/Player2/TopDownPlayerController.gd"
tool

"""
A short thread on a few Celeste game-feel things :) I don't think we invented any of these.

~~~1- Coyote time. You can still jump for a short time after leaving a ledge.

~~~2- Jump buffering. If you press and hold the jump button a short time before landing, you will jump on the exact frame that you land.

~~~3- Halved gravity jump peak. This one is hard to see. If you hold the jump button, the top of your jump has half gravity applied. It's subtle, but this gives you more time to adjust for landing, and also just looks/feels pleasant.

4- Jump corner correction. If you bonk your head on a corner, the game tries to wiggle you to the side around it.

5- Dash corner correction. Also tough to see, but if you dash sideways and clip a corner, it'll pop you up onto the ledge.

6- We also pop you up onto semi-solid platforms if you dash sideways through them.

7- Lift momentum storage. Jumping off a fast-moving platform adds the platform's momentum to your jump's speed. Madeline "stores" this momentum and will still get the boosted jump for a few frames after the platform has stopped.

~~~8- You can actually wall jump 2 pixels from a wall. (That sounds tiny but this is a 320x180-resolution game :P)

9- If you're doing a "super wall jump" (ie: a wall jump while dashing upward), this is a more precise and demanding maneuver so we let you do it from even further away (I think it's 5 pixels, which is more than half a tile!)

10- And this final one is complicated but very important for Celeste. Some setup: If you're grabbing a wall and jump straight upward, that consumes a lot of stamina. But if you jump away from the wall, that's a normal wall jump that uses no stamina and pushes you away strongly. So if you perform the straight upward jump, then press away from the wall shortly after, the game refunds the stamina spent by the upward jump, and applies the horizontal wall jump force. It converts from one jump type to the other after the fact.

There are videos for each example if you want to follow the link but these are the ten that were posted.

TODO:
	the above, but also
	~~snap to wall when you grab
	proper jumping types. On wall vs off wall vs normal vs dash
	~~implement a dash
	
	when you jump, disable the movement in the direction of the wall so that
		if you want to go back you have to release then press the key again

"""


signal jumped
signal landed
signal wall_jumped
signal just_grabbed_a_wall
signal just_released_a_wall

signal dashed


export var JUMP_POWER = 250 
export var GRAVITY = 9.8 * 70

export var halve_gravity_at_jump_peak_enabled: bool = true
export var wall_grab_enabled: bool = true
export var wall_jump_enabled: bool = true



var input_jump = "ui_accept"
var input_dash = "dash"

var is_facing_locked = false
var is_axis_locked = false


# vector position constants

onready var height = $CollisionBox.shape.height
onready var radius = $CollisionBox.shape.radius

onready var BOTTOM = Vector2()
onready var BOTTOMLEFT = BOTTOM - Vector2(radius,0)
onready var BOTTOMRIGHT = BOTTOM + Vector2(radius,0)

onready var LEFT = BOTTOMLEFT - Vector2(0, radius + (height / 2) )
onready var RIGHT = BOTTOMRIGHT - Vector2(0, radius + (height / 2) )

onready var TOP = BOTTOM - Vector2(0, radius + radius + height )
onready var TOPLEFT = TOP - Vector2(radius,0)
onready var TOPRIGHT = TOP + Vector2(radius,0)

# vector position constants



# jump
var time_since_last_jump = 999
var time_between_jumps = 0.2
var is_jumping = false
export var AIR_FRICTION_MULTIPLIER: float = 0.3
# jump

# halve gravity
var apply_gravity_enabled: bool = true
var grav_mult = 1.0
# halve gravity

# coyote time
var frames_since_on_wall = 999 # arbitrary high so no jump at game start
var frames_since_on_floor = 999 # arbitrary high so no jump at game start
export var coyote_time_frames_floor = 10
export var coyote_time_frames_wall = 5
var in_floor_coyote_time = false
var in_wall_coyote_time = false
# coyote time

# jump buffering
var frames_since_jump_pressed = 999
export var jump_buffer_frame_amount = 8 
var is_jump_buffering = false
# jump buffering

# wall grab
export var wall_snap: bool = true
var distance_from_right_wall = 999
var distance_from_left_wall = 999
export var wall_grab_distance = 3.2 # in pixels
var on_right_wall = false
var on_left_wall = false
var frames_on_wall: int = 0
var time_on_wall: float = 0
var can_wall_grab: bool = false

var just_grabbed_right_wall = false
var just_released_right_wall = false
var just_grabbed_left_wall = false
var just_released_left_wall = false
var on_a_wall = false
var just_grabbed_a_wall = false
var just_released_a_wall = false
# wall grab

# wall jump
export var wall_jump_lock_time = 0.2 # time after a wall jump with no player control
# wall jump

# dash
var is_dash_just_pressed = false
export var DASH_POWER = 350
export var dash_time = 0.2
# dash

func _init():
	lock_y = true

func move(delta: float) -> void:
	update()
	if Engine.editor_hint: 
		return 
	
	### Checks ###
	is_dash_just_pressed = Input.is_action_just_pressed(input_dash)
	if wall_grab_enabled: wall_grab(delta)
	if halve_gravity_at_jump_peak_enabled: halve_gravity_at_jump_peak(delta)
	jump_buffering()
	coyote_time()
	### Checks ###
	
	
	
	if apply_gravity_enabled: apply_gravity(delta)
	
	
	# most specific case to most general
	var can_regular_jump = is_jump_buffering and in_floor_coyote_time
	var can_wall_jump = is_jump_buffering and in_wall_coyote_time and not in_floor_coyote_time
#	var can_wall_climb = can_wall_jump and Facings[facing] == Facings.UP # unimplemented
	var can_dash = Input.is_action_just_pressed("dash")
#	var can_wall_dash = false # unimplemented
	
	if false: pass
#	elif can_wall_climb:   wall_climb()
	elif can_dash:    	   regular_dash()
	elif can_wall_jump:    wall_dash()
	elif can_regular_jump: regular_jump()
	elif can_wall_grab:
		# we did not jump this frame so grab the wall
		if wall_snap: apply_wall_snap()
		apply_wall_grab(delta)
	
	
#	print(position.y)
#	print(motion.y)
	
	.move(delta)



################################ Override ################################

func get_input_axis():
	if not is_axis_locked:
		.get_input_axis()
func calculate_facing():
	if not is_facing_locked:
		.calculate_facing()

# Apply friction only to x when on the ground
func apply_friction(amount: float) -> void:
	if not in_floor_coyote_time: # in air?
		amount *= AIR_FRICTION_MULTIPLIER
	
	if abs(motion.x) > amount:
		if motion.x > 0: motion.x -= amount
		else:            motion.x += amount
	else:
		motion.x = 0

# clamp only x speed
func clamp_motion() -> void:
	motion = Vector2(clamp(motion.x, -MAX_SPEED, MAX_SPEED), motion.y)

################################ End Override ################################

################################ Action Subroutines ################################

func regular_jump():
	motion.y = -JUMP_POWER
	time_since_last_jump = 0
	facing = "DOWN"
	emit_signal("jumped")
	print("jumped")
	is_jump_buffering = false
	pass

func wall_dash():
	# because of coyote time we might not be on a wall when we jump
	var right_wall_closer = distance_from_right_wall < distance_from_left_wall
	facing = "UPLEFT" if right_wall_closer else "UPRIGHT"
	
	_dash(JUMP_POWER, wall_jump_lock_time)
	
	emit_signal("wall_jumped")
	print("wall_jumped")
	is_jump_buffering = false

func regular_dash():
	_dash(DASH_POWER, dash_time)
	
	
	emit_signal("dashed")


func _dash(power: float, time_sec: float):
	axis = FacingsDir[Facings[facing]]
	motion = axis * power
	lock_facing(time_sec)

func wall_climb(): # this is actually a type of dash
	motion.y = -JUMP_POWER
	emit_signal("wall_climbed")
	print("wall_climbed")
	is_jump_buffering = false
	pass

func apply_wall_grab(delta):
	motion.y *= 0.6
	frames_on_wall += 1
	time_on_wall += delta

func apply_wall_snap():
	if just_grabbed_left_wall:
		print('snap left')
		position.x -= distance_from_left_wall
	if just_grabbed_right_wall:
		print('snap right')
		position.x += distance_from_right_wall

func apply_gravity(delta: float):
	motion.y += GRAVITY * delta * grav_mult

################################ Action Subroutines ################################

################################ Subroutines ################################

func lock_facing(time_sec: float):
#	var temp = MAX_SPEED
#	MAX_SPEED = 999999
	lock_movement = true
	is_facing_locked = true
	is_axis_locked = true
	yield(get_tree().create_timer(time_sec), "timeout")
	print("done")
#	MAX_SPEED = temp
	lock_movement = false
	is_facing_locked = false
	is_axis_locked = false

func set_jump_type():
	pass

func detect_walls():
	# detect walls
	#	right wall raycast
	distance_from_right_wall = intersect_ray(RIGHT.linear_interpolate(TOPRIGHT, 0.5), Vector2(20,0))
	var old_on_right_wall = on_right_wall
	on_right_wall = distance_from_right_wall < wall_grab_distance \
					and (Facings[facing] != Facings.LEFT \
					and Facings[facing] != Facings.UPLEFT \
					and Facings[facing] != Facings.DOWNLEFT \
					and Facings[facing] != Facings.DOWN)
#	print(on_right_wall, distance_from_right_wall)
	just_grabbed_right_wall = on_right_wall and not old_on_right_wall
	just_released_right_wall = not on_right_wall and old_on_right_wall
	#	right wall raycast
	#	left wall raycast
	distance_from_left_wall = intersect_ray(LEFT.linear_interpolate(TOPLEFT, 0.5), Vector2(-20,0))
	var old_on_left_wall = on_left_wall
	on_left_wall = distance_from_left_wall < wall_grab_distance \
					and (Facings[facing] != Facings.RIGHT \
					and Facings[facing] != Facings.UPRIGHT \
					and Facings[facing] != Facings.DOWNRIGHT \
					and Facings[facing] != Facings.DOWN)
#	print(on_left_wall, distance_from_left_wall)
	just_grabbed_left_wall = on_left_wall and not old_on_left_wall
	just_released_left_wall = not on_left_wall and old_on_left_wall
	#	left wall raycast
	
	on_a_wall = on_left_wall or on_right_wall
	just_grabbed_a_wall = just_grabbed_right_wall or just_grabbed_left_wall
	just_released_a_wall = just_released_left_wall or just_released_right_wall
	
	can_wall_grab = on_a_wall and not in_floor_coyote_time
	# detect walls


func wall_grab(_delta):
	detect_walls()
	# wall grab
	if just_grabbed_a_wall:
#		motion.y = 0
		frames_on_wall = 0
		time_on_wall = 0
		print("wall grab")
		emit_signal("just_grabbed_a_wall")
	
	if just_released_a_wall:
		emit_signal("just_released_a_wall")
	# wall grab
	

func halve_gravity_at_jump_peak(delta):
	#Halved gravity jump peak
	# btw: motion.y * delta == derivative
	if not on_right_wall and not on_left_wall:
		var halved_gravity = abs(motion.y) * delta < 1.0
		grav_mult = 0.5 if halved_gravity else 1.0
	else:
		grav_mult = 0.0
	#Halved gravity jump peak

	

func coyote_time():
	# coyote time
	
	frames_since_on_wall += 1
	frames_since_on_floor += 1
	if is_on_floor():
		frames_since_on_floor = 0
		emit_signal("landed")
	if on_a_wall:
		frames_since_on_wall = 0
	in_floor_coyote_time = frames_since_on_floor < coyote_time_frames_floor
	in_wall_coyote_time = frames_since_on_wall < coyote_time_frames_wall
#	if frames_since_on_floor == coyote_time_frames:
#		print("End coyote time")
	# coyote time

func jump_buffering():
	# jump buffering
	frames_since_jump_pressed += 1
	if Input.is_action_just_pressed(input_jump):
		frames_since_jump_pressed = 0
		is_jump_buffering = true
	else:
		is_jump_buffering = frames_since_jump_pressed < jump_buffer_frame_amount \
							and is_jump_buffering
#	if frames_since_jump_pressed == jump_buffer_frame_amount:
#		print("End jump buffer")
	# jump buffering



func intersect_ray(start_offset: Vector2, offset: Vector2):
	var space_state = get_world_2d().direct_space_state
	var start_pos = global_position + start_offset
	var target_pos = start_pos + offset
	var result = space_state.intersect_ray(start_pos, target_pos, [], 1) # only collide with the first col layer
	if not result.empty(): # ray hit something
		return start_pos.distance_to(result.position)
	else:
		return offset.length()


################################ Subroutines End ################################







#Tool debug stuff
func _draw():
	var height = $CollisionBox.shape.height
	var radius = $CollisionBox.shape.radius
	
	BOTTOM = Vector2()
	BOTTOMLEFT = BOTTOM - Vector2(radius,0)
	BOTTOMRIGHT = BOTTOM + Vector2(radius,0)

	LEFT = BOTTOMLEFT - Vector2(0, radius + (height / 2) )
	RIGHT = BOTTOMRIGHT - Vector2(0, radius + (height / 2) )

	TOP = BOTTOM - Vector2(0, radius + radius + height )
	TOPLEFT = TOP - Vector2(radius,0)
	TOPRIGHT = TOP + Vector2(radius,0)
	
	draw_line(LEFT, LEFT+Vector2(-10,0), Color("#ffaaff"), 1.5)
	draw_string(Control.new().get_font("font"), BOTTOMRIGHT, str(distance_from_left_wall), Color("ffffff"))
	draw_string(Control.new().get_font("font"), BOTTOMRIGHT+Vector2(0,20), str(distance_from_right_wall), Color("ffffff"))
	draw_string(Control.new().get_font("font"), BOTTOMRIGHT+Vector2(0,40), str(facing), Color("ffffff"))
	
	draw_circle(BOTTOM, 2, Color("#ffffff"))
	draw_circle(BOTTOMRIGHT, 1, Color("#ffffff"))
	draw_circle(BOTTOMLEFT, 1, Color("#ffffff"))
	
	draw_circle(LEFT, 1, Color("#ffffff"))
	draw_circle(RIGHT, 1, Color("#ffffff"))
	
	draw_circle(TOP, 2, Color("#ffffff"))
	draw_circle(TOPRIGHT, 1, Color("#ffffff"))
	draw_circle(TOPLEFT, 1, Color("#ffffff"))
















# corner correction
#	var collision : KinematicCollision2D = move_and_collide(motion*delta, true, true, true)
#	if collision:
#		print(collision.position)
#		emit_signal("collider_test", collision)
#//Corner Correction
#                {
#                    if (Speed.X <= 0)
#                    {
#                        for (int i = 1; i <= UpwardCornerCorrection; i++)
#                        {
#                            if (!CollideCheck<Solid>(Position + new Vector2(-i, -1)))
#                            {
#                                Position += new Vector2(-i, -1);
#                                return;
#                            }
#                        }
#                    }
#
#                    if (Speed.X >= 0)
#                    {
#                        for (int i = 1; i <= UpwardCornerCorrection; i++)
#                        {
#                            if (!CollideCheck<Solid>(Position + new Vector2(i, -1)))
#                            {
#                                Position += new Vector2(i, -1);
#                                return;
#                            }
#                        }
#                    }
	# corner correction
