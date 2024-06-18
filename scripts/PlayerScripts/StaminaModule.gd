extends Node

# Stamina properties
@export var max_stamina: int = 100
@export var stamina_regen_rate: float = 10.0  # Stamina points regenerated per second

var current_stamina: int
var is_exhausted: bool = false

# Signals
signal stamina_changed(current_stamina: int)
signal stamina_exhausted()

func _ready():
	current_stamina = max_stamina

func deplete_stamina(amount: int):
	current_stamina = max(current_stamina - amount, 0)
	emit_signal("stamina_changed", current_stamina)
	if current_stamina == 0:
		is_exhausted = true
		emit_signal("stamina_exhausted")

func regenerate_stamina(delta: float):
	if current_stamina < max_stamina and not is_exhausted:
		current_stamina = min(current_stamina + stamina_regen_rate * delta, max_stamina)
		emit_signal("stamina_changed", current_stamina)

func reset_exhaustion():
	is_exhausted = false

