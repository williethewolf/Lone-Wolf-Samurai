extends Node2D

@export var character_path: NodePath = NodePath("../character")  # Path to the character node
@export var remote_transform_name: String = "StaminaAnchorRemoteTransform2D"  # Name of the RemoteTransform2D node

func _ready()  -> void:
	var character : Character = get_node_or_null(character_path) as Character
	if character:
		var anchor : Node2D = character.get_node("AnimatedSprite2DTorso/AnchorPoint")
		if anchor:
			var remote_transform : RemoteTransform2D = anchor.get_node_or_null(remote_transform_name)
			if remote_transform:
				remote_transform.remote_path = get_path()
				print("RemoteTransform2D Path set to: ",remote_transform.remote_path)
			else:
				print("RemoteTransform2D node not found")
		else:
			print("AnchorPoint node not found")
	else:
		print("Character node not found")
