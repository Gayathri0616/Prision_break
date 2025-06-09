
extends Node2D

# Maze dimensions
const ROWS = 40
const COLS = 30

# Tilemap settings
const WALL_TILE_ID = 0  # ID of the wall tile
const PATH_TILE_ID = 1  # ID of the path tile
const SOURCE_ID = 0     # Tile source ID
const TILE_LAYER = 0    # Layer for maze tiles

# Game constants
const STARTING_MONEY := 5000

# Maze data
var maze = []

@onready var objective := $Objective as Objective
@onready var spawner := $Spawner as Spawner
@onready var camera := $Camera2D as Camera2D
@onready var tilemap := $TileMap as TileMap

func _ready() -> void:
	randomize()
	initialize_maze()
	generate_maze()
	Global.money = STARTING_MONEY
	var map_limits := tilemap.get_used_rect()
	var cell_size := tilemap.tile_set.tile_size
	camera.limit_left = int(map_limits.position.x) * cell_size.x
	camera.limit_top = int(map_limits.position.y) * cell_size.y
	camera.limit_right = int(map_limits.end.x) * cell_size.x + cell_size.x
	camera.limit_bottom = int(map_limits.end.y) * cell_size.y
	spawner.countdown_started.connect(Callable(camera.hud, "_on_spawner_countdown_started"))
	spawner.wave_started.connect(Callable(camera.hud, "_on_spawner_wave_started"))
	spawner.enemies_defeated.connect(Callable(camera.hud, "_on_spawner_enemies_defeated"))
	objective.health_changed.connect(Callable(camera.hud, "_on_objective_health_changed"))
	objective.destroyed.connect(Callable(camera.hud, "_on_objective_destroyed"))
	(camera.hud as Hud).initialize(objective.health)
	spawner.initialize(objective.global_position, map_limits, cell_size)

func initialize_maze():
	maze = []
	for r in range(ROWS):
		var row = []
		for c in range(COLS):
			row.append(1)
		maze.append(row)

func generate_maze():
	for r in range(ROWS):
		for c in range(COLS):
			maze[r][c] = 1
			tilemap.set_cell(TILE_LAYER, Vector2i(c, r), SOURCE_ID, Vector2i(0, 0), WALL_TILE_ID)
	var start_row = 1
	var start_col = 1
	maze[start_row][start_col] = 0
	tilemap.set_cell(TILE_LAYER, Vector2i(start_col, start_row), SOURCE_ID, Vector2i(0, 0), PATH_TILE_ID)
	carve_passages(start_row, start_col)
	var objective_pos = tilemap.local_to_map(objective.global_position)
	var exit_pos = Vector2i(COLS - 2, ROWS - 2)
	if maze[exit_pos.y][exit_pos.x] != 0:
		maze[exit_pos.y][exit_pos.x] = 0
		tilemap.set_cell(TILE_LAYER, exit_pos, SOURCE_ID, Vector2i(0, 0), PATH_TILE_ID)
	spawner.position = tilemap.map_to_local(Vector2i(start_col, start_row))
	Global.final_door_position = tilemap.map_to_local(tilemap.local_to_map(exit_pos))

func carve_passages(r, c):
	var directions = [[-2, 0], [0, 2], [2, 0], [0, -2]]
	directions.shuffle()
	for direction in directions:
		var dr = direction[0]
		var dc = direction[1]
		var new_r = r + dr
		var new_c = c + dc
		if new_r > 0 and new_r < ROWS - 1 and new_c > 0 and new_c < COLS - 1 and maze[new_r][new_c] == 1:
			maze[r + dr/2][c + dc/2] = 0
			tilemap.set_cell(TILE_LAYER, Vector2i(c + dc/2, r + dr/2), SOURCE_ID, Vector2i(0, 0), PATH_TILE_ID)
			maze[new_r][new_c] = 0
			tilemap.set_cell(TILE_LAYER, Vector2i(new_c, new_r), SOURCE_ID, Vector2i(0, 0), PATH_TILE_ID)
			carve_passages(new_r, new_c)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Global.turret_actions:
			Global.turret_actions.hide()
