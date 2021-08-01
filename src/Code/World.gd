tool
extends Node2D


export var _spawn_level: bool setget spawn_level2
export var room_number : int = 5


onready var background : TileMap = $Background
onready var foreground : TileMap = $Foreground


const color_wall: Color = Color("#000000")
const color_air: Color = Color("#ffffff")
const color_spawn: Color = Color("#ff00ff")
const color_exit: Color = Color("#ffff00")

const wall_id: int = 1 # tilemap id for the tiles
const air_id: int = -1 # tilemap id for the tiles


var rooms_dir = "res://Rooms/"
var start_room_name = "Start.png"
var offset: Vector2 = Vector2(0, 0)
var entrance: Vector2 = Vector2(0, 0)
var exit: Vector2 = Vector2(0, 0)
var room_info = {
	"exits" : [],
	"player_spawns" : [],
	"enemy_spawns" : []
}


func _ready():
	$Player.connect("attacked", self, "on_player_attack")
	$Player.connect("landed", self, "on_player_landed")
	$Player.connect("jumped", self, "on_player_jumped")
#	$Zombie.connect("died", self, "on_zombie_died")
	
	if Engine.editor_hint:
		return
	
	spawn_level2(true)
#	spawn_level(true)

func on_zombie_died():
#	$ZombieDeathSound.play()
	Engine.time_scale = 0.1
	yield(get_tree().create_timer(0.06), "timeout")
	Engine.time_scale = 1

func on_player_attack():
	$Camera2D.add_trauma(0.3)


func on_player_landed():
	$Camera2D.add_trauma(0)

func on_player_jumped():
	$Camera2D.add_trauma(0)
	
func connect_zombies():
	for zombie in $Zombies.get_children():
		if not zombie.is_connected("died", self, "on_zombie_died"):
			zombie.connect("died", self, "on_zombie_died")
			print("connecting zombie")



### Tool Script helpers ###



const ZOMBIE_TILE = 26
const PLAYER_TILE = 27
const EXIT_TILE = 28


func spawn_level2(v=true):
	if v==false:
		return
	
	var rooms: Node2D = load("res://Art/Rooms/Rooms.tscn").instance()
	var start_room = rooms.get_node("Start")
	var end_room = rooms.get_node("End")
	var other_rooms = []
	for child in rooms.get_children():
		if child.name == "Start" and child.name == "End":
			continue
		elif child.name.begins_with("Room"):
			other_rooms.append(child)
	
	#print(start_room, end_room, other_rooms)
	
	# Clear the tilemaps
	clear_tilemaps()
	
	# spawn the start room.
	spawn_a_room(start_room, true)
	offset = room_info[EXIT_TILE][0] + Vector2(1,0)
	
	# for number of rooms, spawn a room
	for i in range(room_number):
		var room_id: int = randi() % other_rooms.size()
		print("prev_room: ", room_info[EXIT_TILE])
		var exits = get_room_exits(other_rooms[room_id])
		
		offset -= exits["entrance"]
		spawn_a_room(other_rooms[room_id])
		offset += exits["exit"] + Vector2(1,0)
		
	# spawn the end room
	var exits = get_room_exits(end_room)
	offset -= exits["entrance"]
	spawn_a_room(end_room)
	
	# update autotile
	$Background.update_bitmask_region()
	$Foreground.update_bitmask_region()
	
	connect_zombies()


func spawn_a_room(room: Node2D, move_player=false):
	room_info = {}
	_spawn_a_tilemap(room, "Background", move_player)
	_spawn_a_tilemap(room, "Foreground2", move_player)
	_spawn_a_tilemap(room, "Foreground", move_player)


func _spawn_a_tilemap(room, tilemap, move_player=false):
	var Tilemap = room.get_node(tilemap)
	var cellvs = Tilemap.get_used_cells() # array of Vector2
	for cellv in cellvs:
		
		var tile_id: int = Tilemap.get_cellv(cellv)
		
		match tile_id:
			EXIT_TILE:
				pass
			PLAYER_TILE:
				if move_player:
					$Player.global_position = $Foreground.map_to_world(cellv+offset)
					$Entrance.global_position = $Player.global_position
				else:
					$Exit.global_position = $Foreground.map_to_world(cellv+offset)
				pass
			ZOMBIE_TILE:
				var zombie = load("res://Prefabs/Zombie.tscn").instance(PackedScene.GEN_EDIT_STATE_INSTANCE)
				zombie.global_position = $Foreground.map_to_world(cellv+offset)
				$Zombies.add_child(zombie)
				zombie.owner = get_tree().get_edited_scene_root()
			_:
				get_node(tilemap).set_cellv(cellv+offset, tile_id)
		
		if not tile_id in room_info:
			room_info[tile_id] = []
		room_info[tile_id].append(cellv)


