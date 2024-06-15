extends Camera2D

# Variables for smoothing
var target_offset_y = -75.0
var offset_smoothing_speed = 3.50  # Adjust this value to control the smoothing speed
var is_jumping_state = false  # Variable to track the jumping state
var initial_offset_y = -270.0  # Set this to the desired initial offset

# This function is called when the node enters the scene tree for the first time.
func _ready():
	initial_offset_y = offset.y
	#print("Camera", name, "initialized with target_offset_y:", target_offset_y)

func _process(delta):
	# Smoothly interpolate towards the target offset
	if not is_jumping_state:  # Only update the offset if not jumping
		offset.y = lerp(offset.y, target_offset_y, offset_smoothing_speed * delta)
		#print("Camera", name, "lerp to target_offset_y:", target_offset_y, "current offset.y:", offset.y)

# This function is called when the grounded_updated signal is emitted.
func _on_grounded_updated(jumping_state):
	is_jumping_state = jumping_state  # Update the jumping state
	if not jumping_state:
		pass
		# Reset target offset to initial when not jumping
		#target_offset_y = initial_offset_y
	#print("Camera", name, "is_jumping:", is_jumping_state)
	#print("Camera", name, "drag_vertical_enabled:", drag_vertical_enabled)

# For debugging
func print_debug(message: String):
	print(message)
	
func _update_camera_offset(distance_to_floorline):
	## Initial and final offset values
	#var final_offset_y = 100.0
	#var max_distance = 600.0
	#
	## Clamp the distance to be between 0 and max_distance
	#var clamped_distance = clamp(float(distance_to_floorline), 0.0, max_distance)
	#
	## Calculate the interpolation factor with easing
	#var t = clamped_distance / max_distance
	#
	## Interpolate between the initial and final offset values
	#var new_offset_y = lerp(initial_offset_y, final_offset_y, t)
	#
	## Clamp the new offset to not go below the initial offset when on the ground or falling
	#if distance_to_floorline <= 0:
		#new_offset_y = initial_offset_y
	#
	## Set the new offset for the camera if jumping
	#if is_jumping_state:
		#target_offset_y = new_offset_y
	##print("Camera", name, "distance_to_floorline:", distance_to_floorline, "new_target_offset_y:", target_offset_y)
	pass

# Linear interpolation function
func lerp(a, b, t):
	return a + (b - a) * t

# This function handles the distance to floorline updates
func _on_distance_to_floor(_distance_to_floorline):
	#disabled until I can figure out how to make it smooth and work fine with the two player camera
	#_update_camera_offset(distance_to_floorline)
	pass
