extends CharacterBody2D

# Define the Character class
class_name Character

# Player properties
@export var life: int = 100
@export var stamina: int = 4
var stance = ["Top", "Mid", "Low"]
var current_stance = "Mid"
@export var player_name: String = "player1"
@export var weapon: String = "katana"
@export var speed: float = 300.0  # Adjusted speed
@export var player_height: float = 175.0  # Player height in centimeters (1.75 meters)
@export var stance_penalty_duration: float = 0.5  # Penalty duration in seconds
@export var stanceChangeCooldown: float = 0.2  # Cooldown for changing stances

# Constants for movement and controls
const LEFT = Vector2(-1, 0)
const RIGHT = Vector2(1, 0)

# Jump properties
@export var jump_height: float = 200.0  # Jump height in pixels
@export var gravity: float = 2500.0  # Increased gravity strength
@export var jump_speed: float = -1000.0  # Increased initial jump speed (more negative to move up faster)
var floor_y_position: float = 10

# Movement variables
var direction = Vector2.ZERO
var facing = RIGHT

# Dash variables
var is_dashing = false
@export var dash_speed: float = 1200.0  # Adjusted dash speed
var dash_duration = 0.2
var dash_timer = 0

# Jump variables
var is_jumping = false

# Unseath variables
var sword_sheathed = true

# Double-tap detection
var last_tap_time_left = 0
var last_tap_time_right = 0
var double_tap_interval = 0.3

# Attack in progress flag
var is_attacking = false
var next_stance = ""
var stance_button_held = false
var is_midSwing_complete = false

# Reference to the AnimatedSprite2D nodes
@onready var legs_sprite = $AnimatedSprite2DLegs
@onready var torso_sprite = $AnimatedSprite2DTorso

# Current animation state
var current_torso_animation = ""

# Cooldown timers
var attack_cooldown = false
var stance_change_cooldown = false

# Animation lengths (assuming these values are correct, adjust if necessary)
var animation_lengths = {
	"Top": 0.18,  # Top attack animation length
	"Mid": 0.15,  # Mid attack animation length
	"Low": 0.18,  # Low attack animation length
}

# Time tracking
var attack_start_time = 0.0

#for camera help
signal grounded_updated (is_jumping)
#this passes the transform to the parent so the camera can be there.
signal transform_changed(new_transform)

func _ready():
	set_process(true)
	legs_sprite.play("idle_legs")
	update_torso_animation()
	legs_sprite.connect("animation_finished", Callable(self, "_on_AnimationFinished"))
	torso_sprite.connect("animation_finished", Callable(self, "_on_AnimationFinished"))

func _physics_process(delta):
	apply_gravity(delta)
	velocity.x = direction.x * speed
	move_and_slide()  # Move and slide the character based on velocity
	
	if is_jumping:
		handle_jump(delta)
	
	update_animation()  # Ensure this is called every frame

	# Check if player is falling and close to the floor
	if is_jumping and velocity.y > 0 and is_close_to_floor():
		legs_sprite.play("jump_down")  # Play the second half of the jump animation

func apply_gravity(delta):
	if not is_on_floor():
		velocity.y += gravity * delta

func dash():
	is_dashing = true
	dash_timer = dash_duration
	velocity.x = facing.x * dash_speed
	legs_sprite.play("dash")

func jump():
	is_jumping = true
	velocity.y = jump_speed  # Set the initial jump speed
	legs_sprite.play("jump_up")  # Play the first half of the jump animation
	emit_signal("grounded_updated", is_jumping)

func is_close_to_floor() -> bool:
	return position.y + 10 >= floor_y_position  # Adjust this threshold as needed

func handle_jump(delta):
	if is_on_floor():
		is_jumping = false
		velocity.y = 0
		legs_sprite.play("idle_legs")  # Ensure legs go back to idle after landing
		emit_signal("grounded_updated", is_jumping)

func _on_AnimationFinished():
	if is_attacking and (torso_sprite.animation == "attack1" or torso_sprite.animation == "attack2" or torso_sprite.animation == "attack3"):
		is_attacking = false
		# Change the stance only after the attack animation finishes
		if next_stance != "":
			current_stance = next_stance
			next_stance = ""
		update_torso_animation()
	elif legs_sprite.animation == "jump":
		is_jumping = false
		update_leg_animation()
	current_torso_animation = ""

func handle_stance_change():
	if stance_change_cooldown:
		return  # Prevent stance change during cooldown
	
	stance_button_held = false
	
	if Input.is_action_pressed("stance_top"):
		stance_button_held = true
		if current_stance != "Top":
			change_stance("Top")
	elif Input.is_action_pressed("stance_low"):
		stance_button_held = true
		if current_stance != "Low":
			change_stance("Low")
	elif Input.is_action_pressed("ui_right") and facing == RIGHT:
		stance_button_held = true
		if current_stance != "Mid":
			change_stance("Mid")
	elif Input.is_action_pressed("ui_left") and facing == LEFT:
		stance_button_held = true
		if current_stance != "Mid":
			change_stance("Mid")

	if not is_attacking:
		update_torso_animation()

