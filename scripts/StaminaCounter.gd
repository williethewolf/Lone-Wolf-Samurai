extends Control

@export var stamina_module_path: NodePath = NodePath("../../character/StaminaModule")
@export var player_path: NodePath = NodePath("../../character")

var stamina_spheres = []
var stamina_module
var player
var tween

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
	player = get_node(player_path) as Node

	if stamina_module:
		stamina_module.connect("stamina_changed", Callable(self, "_on_stamina_changed"))
		stamina_module.connect("stamina_exhausted", Callable(self, "_on_stamina_exhausted"))
		_on_stamina_changed(stamina_module.current_stamina)  # Initialize the visual state

	if player:
		player.connect("tree_exited", Callable(self, "_on_player_eliminated"))

	modulate.a = 0.0  # Start with the counter hidden

func _on_stamina_changed(current_stamina: int):
	update_stamina_visual(current_stamina)
	if current_stamina == stamina_module.max_stamina:
		hide_counter()
	else:
		show_counter()

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

func hide_counter():
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)

func show_counter():
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)

func _on_player_eliminated():
	hide_counter()
