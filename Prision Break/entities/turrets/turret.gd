class_name Turret
extends CharacterBody2D

signal turret_disabled

const FADE_OUT_DURATION := 0.25
const MOVE_STEP := 32.0  # 2 steps total patrol distance (32 units each way)
const MOVE_SPEED := 200.0  # Increased for testing

@export_range(1, 500) var health: int = 100:
	set = set_health

var type: String:
	get: return String(name).trim_suffix("Turret").to_lower()

@onready var collision := $CollisionShape2D as CollisionShape2D
@onready var shooter := $Shooter as Shooter
@onready var explosion := $Explosion as AnimatedSprite2D
@onready var hud := $UI/EntityHUD as EntityHud
@onready var sprite := $Basement/Move as AnimatedSprite2D  # Matches renamed node
@onready var basement := $Basement as Node2D  # Reference to the Basement node

var move_direction := 1.0
var base_position := Vector2.ZERO
var patrol_distance := MOVE_STEP * 2  # Total patrol range of 2 steps
var selected := false  # Track turret selection

func _ready() -> void:
	base_position = global_position
	print("Base position set to: ", base_position)
	if sprite and sprite.sprite_frames.has_animation("move"):
		sprite.play("move")
	if basement:
		basement.visible = true
		print("Basement node found at: ", basement.get_path(), " initial visibility: ", basement.visible, " is class: ", basement.get_class())
	else:
		print("Error: Basement node not found at path $Basement! Check scene hierarchy.")
	hud.state_label.hide()
	hud.healthbar.max_value = health
	hud.healthbar.value = health

func _physics_process(delta: float) -> void:
	if sprite and sprite.sprite_frames.has_animation("move"):
		sprite.play("move")
	if shooter.targets and shooter.can_shoot and shooter.lookahead.is_colliding():
		shooter.shoot()
	move_turret(delta)
	if velocity.length() > 0:
		move_and_slide()
		print("Moved to: ", global_position)
	else:
		print("Velocity is zero, no movement")
	# Removed basement visibility toggling here to prevent awkward flashing

func move_turret(delta: float) -> void:
	print("Attempting to move turret")
	var move_amount := MOVE_SPEED * delta * move_direction
	velocity = Vector2(move_amount, 0.0)
	print("Setting velocity: ", velocity)
	var current_offset := global_position.x - base_position.x
	if abs(current_offset) >= patrol_distance:
		move_direction *= -1.0
		print("Reversed direction to: ", move_direction)
		if sprite and sprite.sprite_frames.has_animation("move"):
			sprite.play("move")

func set_selected(value: bool) -> void:
	selected = value
	if basement:
		basement.visible = not value  # Hide basement when selected, show when deselected
	print("Turret selection changed to: ", selected, " Basement visible: ", basement.visible)

func remove() -> void:
	var health_perc: float = hud.healthbar.value / hud.healthbar.max_value
	var money_returned := int(Global.turret_prices[type] * health_perc / 2)
	Global.money += money_returned
	queue_free()

func repair() -> bool:
	var missing_health_perc: float = 1.0 - (hud.healthbar.value / hud.healthbar.max_value)
	var money_needed := int(Global.turret_prices[type] * missing_health_perc)
	var can_repair := Global.money >= money_needed
	if can_repair:
		Global.money -= money_needed
		health = int(hud.healthbar.max_value)
	return can_repair

func set_health(value: int) -> void:
	health = max(0, value)
	if is_instance_valid(hud):
		hud.healthbar.value = health
	if health == 0:
		collision.set_deferred("disabled", true)
		shooter.explode()
		explosion.play("default")
		turret_disabled.emit()

func _on_gun_animation_finished() -> void:
	if shooter.gun.animation == "explode":
		var tween := get_tree().create_tween()
		tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_DURATION)
		tween.finished.connect(_on_tween_finished)

func _on_tween_finished() -> void:
	queue_free()

func _on_detector_body_entered(body: Node2D) -> void:
	if not body in shooter.targets:
		shooter.targets.append(body)

func _on_detector_body_exited(body: Node2D) -> void:
	if body in shooter.targets:
		shooter.targets.erase(body)

func _on_shooter_has_shot(reload_time: float) -> void:
	hud.update_reloadbar(reload_time)
