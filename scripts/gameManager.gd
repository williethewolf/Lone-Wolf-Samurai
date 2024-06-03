extends Node2D

@onready var player1 = $Player1
@onready var camera = $Player1/Camera2D

func _ready():
	if player1 and camera:
		camera.make_current()
