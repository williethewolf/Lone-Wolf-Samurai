extends Camera2D

@export var move_speed = 30
@export var zoom_speed = 3.0
@export var min_zoom = 5.0
@export var max_zoom = 0.5
@export var margin = Vector2(400,200)

@onready var targets = get_tree().get_nodes_in_group("Players")


@onready var screen_size = get_viewport_rect().size

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if !targets:
		return
	#center camera betwen targets
	var p = Vector2.ZERO
	for target in targets:
		p += target.get_node("character").position
	p /= targets.size()
	position = lerp(position, p, move_speed)
	
	#find the zoom level fitting all target/players
	var r = Rect2(position, Vector2.ONE)
	for target in targets:
		r = r.expand(target.position)
	r = r.grow_individual(margin.x, margin.y, margin.x, margin.y)
	var z
	if r.size.x > r.size.y * screen_size.aspect():
		z = 1 / clamp(r.size.x / screen_size.x, min_zoom, max_zoom)
	else:
		z = 1 / clamp(r.size.y / screen_size.y, min_zoom, max_zoom)
	zoom = lerp(zoom, Vector2.ONE * z, zoom_speed)


#func add_target(t):
	#if not t in targets:
		#targets.append(t)
		#
#func remove_target(t):
	#if t in targets:
		#targets.remove(t)
