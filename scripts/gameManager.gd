extends Node2D

@onready var player1 = $Player1
@onready var camera1 = $Player1/character/Camera2D
@onready var player2 =  get_node_or_null("Player2")
@onready var camera2 = get_node_or_null("Player2/character/Camera2D")
@onready var twoPlayerCamera = get_node_or_null("twoPlayerCamera")

func _ready():
	if player1 and camera1:
		camera1.make_current()
	elif player1 and player2:
		pass
	elif player2 == null:
		print("No player 2. Single player game")
