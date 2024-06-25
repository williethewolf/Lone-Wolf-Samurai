# SphereNode2D.gd
extends Node2D

var fill_amount: float = 0.0

func _draw():
	var parent = get_parent()
	var texture = parent.texture
	var size = Vector2(35, 35)  # Set the size manually if texture.get_size() is not giving desired results
	var radius = min(size.x, size.y) / 2
	var center = Vector2(radius, radius)
	var fill_radius = radius * fill_amount

	# Draw the filled portion of the circle
	draw_circle(center, fill_radius, modulate)

func update_fill(amount: float):
	fill_amount = amount
	queue_redraw()

func _ready():
	update_fill(0.0)
