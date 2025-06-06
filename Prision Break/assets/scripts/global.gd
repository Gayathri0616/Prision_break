extends Node

# Game state variables
var is_gameover := false
var turret_actions: Control = null  # Ensures only one turret UI is visible
var money: int = 5000  # Starting money
var turret_prices := {
	"gatling": 250,
	"single": 400,
	"missile": 800,
	"tesla": 500  # Added post-beta TeslaTurret price
}

# Post-beta additions
var final_door_position := Vector2.ZERO  # Dynamically set by Map.gd
var scout_enemy_speed := 350  # Speed for ScoutEnemy (pixels/second)

# Static utility function
static func wrap_index(index: int, size: int) -> int:
	return ((index % size) + size) % size

# Function to update money, with clamping
func set_money(value: int) -> void:
	money = max(0, value)
	# Optional: Emit signal for HUD update
	# e.g., signal money_changed(new_value)

# Function to check if a turret can be purchased
func can_afford(turret_type: String) -> bool:
	return turret_prices.get(turret_type, 0) <= money

# Initialize the singleton
func _ready() -> void:
	if not is_inside_tree():  # Ensure this runs only once
		set_multiplayer_authority(str(get_instance_id()).hash())
