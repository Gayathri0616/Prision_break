class_name Enemy
extends CharacterBody2D

# Signals for target changes and death
signal target_changed(pos: Vector2)
signal dead

# Exported variables for the Godot Inspector
@export var rot_speed: float = 10.0
@export var health: int = 100:
	set = set_health
@export var speed: int = 300

# Damage dealt when reaching an objective
var objective_damage := 10

# Variables for collision-based direction reversal
var collision_cooldown: float = 0.5
var collision_timer: float = 0.0
var is_colliding: bool = false

# Node references
@onready var state_machine := $StateMachine as StateMachine
@onready var nav_agent := $NavigationAgent2D as NavigationAgent2D
@onready var sprite := $Sprite2D as AnimatedSprite2D
@onready var collision := $CollisionShape2D as CollisionShape2D
@onready var hud := $UI/EntityHUD as EntityHud

# Initialization
func _ready() -> void:
	# Initialize HUD
	hud.state_label.text = state_machine.current_state.name
	hud.healthbar.max_value = health
	hud.healthbar.value = health
	# Initialize navigation agent
	nav_agent.max_speed = speed

# Physics processing for rotation and collision handling
func _physics_process(delta: float) -> void:
	# Update collision timer
	if is_colliding:
		collision_timer -= delta
		if collision_timer <= 0:
			is_colliding = false
	
	# Rotate sprite and collision shape based on velocity
	if sprite:
		sprite.global_rotation = _calculate_rot(sprite.global_rotation, velocity.angle(), rot_speed, delta)
	if collision:
		collision.global_rotation = _calculate_rot(collision.global_rotation, velocity.angle(), rot_speed, delta)

# Move to a target position
func move_to(pos: Vector2) -> void:
	nav_agent.target_position = pos
	target_changed.emit(nav_agent.target_position)

# Stop movement
func stop() -> void:
	if velocity == Vector2.ZERO:
		return
	nav_agent.set_velocity(Vector2.ZERO)

# Play an animation if it exists
func apply_animation(anim_name: String) -> void:
	if sprite and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
	else:
		print_debug("Sprite node doesn't have animation %s!" % anim_name)

# Setter for health, updates HUD
func set_health(value: int) -> void:
	health = max(0, value)
	if is_instance_valid(hud):
		hud.healthbar.value = health

# Calculate smooth rotation using interpolation
func _calculate_rot(start_rot: float, target_rot: float, _speed: float, delta: float) -> float:
	return lerp_angle(start_rot, target_rot, _speed * delta)

# Handle velocity computed by NavigationAgent2D
func _on_navigation_agent_2d_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
	var collision = move_and_slide()
	
	# Check for collision and reverse
