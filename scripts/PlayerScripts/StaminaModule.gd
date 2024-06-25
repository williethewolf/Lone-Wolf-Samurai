extends Node

# Stamina properties
@export var max_stamina: float = 120.0
@export var stamina_regen_rate_moving: float = 10.0  # Stamina points regenerated per second while moving
@export var stamina_regen_rate_still: float = 20.0  # Stamina points regenerated per second while still
@export var exhaustion_threshold: float = 0.5  # Threshold for removing exhaustion state
@export var stamina_regen_rate_exhausted_modifier: float = 0.75  # Modifier for regeneration rate when exhausted

var current_stamina: float
var is_exhausted: bool = false
var is_moving: bool = false
var is_attacking: bool = false

# Signals
signal stamina_changed(current_stamina: int)
signal stamina_exhausted()
signal exhausted_changed(is_exhausted: bool)

@onready var movement_module = get_parent().get_node("MovementModule")

func _ready():
	current_stamina = max_stamina
	

func deplete_stamina(amount: int):
	current_stamina = max(current_stamina - amount, 0)
	if current_stamina <= 0:
		is_exhausted = true
		emit_signal("exhausted_changed", true)
		emit_signal("stamina_exhausted")
	emit_signal("stamina_changed", current_stamina)

func regenerate_stamina(delta: float):
	if current_stamina < max_stamina and not is_attacking and not movement_module.is_running:
		var regen_rate = stamina_regen_rate_still if not is_moving else stamina_regen_rate_moving
		if is_exhausted:
			regen_rate *= stamina_regen_rate_exhausted_modifier
		
		# Apply regeneration
		current_stamina = min(current_stamina + regen_rate * delta, max_stamina)
		
		# Reset exhaustion if stamina is above 50%
		if is_exhausted and current_stamina >= max_stamina * exhaustion_threshold:
			is_exhausted = false
			emit_signal("exhausted_changed", false)

		emit_signal("stamina_changed", int(current_stamina))
	

func reset_exhaustion():
	is_exhausted = false

func set_moving(moving: bool):
	is_moving = moving

func set_attacking(attacking: bool):
	is_attacking = attacking
	
func _on_stamina_exhausted():
	emit_signal("exhausted_changed", true)