func get_room_exits(room: Node2D, tilemap: String="Foreground"):
	var Tilemap: TileMap = room.get_node(tilemap)
	var exits = []
	for cellv in Tilemap.get_used_cells(): # array of Vector2
		var tile_id: int = Tilemap.get_cellv(cellv)
		if tile_id != EXIT_TILE:
			continue
		exits.append(cellv)
	
	if exits.size() == 1:
		print("exit size 1")
		return {
			"entrance": exits[0]
		}
	
	assert(exits.size() == 2, "Must only have 2 exits per room. Start and end.")
	
	if exits[0].x < exits[1].x:
		return {
			"entrance": exits[0],
			"exit": exits[1],
		}
	else:
		return {
			"entrance": exits[1],
			"exit": exits[0],
		}
	

func clear_tilemaps():
	for c in $Foreground.get_children(): c.queue_free()
	for c in $Foreground2.get_children(): c.queue_free()
	for c in $Background.get_children(): c.queue_free()
	for c in $Zombies.get_children(): c.queue_free()
	
	# clear the tilemap
	offset = Vector2(0, 0)
	entrance = Vector2(0, 0)
	exit = Vector2(0, 0)
	$Background.clear()
	$Foreground.clear()
	$Foreground2.clear()





































func spawn_level(v):
	if v == false: # we didn't click it so do nothing
		return 
	
	clear_tilemaps()
	
	# load the rooms
	var rooms: Array = load_rooms() # an array of Image objects
	# create the spawn room
	var spawn_room: Image = load(rooms_dir + start_room_name).get_data()
	
	fill_room(spawn_room)
	entrance = room_info["player_spawns"][0]
	$Player.global_position = $Background.map_to_world(offset + room_info["player_spawns"][0])
	exit = room_info["exits"][0]
	
	# for the number of rooms, 
	#  get a random room 
	#  check if it fits in the space
	#  if it does, add it and continue
	#  otherwise choose another room
	# stop if no room can be found
	for _i in range(room_number):
		rooms.shuffle()
		for room in rooms:
			# check if the room fits - unimplemented
			
			# randomly flip the room
			if randi() % 2:
				room.flip_x()
			
			spawn_room(room)
			
#			print(entrance, exit, offset)
			
			break
	
	
	# spawn the exit room
	spawn_room.flip_x()
	spawn_room(spawn_room)
	
	$Exit.global_position = $Background.map_to_world(offset + room_info["player_spawns"][0])
	
	


### Subroutines ###


func spawn_room(room):
	offset = get_new_offset(room)
	fill_room(room)
	entrance = room_info["exits"][0]
	if room_info["exits"].size() > 1:
		exit = room_info["exits"][1]
	$Background.update_bitmask_region()
	$Foreground.update_bitmask_region()


func reset_room_info():
	room_info = {
		"exits" : [],
		"player_spawns" : [],
		"enemy_spawns" : []
	}
	

func get_new_offset(room) -> Vector2:
	# new offset is the one farthest from the current offset.
	var exit_positions = get_exit_positions(room)
	for pos in exit_positions:
#		printt(offset, exit, pos)
		if entrance.distance_to(pos) < 2 or true: # first one found
#			var new_offset = (offset + exit) - pos
			var new_offset = (offset + exit) - pos
#			print("new offset: %s" % [new_offset])
			return new_offset
	push_error("No new offset found")
	return exit


func get_exit_positions(room):
	return iterate_through_room_pixels(room, funcref(self, "_exit_positions"))


func _exit_positions(pixel_color, x, y):
	match pixel_color:
		color_exit:
			return Vector2(x, y)
		_:
			pass


func fill_room(room: Image):
	reset_room_info()
	iterate_through_room_pixels(room, funcref(self, "_build_room"))


func _build_room(pixel_color, x, y):
	match pixel_color:
		color_spawn:
			room_info["player_spawns"].append(Vector2(x, y))
			pass
		color_exit:
			room_info["exits"].append(Vector2(x, y))
			pass
		color_air:
			pass
		color_wall:
			$Background.set_cell(x + offset.x, y + offset.y, wall_id)
			pass


func iterate_through_room_pixels(room: Image, function: FuncRef):
	var output = []
	room.lock()
	for x in room.get_width():
		for y in room.get_height():
			var pixel_color: Color = room.get_pixel(x, y)
			var out = function.call_func(pixel_color, x, y)
			if out: output.append(out)
	room.unlock()
	return output


func load_rooms() -> Array:
	# Returns an array of Image objects
	var file_names = list_files_in_directory(rooms_dir, ".png")
	var rooms = []
	for file_name in file_names:
		if file_name == start_room_name:
			continue
		rooms.append( (load(rooms_dir + file_name) as Texture).get_data() )
	return rooms


static func list_files_in_directory(path, ext=".tres"):
	var files = []
	var dir = Directory.new()
	dir.open(path)
	dir.list_dir_begin()
	
	while true:
		var file = dir.get_next()
		if file == "":
			break
		elif not file.begins_with("."):
			if file.ends_with(ext):
				files.append(file)
	
	dir.list_dir_end()
	
	return files



func _on_Exit_body_entered(body):
	if body.name == "Player":
		spawn_level2(true)
#		spawn_level(true)
