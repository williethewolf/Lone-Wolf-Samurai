extends Control

@export var stamina_module_path: NodePath = NodePath("../../character/StaminaModule")

var stamina_spheres = []
var stamina_module

# Signals
signal stamina_changed(current_stamina: int)
signal stamina_exhausted()

func _ready():
	stamina_spheres = [
		$Circle0/Node2D,
		$Circle1/Node2D,
		$Circle2/Node2D,
		$Circle3/Node2D,
		$Circle4/Node2D,
		$Circle5/Node2D
	]
	stamina_spheres.reverse()  # Reverse the array
	stamina_module = get_node(stamina_module_path) as Node
	if stamina_module:
		stamina_module.connect("stamina_changed", Callable(self, "_on_stamina_changed"))
		stamina_module.connect("stamina_exhausted", Callable(self, "_on_stamina_exhausted"))
		_on_stamina_changed(stamina_module.current_stamina)  # Initialize the visual state

func _on_stamina_changed(current_stamina: int):
	update_stamina_visual(current_stamina)

func _on_stamina_exhausted():
	# Handle exhaustion visual feedback if needed
	pass

func update_stamina_visual(current_stamina: int):
	var stamina_per_circle = stamina_module.get("max_stamina") / stamina_spheres.size()
	for i in range(stamina_spheres.size()):
		var sphere = stamina_spheres[i]
		var fill_amount = (current_stamina - i * stamina_per_circle) / stamina_per_circle
		fill_amount = clamp(fill_amount, 0.0, 1.0)
		sphere.call("update_fill", fill_amount)
		if fill_amount >= 1.0:
			sphere.modulate.a = 1.0  # Full opacity
		else:
			sphere.modulate.a = 0.4  # Low opacity
