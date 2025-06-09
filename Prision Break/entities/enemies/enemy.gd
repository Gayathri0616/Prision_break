class_name Enemy
extends CharacterBody2D

signal target_changed(pos: Vector2)
signal dead

@export var rot_speed: float = 10.0
@export var health: int = 100:
	set = set_health
@export var speed: int = 50  # Reduced speed for testing

var objective_damage := 10
var target_position := Vector2.ZERO

@onready var state_machine := $StateMachine as StateMachine
@onready var nav_agent := $NavigationAgent2D as NavigationAgent2D
@onready var sprite := $Sprite2D as AnimatedSprite2D:
	get: return $Sprite2D as AnimatedSprite2D
@onready var collision := $CollisionShape2D as CollisionShape2D
@onready var hud := $UI/EntityHUD as EntityHud

func _ready() -> void:
	hud.state_label.text = state_machine.current_state.name
	hud.healthbar.max_value = health
	hud.healthbar.value = health
	nav_agent.max_speed = speed
	nav_agent.avoidance_enabled = true
	if target_position == Vector2.ZERO:
		print("Warning: target_position not set. Please initialize via move_to or set_target_position.")

func _physics_process(delta: float) -> void:
	if target_position != Vector2.ZERO:
		nav_agent.target_position = target_position
		print("Target: ", target_position, " Position: ", global_position)
	
	sprite.global_rotation = _calculate_rot(sprite.global_rotation, velocity.angle(), rot_speed, delta)
	collision.global_rotation = _calculate_rot(collision.global_rotation, velocity.angle(), rot_speed, delta)
	
	move_and_slide()
	
	if is_on_wall() or is_on_ceiling() or is_on_floor():
		_recalculate_path()
		print("Collision detected")

func move_to(pos: Vector2) -> void:
	target_position = pos
	nav_agent.target_position = pos
	target_changed.emit(nav_agent.target_position)

func stop() -> void:
	if velocity == Vector2.ZERO:
		return
	nav_agent.set_velocity(Vector2.ZERO)
	target_position = Vector2.ZERO

func apply_animation(anim_name: String) -> void:
	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
	else:
		print_debug("Sprite node doesn't have animation %s!" % anim_name)

func set_health(value: int) -> void:
	health = max(0, value)
	if is_instance_valid(hud):
		hud.healthbar.value = health

func _calculate_rot(start_rot: float, target_rot: float, _speed: float, delta: float) -> float:
	return lerp_angle(start_rot, target_rot, _speed * delta)

func _on_navigation_agent_2d_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
	print("Velocity computed: ", safe_velocity)
	move_and_slide()

func _on_state_machine_state_changed(states_stack: Array) -> void:
	hud.state_label.text = (states_stack[0] as State).name

func _recalculate_path() -> void:
	if target_position != Vector2.ZERO:
		nav_agent.target_position = target_position

func set_target_position(new_position: Vector2) -> void:
	target_position = new_position
	nav_agent.target_position = new_position
	target_changed.emit(nav_agent.target_position)
