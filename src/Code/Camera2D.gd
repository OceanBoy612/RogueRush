extends Camera2D





export var player_path: NodePath = NodePath("../Player")
export var bob_amount = 25
export(float, 0, 0.2, 0.01) var bob_duration = 0.08


onready var player: KinematicBody2D = get_node(player_path)


var offset_pos: Vector2 = Vector2()


func _ready():
	player.connect("landed", self, "_on_player_landed")


func _process(delta):
	global_position = player.global_position + offset_pos


func _on_player_landed():
	# Bob downwards
	var bob_pos = Vector2(0, 1) * bob_amount
	$Tween.interpolate_property(self, "offset_pos", Vector2(), bob_pos,
			bob_duration, Tween.TRANS_SINE, Tween.EASE_OUT)
	$Tween.interpolate_property(self, "offset_pos", bob_pos, Vector2(),
			bob_duration, Tween.TRANS_SINE, Tween.EASE_OUT, bob_duration)
	$Tween.start()
