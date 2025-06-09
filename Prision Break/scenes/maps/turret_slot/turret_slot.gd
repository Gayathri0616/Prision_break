extends Area2D

var turret: Turret  # Turret assigned to this slot

@onready var projectile_container := $ProjectileContainer as Node
@onready var turret_popup := $UI/TurretPopup as CanvasLayer
@onready var turret_actions := $UI/TurretActions as VBoxContainer
@onready var turret_sprite := $Sprite2D as AnimatedSprite2D
# Base idle sprite

func _ready() -> void:
	if turret_sprite:
		turret_sprite.play("idle")  # Default animation
	if turret_popup:
		turret_popup.connect("turret_requested", _on_turret_popup_turret_requested)
	
func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_instance_valid(turret):
			turret_actions.visible = not turret_actions.visible
		else:
			turret_popup.show()

func _on_turret_replace_requested() -> void:
	turret_actions.hide()
	if is_instance_valid(turret):
		turret.remove()
	turret_popup.show()
	if turret_sprite:
		turret_sprite.play("idle")  # Reset to idle

func _on_turret_repair_requested() -> void:
	if is_instance_valid(turret) and turret.repair():
		turret_actions.hide()
		if turret_sprite:
			turret_sprite.play("idle")
	else:
		var repair_btn := get_node("UI/TurretActions/Repair") as Button
		if is_instance_valid(repair_btn):
			var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(repair_btn, "modulate", Color("fff"), 0.25).from(Color("ff383f"))
		if turret_sprite:
			turret_sprite.play("damaged")

func _on_turret_remove_requested() -> void:
	turret_actions.hide()
	if is_instance_valid(turret):
		turret.remove()
	if turret_sprite:
		turret_sprite.play("idle")

func _on_turret_popup_turret_requested(type: String) -> void:
	if Global.can_afford(type):
		Global.set_money(Global.money - Global.turret_prices[type])
		turret = load(Scenes.get_turret_path(type)).instantiate()
		add_child(turret, true)
		print("Turret instantiated: ", turret.name, " at path: ", turret.get_path())
		if turret:
			turret.shooter.projectile_instanced.connect(_on_turret_projectile_instanced)
			turret.turret_disabled.connect(_on_turret_disabled)
			turret.set_selected(true)  # Hide basement on turret spawn
		turret_popup.hide()
		if turret_sprite:
			turret_sprite.visible = false  # Hide base idle sprite since turret is active

func _on_turret_selected(type: String) -> void:
	if is_instance_valid(turret):
		turret.set_selected(true)
		print("Turret selected via signal: ", turret.name)

func _on_turret_projectile_instanced(projectile: Projectile) -> void:
	projectile_container.add_child(projectile, true)
	if turret_sprite:
		turret_sprite.play("firing")

func _on_turret_disabled() -> void:
	turret_actions.hide()
	if is_instance_valid(turret):
		turret.set_selected(false)  # Show basement again
	turret = null
	if turret_sprite:
		turret_sprite.visible = true  # Show base idle sprite again
		turret_sprite.play("idle")

func _on_turret_popup_visibility_changed() -> void:
	if turret_popup.visible:
		turret_actions.hide()
	elif not turret_popup.visible and is_instance_valid(turret):
		pass

func _on_turret_actions_visibility_changed() -> void:
	if turret_actions.visible:
		turret_popup.hide()
		Global.turret_actions = turret_actions
	else:
		Global.turret_actions = null
