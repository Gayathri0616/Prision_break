extends Area2D

var turret: Turret  # Turret assigned to this slot

@onready var projectile_container := $ProjectileContainer as Node
@onready var turret_popup := $UI/TurretPopup as CanvasLayer
@onready var turret_actions := $UI/TurretActions as VBoxContainer
@onready var turret_sprite := get_node_or_null("Sprite2D") as AnimatedSprite2D
# Base idle sprite

func _ready() -> void:
	if turret_sprite:
		turret_sprite.play("idle")
		print("Turret sprite initial visibility: ", turret_sprite.visible, " at path: ", turret_sprite.get_path())
		# Hide turret_sprite when turret_popup is initialized, if no turret
		if not is_instance_valid(turret) and turret_popup:
			turret_sprite.visible = false
			print("Ready: Hid turret sprite due to no turret and turret_popup present, visibility: ", turret_sprite.visible)
	else:
		print("Warning: Turret sprite (Sprite2D) not found!")
	if turret_popup:
		turret_popup.connect("turret_requested", _on_turret_popup_turret_requested)
	
func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_instance_valid(turret):
			turret_actions.visible = not turret_actions.visible
			# Sync with turret's selected state
			if turret_actions.visible and not turret.selected:
				turret.set_selected(true)
			elif not turret_actions.visible and turret.selected:
				turret.set_selected(false)
			if turret_sprite:
				turret_sprite.visible = not turret.selected
				print("Input event: Turret actions toggled, turret selected: ", turret.selected, " base sprite visibility: ", turret_sprite.visible)
		else:
			turret_popup.show()
			if turret_sprite:
				turret_sprite.visible = false
				print("Input event: No turret, hid base sprite, visibility: ", turret_sprite.visible)

func _on_turret_popup_turret_requested(type: String) -> void:
	if is_instance_valid(turret):
		turret.remove()
	
	if Global.can_afford(type):
		Global.set_money(Global.money - Global.turret_prices[type])
		turret = load(Scenes.get_turret_path(type)).instantiate()
		add_child(turret, true)
		print("Turret instantiated: ", turret.name, " at path: ", turret.get_path())
		if turret:
			turret.shooter.projectile_instanced.connect(_on_turret_projectile_instanced)
			turret.turret_disabled.connect(_on_turret_disabled)
			# Correct connect syntax using Callable
			turret_popup.connect("turret_requested", turret._on_turret_popup_requested.bind())
			turret.set_selected(true)  # Hide basement and label
			if turret_sprite:
				turret_sprite.visible = false
				print("Turret placed, base sprite hidden: ", turret_sprite.visible)
		turret_popup.hide()

func _on_turret_selected(type: String) -> void:
	pass

func _on_turret_projectile_instanced(projectile: Projectile) -> void:
	projectile_container.add_child(projectile, true)
	if turret_sprite:
		turret_sprite.play("firing")

func _on_turret_disabled() -> void:
	turret_actions.hide()
	if is_instance_valid(turret):
		turret.set_selected(false)
	turret = null
	if turret_sprite:
		turret_sprite.visible = true
		turret_sprite.play("idle")
		print("Turret disabled, base sprite visible: ", turret_sprite.visible)

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
