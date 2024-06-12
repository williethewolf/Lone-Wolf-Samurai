extends Camera2D

# Variables for smoothing
var target_offset_y = -150.0
var offset_smoothing_speed = 3.50  # Adjust this value to control the smoothing speed
var is_jumping_state = false  # Variable to track the jumping state

# This function is called when the node enters the scene tree for the first time.
func _ready():
	pass

func _process(delta):
	# Smoothly interpolate towards the target offset
	if not is_jumping_state:  # Only update the offset if not jumping
		offset.y = lerp(offset.y, target_offset_y, offset_smoothing_speed * delta)

# This function is called when the grounded_updated signal is emitted.
func _on_grounded_updated(jumping_state):
	drag_vertical_enabled = jumping_state
	is_jumping_state = jumping_state  # Update the jumping state
	print("is_jumping:", is_jumping_state)
	print("drag_vertical_enabled:", drag_vertical_enabled)

# For debugging
func print_debug(message: String):
	print(message)
	
func _update_camera_offset(distance_to_floorline):
	
		# Initial and final offset values
		var initial_offset_y = -270.0
		var final_offset_y = 100.0
		var max_distance = 400.0
		
		# Clamp the distance to be between 0 and max_distance
		var clamped_distance = clamp(float(distance_to_floorline), 100.0, max_distance)
		
		# Calculate the interpolation factor with easing
		var t = clamped_distance / max_distance
		
		# Interpolate between the initial and final offset values
		var new_offset_y = lerp(initial_offset_y, final_offset_y, t)
		
		# Set the new offset for the camera
		target_offset_y = new_offset_y

# Linear interpolation function
func lerp(a, b, t):
	return a + (b - a) * t

# This function handles the distance to floorline updates
func _on_distance_to_floor(distance_to_floorline):
	_update_camera_offset(distance_to_floorline)
