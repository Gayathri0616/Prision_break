class_name Turret
extends CharacterBody2D

signal turret_disabled

const FADE_OUT_DURATION := 0.25
const MOVE_STEP := 32.0  # 2 steps total patrol distance (32 units each way)
const MOVE_SPEED := 200.0  # Speed for testing

@export_range(1, 500) var health: int = 100:
	set = set_health

var type: String:
	get: return String(name).trim_suffix("Turret").to_lower()

@onready var collision := $CollisionShape2D as CollisionShape2D
@onready var shooter := $Shooter as Shooter
@onready var explosion := $Explosion as AnimatedSprite2D
@onready var hud := $UI/EntityHUD as EntityHud
@onready var sprite := $Basement/Move as AnimatedSprite2D  # Animation node
@onready var basement := $Basement as Node2D  # Basement node (base idle)
@onready var status_label := $UI/StatusLabel as Label if has_node("UI/StatusLabel") else null  # Optional label

var move_direction := 1.0
var base_position := Vector2.ZERO
var patrol_distance := MOVE_STEP * 2  # Total patrol range of 64 units
var selected := false  # Track turret selection
var is_moving := false  # Track if animation should play
var instance_id := str(get_instance_id())  # Unique ID for debugging

func _ready() -> void:
	base_position = global_position
	print("Turret ", instance_id, " initialized at ", global_position)
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("move"):
		is_moving = true
		sprite.play("move")
	else:
		print("Error: Move animation not found or sprite node invalid at path $Basement/Move for turret ", instance_id)
	if basement:
		basement.visible = true
		print("Turret ", instance_id, " basement visible: ", basement.visible)
	else:
		print("Error: Basement node not found at path $Basement! for turret ", instance_id)
	if status_label:
		print("Turret ", instance_id, " status label found at: ", status_label.get_path())
	hud.state_label.hide()
	hud.healthbar.max_value = health
	hud.healthbar.value = health
	if not is_connected("input_event", _on_input_event):
		var error = connect("input_event", _on_input_event)
		if error == OK:
			print("Turret ", instance_id, " input event signal connected successfully")
		else:
			print("Turret ", instance_id, " failed to connect input event signal, error code: ", error)

func _physics_process(delta: float) -> void:
	if sprite and is_moving and not sprite.is_playing():
		sprite.play("move")
	if shooter.targets and shooter.can_shoot and shooter.lookahead.is_colliding():
		shooter.shoot()
	move_turret(delta)
	if velocity.length() > 0:
		move_and_slide()
	else:
		print("Turret ", instance_id, " velocity is zero, no movement")

func move_turret(delta: float) -> void:
	var move_amount := MOVE_SPEED * delta * move_direction
	velocity = Vector2(move_amount, 0.0)
	var current_offset := global_position.x - base_position.x
	if abs(current_offset) >= patrol_distance:
		move_direction *= -1.0
		if sprite and is_moving:
			sprite.play("move")

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected = !selected
		set_selected(selected)
		print("Turret ", instance_id, " input event: clicked, selected: ", selected, " Basement visible: ", basement.visible if basement else "N/A")

func _on_turret_popup_requested(_type: String) -> void:
	print("Turret ", instance_id, " received turret_popup_requested signal, current selected: ", selected)
	if not selected:
		set_selected(true)
		print("Turret ", instance_id, " set_selected(true) called from popup, Basement visible: ", basement.visible if basement else "N/A")
	else:
		print("Turret ", instance_id, " already selected, skipping set_selected in popup request")

func set_selected(value: bool) -> void:
	selected = value
	print("Turret ", instance_id, " set_selected to ", value)
	if basement:
		basement.visible = not value
		for child in basement.get_children():
			if child is CanvasItem:
				child.visible = not value
				print("Turret ", instance_id, " child ", child.name, " visibility set to: ", child.visible)
	if status_label:
		status_label.visible = not value
		print("Turret ", instance_id, " status label visibility set to: ", status_label.visible)

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
