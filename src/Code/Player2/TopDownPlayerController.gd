extends KinematicBody2D


export var MAX_SPEED = 200     # pixels per second I believe
export var ACCELERATION = 1500 # Accel for both moving and stopping
export var SLIPPERY = false    # whether the character slides a bit when changing directions - depreciated
export var FRICTION: float = 1000

var lock_x = false
var lock_y = false
var lock_movement = false

#enum LockAxisOptions { NEITHER, X, Y, BOTH }
#export(LockAxisOptions) var lock_axis = LockAxisOptions.NEITHER


var motion = Vector2.ZERO
var input_left  = "ui_left"
var input_right = "ui_right"
var input_up    = "ui_up"
var input_down  = "ui_down"


# enumerated counterclockwise, starting from east = 0:
enum Facings {
	RIGHT = 0, DOWNRIGHT = 1,
	DOWN = 2, DOWNLEFT = 3,
	LEFT = 4, UPLEFT = 5,
	UP = 6, UPRIGHT = 7
}
var FacingsDir = [
	Vector2(1,0), Vector2(1,1).normalized(),
	Vector2(0,1), Vector2(-1,1).normalized(),
	Vector2(-1,0), Vector2(-1,-1).normalized(),
	Vector2(0,-1), Vector2(1,-1).normalized(),
]
var facing = "RIGHT"
var axis = Vector2.ZERO


func _physics_process(delta):
	move(delta)


func move(delta: float) -> void:
	get_input_axis()
	calculate_facing()
	if not lock_movement:
		if SLIPPERY: 
			slide_movement(delta)
		else:
			snappier_movement(delta)
		clamp_motion()
	motion = move_and_slide(motion, Vector2.UP)








##### Subroutines #####


func get_input_axis() -> void:
	axis = Vector2(
		Input.get_action_strength(input_right) - Input.get_action_strength(input_left),
		Input.get_action_strength(input_down) - Input.get_action_strength(input_up)
	).normalized()

func calculate_facing():
	# only change directions if we are moving since this breaks at 0,0
	if axis.length_squared() <= 0.1: return
	var angle = atan2( axis.y, axis.x );
	var octant = int( round( 8 * angle / (2*PI) + 8 ) ) % 8;
	facing = Facings.keys()[octant]  # int to enum: 0 -> RIGHT etc.
#	print("facing: ", facing, octant, axis)


func snappier_movement(delta: float) -> void:
	apply_friction(FRICTION * delta)
	apply_movement(axis * ACCELERATION * delta * 2)


func slide_movement(delta: float) -> void:
	if axis == Vector2.ZERO:
		apply_friction(delta)
	else:
		apply_movement(axis * ACCELERATION * delta)


func apply_friction(amount: float) -> void:
	if motion.length() > amount:
		motion -= motion.normalized() * amount
	else:
		motion = Vector2.ZERO


func apply_movement(acceleration) -> void:
	if lock_x: acceleration *= Vector2(0, 1)
	if lock_y: acceleration *= Vector2(1, 0)
	motion += acceleration


func clamp_motion():
	motion = motion.clamped(MAX_SPEED)
