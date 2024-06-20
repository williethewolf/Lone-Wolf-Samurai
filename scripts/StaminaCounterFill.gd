extends Node2D

var fill_amount: float = 0.0

func _draw():
	var parent = get_parent()
	var texture = parent.texture
	var size = texture.get_size()
	var radius = min(size.x, size.y) / 2
	var fill_height = radius * 2 * fill_amount
	var offset = radius * 2 - fill_height
	
	# Draw the filled portion
	draw_rect(Rect2(Vector2(0, offset), Vector2(radius * 2, fill_height)), Color(1, 1, 1, 0.4 + 0.6 * fill_amount))

func update_fill(amount: float):
	fill_amount = amount
	queue_redraw()

func _ready():
	update_fill(0.0)
