extends Node2D

# Maze dimensions (adjust based on your circled path size)
const ROWS = 20
const COLS = 20
const CELL_SIZE = 32  # Adjust to match your TileMap cell size (e.g., 16, 32, or 64)

# Tilemap settings (updated with your coordinates as tile IDs)
const WALL_TILE_ID = 2  # Brown wall tile ID from your tileset
const PATH_TILE_ID = 3  # Green path tile ID from your tileset
const SOURCE_ID = 0     # Tile source ID in your tileset
const TILE_LAYER = 0    # Layer for maze tiles

# Game constants
const STARTING_MONEY := 5000

# Maze data
var maze = []
var maze_offset = Vector2i(0, 0)  # Offset to align maze with circled path

@onready var objective := $Objective as Objective
@onready var spawner := $Spawner as Spawner
@onready var camera := $Camera2D as Camera2D
@onready var tilemap := $TileMap as TileMap

func _ready() -> void:
	randomize()
	# Ensure TileMap is at origin
	tilemap.position = Vector2(0, 0)
	# Initialize maze array
	initialize_maze()
	# Generate maze within the path area
	generate_maze()
	# Initialize money
	Global.money = STARTING_MONEY
	# Initialize camera
	update_camera_limits()
	# Connect signals
	spawner.countdown_started.connect(Callable(camera.hud, "_on_spawner_countdown_started"))
	spawner.wave_started.connect(Callable(camera.hud, "_on_spawner_wave_started"))
	spawner.enemies_defeated.connect(Callable(camera.hud, "_on_spawner_enemies_defeated"))
	objective.health_changed.connect(Callable(camera.hud, "_on_objective_health_changed"))
	objective.destroyed.connect(Callable(camera.hud, "_on_objective_destroyed"))
	# Initialize HUD parameters
	(camera.hud as Hud).initialize(objective.health)
	# Start spawning enemies
	var map_limits = tilemap.get_used_rect()
	var cell_size = tilemap.tile_set.tile_size
	spawner.initialize(objective.global_position, map_limits, cell_size)

func initialize_maze():
	# Create a 2D array filled with walls (1)
	maze = []
	for r in range(ROWS):
		var row = []
		for c in range(COLS):
			row.append(1)
		maze.append(row)

func generate_maze():
	# Calculate maze offset based on spawner position
	var start_pos = tilemap.local_to_map(spawner.position)
	maze_offset = Vector2i(start_pos.x, start_pos.y)  # Start maze at spawner position
	
	# Clear existing tiles in the maze area to avoid overlap
	for r in range(ROWS):
		for c in range(COLS):
			var tile_pos = Vector2i(c, r) + maze_offset
			tilemap.set_cell(TILE_LAYER, tile_pos, -1)  # Clear tile
	
	# Reset maze area to walls
	for r in range(ROWS):
		for c in range(COLS):
			var tile_pos = Vector2i(c, r) + maze_offset
			maze[r][c] = 1
			tilemap.set_cell(TILE_LAYER, tile_pos, SOURCE_ID, Vector2i(0, 0), WALL_TILE_ID)
	
	# Start at a position near the spawner (adjusted for maze grid)
	var start_row = 1
	var start_col = 1
	maze[start_row][start_col] = 0
	tilemap.set_cell(TILE_LAYER, Vector2i(start_col, start_row) + maze_offset, SOURCE_ID, Vector2i(0, 0), PATH_TILE_ID)
	
	# Carve passages
	carve_passages(start_row, start_col)
	
	# Ensure objective is on a path (adjust end position within maze bounds)
	var end_pos = tilemap.local_to_map(objective.position) - maze_offset
	var end_row = min(ROWS - 2, max(1, end_pos.y))
	var end_col = min(COLS - 2, max(1, end_pos.x))
	ensure_path_to_end(start_row, start_col, end_row, end_col)
	
	# Update objective position to a valid maze end point
	objective.position = tilemap.map_to_local(Vector2i(end_col, end_row) + maze_offset)
	spawner.position = tilemap.map_to_local(Vector2i(start_col, start_row) + maze_offset)

