# SphereNode2D.gd
extends Node2D

var fill_amount: float = 0.0

func _draw() -> void:
	#var parent = get_parent()
	#var texture = parent.texture #for now there's no texture so there it is.
	var size : Vector2 = Vector2(35, 35)  # Set the size manually if texture.get_size() is not giving desired results
	var radius : float = min(size.x, size.y) / 2
	var center : Vector2 = Vector2(radius, radius)
	var fill_radius : float = radius * fill_amount

	# Draw the filled portion of the circle
	draw_circle(center, fill_radius, modulate)

func update_fill(amount: float) -> void:
	fill_amount = amount
	queue_redraw()

func _ready() -> void:
	update_fill(0.0)
