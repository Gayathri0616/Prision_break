extends Node2D

@export var damage := 50
@export var range := 200.0
@export var fire_rate := 1.0  # Shots per second
@export var cost := 500  # Cost in Global.money

@onready var sprite := $Sprite2D as Sprite2D
@onready var ray_cast := $RayCast2D as RayCast2D
@onready var fire_timer := $FireTimer as Timer

var target: Node2D = null

func _ready() -> void:
	fire_timer.wait_time = 1.0 / fire_rate
	fire_timer.connect("timeout", _on_fire_timer_timeout)
	ray_cast.target_position = Vector2(range, 0)

func _process(delta: float) -> void:
	if target and is_instance_valid(target):
		look_at(target.global_position)
		ray_cast.force_raycast_update()
		if ray_cast.is_colliding() and ray_cast.get_collider() == target:
			_shoot()
	else:
		_find_target()

func _find_target() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if global_position.distance_to(enemy.global_position) <= range:
			target = enemy
			break
	if not target:
		ray_cast.enabled = false

func _shoot() -> void:
	ray_cast.enabled = true
	if target and is_instance_valid(target):
		target.take_damage(damage)  # Assumes enemies have a take_damage method

func _on_fire_timer_timeout() -> void:
	if target and is_instance_valid(target):
		_shoot()

func take_damage(amount: int) -> void:
	# Optional: Handle turret destruction if damaged by enemies
	pass