func carve_passages(r, c):
	# Define the four possible directions (up, right, down, left) with a step of 2
	var directions = [
		[-2, 0],  # Up
		[0, 2],   # Right
		[2, 0],   # Down
		[0, -2]   # Left
	]
	
	# Randomize direction order
	directions.shuffle()
	
	# Try each direction
	for direction in directions:
		var dr = direction[0]
		var dc = direction[1]
		
		var new_r = r + dr
		var new_c = c + dc
		
		# Check if the new position is valid and still a wall
		if (new_r > 0 and new_r < ROWS - 1 and new_c > 0 and new_c < COLS - 1 and 
			maze[new_r][new_c] == 1):
			# Carve passage by making the wall between current and new cell a path
			maze[r + dr/2][c + dc/2] = 0
			var tile_pos = Vector2i(c + dc/2, r + dr/2) + maze_offset
			tilemap.set_cell(TILE_LAYER, tile_pos, SOURCE_ID, Vector2i(0, 0), PATH_TILE_ID)
			# Make the new cell a path
			maze[new_r][new_c] = 0
			tilemap.set_cell(TILE_LAYER, Vector2i(new_c, new_r) + maze_offset, SOURCE_ID, Vector2i(0, 0), PATH_TILE_ID)
			# Continue from the new cell
			carve_passages(new_r, new_c)

func ensure_path_to_end(start_r, start_c, end_r, end_c):
	# Simple pathfinding to ensure connection to objective
	var visited = []
	for r in range(ROWS):
		visited.append([])
		for c in range(COLS):
			visited[r].append(false)
	
	var stack = [[start_r, start_c]]
	visited[start_r][start_c] = true
	
	while stack:
		var current = stack.pop_back()
		var r = current[0]
		var c = current[1]
		
		if [r, c] == [end_r, end_c]:
			maze[end_r][end_c] = 0
			tilemap.set_cell(TILE_LAYER, Vector2i(c, r) + maze_offset, SOURCE_ID, Vector2i(0, 0), PATH_TILE_ID)
			break
		
		var directions = [[0, 1], [1, 0], [0, -1], [-1, 0]]  # Right, Down, Left, Up
		directions.shuffle()
		for dir in directions:
			var new_r = r + dir[0]
			var new_c = c + dir[1]
			if (new_r >= 0 and new_r < ROWS and new_c >= 0 and new_c < COLS and 
				not visited[new_r][new_c] and maze[new_r][new_c] == 1):
				maze[new_r][new_c] = 0
				tilemap.set_cell(TILE_LAYER, Vector2i(new_c, new_r) + maze_offset, SOURCE_ID, Vector2i(0, 0), PATH_TILE_ID)
				visited[new_r][new_c] = true
				stack.append([new_r, new_c])

func update_camera_limits():
	# Set camera limits to include the full maze area
	var map_limits = tilemap.get_used_rect()
	var cell_size = tilemap.tile_set.tile_size
	camera.limit_left = min(0, map_limits.position.x * cell_size.x)
	camera.limit_top = min(0, map_limits.position.y * cell_size.y)
	camera.limit_right = max(map_limits.end.x * cell_size.x, (maze_offset.x + COLS) * cell_size.x)
	camera.limit_bottom = max(map_limits.end.y * cell_size.y, (maze_offset.y + ROWS) * cell_size.y)
	# Center the camera on the maze area
	var center = Vector2((camera.limit_right + camera.limit_left) / 2, (camera.limit_bottom + camera.limit_top) / 2)
	camera.position = center
	# Ensure camera zoom fits the map
	camera.zoom = Vector2(1.0, 1.0)  # Reset zoom if needed

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# If there's a turret actions UI visible, hide it
		if Global.turret_actions:
			Global.turret_actions.hide()