func handle_attacks():
	if attack_cooldown:
		return  # Prevent attacks during cooldown
	
	if Input.is_action_just_pressed("attack_top"):
		perform_attack("Top")
	elif Input.is_action_just_pressed("attack_mid"):
		perform_attack("Mid")
	elif Input.is_action_just_pressed("attack_low"):
		perform_attack("Low")

func perform_attack(attack_stance) -> void:
	if is_attacking:
		return  # Prevent starting a new attack if already attacking

	is_attacking = true  # Set attacking flag to true
	attack_start_time = Time.get_ticks_msec() / 1000.0
	unseathe_sword()
	var penalty_duration = stance_penalty_duration
	if current_stance != attack_stance || stance_button_held:
		if attack_stance == "Mid":
			penalty_duration *= 0.5  # Reduce penalty by 50% for mid stance
		next_stance = attack_stance
		torso_sprite.play("stance" + attack_stance)
		stance_change_cooldown = true  # Start stance change cooldown
		await get_tree().create_timer(penalty_duration).timeout
		stance_change_cooldown = false  # End stance change cooldown
	
	# Start attack cooldown
	attack_cooldown = true
	if attack_stance == "Top":
		next_stance = "Low"
		torso_sprite.play("attack1")
	elif attack_stance == "Mid":
		if is_midSwing_complete:
			torso_sprite.play("attack22")
			is_midSwing_complete = false
		else:
			torso_sprite.play("attack2")
			is_midSwing_complete = true
		next_stance = "Mid"
	elif attack_stance == "Low":
		next_stance = "Top"
		torso_sprite.play("attack3")

	# Wait for the duration of the animation before allowing another attack
	var attack_duration = animation_lengths[attack_stance]
	await get_tree().create_timer(attack_duration).timeout
	attack_cooldown = false  # End attack cooldown
	is_attacking = false  # Ensure is_attacking flag is reset after the cooldown
	update_torso_animation()

func change_stance(new_stance: String):
	if current_stance == new_stance and current_stance != "Mid":
		return  # Prevent stance change if it's the same as the current stance (except for Mid)
	current_stance = new_stance
	unseathe_sword()
	is_midSwing_complete= false
	if is_attacking:
		torso_sprite.stop()
		is_attacking = false
	stance_change_cooldown = true  # Start stance change cooldown
	await get_tree().create_timer(stanceChangeCooldown).timeout
	stance_change_cooldown = false  # End stance change cooldown
	update_torso_animation()

func unseathe_sword():
	if sword_sheathed:
		sword_sheathed = false
	update_torso_animation()

func update_torso_animation():
	if not is_attacking:
		var new_animation = ""
		if current_stance == "Mid":
			if is_midSwing_complete:
				new_animation = "stanceMid2"
			else:
				new_animation = "stanceMid"
		elif current_stance == "Top":
			new_animation = "stanceTop"
		elif current_stance == "Low":
			new_animation = "stanceLow"

		# Only update animation if it's different from the current one
		if new_animation != current_torso_animation:
			current_torso_animation = new_animation
			torso_sprite.play(new_animation)

func update_animation():
	if is_jumping:
		# Ensure the correct part of the jump animation is playing
		if velocity.y < 0:
			legs_sprite.play("jump_up")
		elif velocity.y > 0 and is_close_to_floor():
			legs_sprite.play("jump_down")
	elif is_dashing:
		legs_sprite.play("dash")
	elif direction != Vector2.ZERO and is_on_floor():
		if (facing == LEFT and direction == RIGHT) or (facing == RIGHT and direction == LEFT):
			legs_sprite.speed_scale = -1  # Play animation in reverse
		else:
			legs_sprite.speed_scale = 1  # Play animation normally
		legs_sprite.play("walk")
	else:
		update_leg_animation()

	if not is_attacking:
		update_torso_animation()

func update_leg_animation():
	if is_jumping:
		legs_sprite.play("jump_up")
	elif direction == Vector2.ZERO:
		legs_sprite.play("idle_legs")  # Ensure legs go back to idle when not moving
	else:
		if (facing == LEFT and direction == RIGHT) or (facing == RIGHT and direction == LEFT):
			legs_sprite.speed_scale = -1  # Play animation in reverse
		else:
			legs_sprite.speed_scale = 1  # Play animation normally
		legs_sprite.play("walk")

func print_debug(message: String):
	print(message)

# Additional function to debug the is_midSwing_complete state
func _process(delta):
	#print("is_jumping:", is_jumping)
	pass

func _on_grounded_updated(is_jumping):
	pass # Replace with function body.
