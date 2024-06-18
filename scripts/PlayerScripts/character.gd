extends CharacterBody2D

# Define the Character class
class_name Character

# Player properties
@export var life: int = 100
@export var stamina: int = 100
var stance = ["Top", "Mid", "Low"]
var current_stance = "Mid"
@export var player_name: String = "player1"
@export var weapon: String = "katana"
@export var speed: float = 400.0  # Adjusted speed
@export var player_height: float = 175.0  # Player height in centimeters (1.75 meters)
@export var stance_penalty_duration: float = 0.5  # Penalty duration in seconds
@export var stanceChangeCooldown: float = 0.2  # Cooldown for changing stances
@export var damageRange = [90,200]

# Constants for movement and controls
const LEFT = Vector2(-1, 0)
const RIGHT = Vector2(1, 0)
#Multiplayer coop control variables
@export var controls: Resource = null

# Jump properties
@export var jump_height: float = 200.0  # Jump height in pixels
@export var min_jump_height: float = 50.0  # Minimum jump height in pixels
@export var gravity: float = 5500.0  # Increased gravity strength
@export var jump_speed: float = -1500.0  # Increased initial jump speed (more negative to move up faster)
@export var jump_duration: float = 0.3  # Duration to reach full jump height
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
var is_falling = false

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

#attack variables for signals to AI and impact logic
var current_attack_stance = ""
var is_attack_blocked = false
#signals
signal stance_changed(new_stance: String)
signal attack_stance_changed(new_attack_stance: String)

#Receiving damage flags
var is_taking_damage = false

# Reference to the AnimationPlayer nodes
@onready var animPlayer_legs = $LegsAnimationPlayer
@onready var animPlayer_torso = $TorsoAnimationPlayer

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
	"Mid": 0.18,  # Mid attack animation length
	"Low": 0.18,  # Low attack animation length
}

# Time tracking
var attack_start_time = 0.0

#for camera help
signal grounded_updated (is_jumping)
#this passes the transform to the parent so the camera can be there.
#signal transform_changed(new_transform)

func _ready():
	set_process(true)
	animPlayer_legs.play("idle_legs")
	update_torso_animation()
	animPlayer_legs.connect("animation_finished", Callable(self, "_on_legs_animation_player_animation_finished"))
	animPlayer_torso.connect("animation_finished", Callable(self, "_on_torso_animation_player_animation_finished"))


func _physics_process(delta):
	apply_gravity(delta)
	velocity.x = direction.x * speed
	move_and_slide()  # Move and slide the character based on velocity
	
	handle_jump(delta)  # Always handle jumping

	update_animation()  # This is called every frame to update animations



func apply_gravity(delta):
	if not is_on_floor():
		velocity.y += gravity * delta
	#print("Applying gravity: velocity.y =", velocity.y, "is_on_floor() =", is_on_floor())

func dash():
	is_dashing = true
	dash_timer = dash_duration
	velocity.x = facing.x * dash_speed
	animPlayer_legs.play("dash")

func jump():
	is_jumping = true
	velocity.y = jump_speed  # Set the initial jump speed
	animPlayer_legs.play("jump_up")  # Play the first half of the jump animation
	emit_signal("grounded_updated", is_jumping)

func is_close_to_floor() -> bool:
	return position.y + 75 >= floor_y_position  # Adjust this threshold as needed

func handle_jump(_delta):
	# Check if the character is on the floor
	if is_on_floor():
		#if is_jumping:  # Only change if it was previously jumping
			is_jumping = false
			#velocity.y = 0
			#animPlayer_legs.play("idle_legs")
			emit_signal("grounded_updated", is_jumping)
	else:
		#if not is_jumping:  # Only change if it was not previously jumping
		is_jumping = true
			#print("Jumping or falling: is_jumping:", is_jumping)


func handle_stance_change():
	if stance_change_cooldown:
		return  # Prevent stance change during cooldown
	
	stance_button_held = false
	
	if Input.is_action_pressed(controls.stance_top):
		stance_button_held = true
		if current_stance != "Top":
			change_stance("Top")
	elif Input.is_action_pressed(controls.stance_low):
		stance_button_held = true
		if current_stance != "Low":
			change_stance("Low")
	elif Input.is_action_pressed(controls.stance_mid) and facing == RIGHT:
		stance_button_held = true
		if current_stance != "Mid":
			change_stance("Mid")
	elif Input.is_action_pressed(controls.stance_midL) and facing == LEFT:
		stance_button_held = true
		if current_stance != "Mid":
			change_stance("Mid")

	if not is_attacking:
		update_torso_animation()

func handle_attacks():
	if attack_cooldown:
		return  # Prevent attacks during cooldown
	
	if Input.is_action_just_pressed(controls.attack_top):
		perform_attack("Top")
	elif Input.is_action_just_pressed(controls.attack_mid):
		perform_attack("Mid")
	elif Input.is_action_just_pressed(controls.attack_low):
		perform_attack("Low")

func perform_attack(attack_stance) -> void:
	if is_attacking:
		return  # Prevent starting a new attack if already attacking

	is_attacking = true  # Set attacking flag to true
	is_attack_blocked = false # Reset the attack blocked flag
	emit_signal("attack_stance_changed", attack_stance)  # Emit signal for attack stance change
	attack_start_time = Time.get_ticks_msec() / 1000.0
	unseathe_sword()
	var penalty_duration = stance_penalty_duration
	
	current_attack_stance = attack_stance # Set the global attack stance
	
	if current_stance == "Mid" and attack_stance == "Mid":
		penalty_duration *= 0.005  # Apply a small penalty duration for consecutive mid stance attacks to prevent spamming the animation.
		if is_midSwing_complete:
			animPlayer_torso.play("stanceMid2")
		else:
			animPlayer_torso.play("stanceMid")
		stance_change_cooldown = true  # Start stance change cooldown
		await get_tree().create_timer(penalty_duration).timeout
		stance_change_cooldown = false 
	elif current_stance != attack_stance or stance_button_held:
		if attack_stance == "Mid":
			penalty_duration *= 0.5  # Reduce penalty by 50% for mid stance
		next_stance = attack_stance
		animPlayer_torso.play("stance" + attack_stance)
		stance_change_cooldown = true  # Start stance change cooldown
		#current_stance = attack_stance
		await get_tree().create_timer(penalty_duration).timeout
		stance_change_cooldown = false  # End stance change cooldown
	
	# Start attack cooldown
	attack_cooldown = true
	if attack_stance == "Top":
		next_stance = "Low"
		animPlayer_torso.play("attack1")
	elif attack_stance == "Mid":
		if is_midSwing_complete:
			animPlayer_torso.play("attack22")
			is_midSwing_complete = false
		else:
			animPlayer_torso.play("attack2")
			is_midSwing_complete = true
		next_stance = "Mid"
	elif attack_stance == "Low":
		next_stance = "Top"
		animPlayer_torso.play("attack3")
	
	# Wait for the duration of the animation before allowing another attack
	var attack_duration = animation_lengths[attack_stance]
	await get_tree().create_timer(attack_duration).timeout
	
	if is_attack_blocked:
		call_deferred("_apply_block_penalty")
		attack_cooldown = false  # End attack cooldown
		is_attacking = false  # Ensure is_attacking flag is reset after the cooldown
		update_torso_animation()
		return
		
	attack_cooldown = false  # End attack cooldown
	is_attacking = false  # Ensure is_attacking flag is reset after the cooldown
	update_torso_animation()
	
func _apply_block_penalty():
	stance_change_cooldown = true  # Start stance change cooldown
	await get_tree().create_timer(stance_penalty_duration).timeout
	stance_change_cooldown = false  # End stance change cooldown
	is_attack_blocked = false  # Reset the attack blocked flag
	
func change_stance(new_stance: String):
	is_attack_blocked = false
	if current_stance == new_stance and current_stance != "Mid":
		return  # Prevent stance change if it's the same as the current stance (except for Mid)
	current_stance = new_stance
	unseathe_sword()
	is_midSwing_complete= false
	emit_signal("stance_changed", new_stance)  # Emit signal for stance change
	if is_attacking:
		animPlayer_torso.stop()
		is_attacking = false
	stance_change_cooldown = true  # Start stance change cooldown
	await get_tree().create_timer(stanceChangeCooldown).timeout
	stance_change_cooldown = false  # End stance change cooldown
	#update_torso_animation()

func set_current_stance(new_stance: String):
	current_stance = new_stance

func unseathe_sword():
	if sword_sheathed:
		sword_sheathed = false
	#update_torso_animation()
	
func _on_sword_hit_area_area_entered(area):
	var entity = area.owner
	if area.is_in_group("hurtbox") and entity != self:
		if entity is Character:
			var attacker_stance = current_attack_stance
			var defender_stance = area.owner.current_stance  # Assuming the defender also has current_stance variable
			if is_facing_each_other(entity):
				if is_blocked(attacker_stance, defender_stance):
					print_debug(attacker_stance," attack blocked by " + area.owner.player_name)
					is_attack_blocked = true  # Set the attack blocked flag
					call_deferred("_interrupt_attack")  # Defer the attack interruption
					#animPlayer_torso.play("block_reaction")  # Play block reaction animation
				else:
					print_debug("sword colliding with hurtbox ", area.owner)
					area.owner.take_damage(attack_damage_calculator())
			else:
					print_debug("sword colliding with hurtbox ", area.owner)
					area.owner.take_damage(attack_damage_calculator())
		
func is_blocked(attacker_stance: String, defender_stance: String) -> bool:
	return attacker_stance == defender_stance
	
func is_facing_each_other(entity) -> bool:
	var self_facing_direction = 1 if facing == RIGHT else -1
	var entity_facing_direction = 1 if entity.facing == RIGHT else -1
	return (global_position - entity.global_position).x * self_facing_direction < 0 and self_facing_direction != entity_facing_direction	
	
func attack_damage_calculator():
	return randi_range(damageRange[0], damageRange[1])
	
func take_damage(amount: int):
	if is_taking_damage:
		return # Prevent taking damage if already in the process of taking damage

	life -= amount
	if life <= 0:
		# Character dies
		modulate = Color(0, 0, 0)  # Turn completely black
		# Defer the freeing of the node
		call_deferred("queue_free")
		#queue_free()  # Remove character from scene
	else:
		is_taking_damage = true
		modulate = Color(1, 0, 0)  # Flash red
		await get_tree().create_timer(0.1).timeout  # Flash duration
		modulate = Color(1, 1, 1)  # Reset color back to normal
		is_taking_damage = false

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
			animPlayer_torso.play(new_animation)

func update_animation():
	#var threshold = 0.01  # Define a small threshold for velocity
	##print("Updating animation: is_jumping =", is_jumping)
#
	#if is_jumping:
		#if velocity.y < 0:
			#animPlayer_legs.play("jump_up")
		#elif velocity.y > 0 and is_close_to_floor():
			#animPlayer_legs.play("jump_down")
	#elif direction == Vector2.ZERO or velocity.length() < threshold:
		#animPlayer_legs.play("idle_legs")  # Ensure legs go back to idle when not moving
	#else:
		#if not is_jumping:
			#if (facing == LEFT and direction == RIGHT) or (facing == RIGHT and direction == LEFT):
				#animPlayer_legs.speed_scale = -1  # Play animation in reverse
			#else:
				#animPlayer_legs.speed_scale = 1  # Play animation normally
			#animPlayer_legs.play("walk")
	if is_dashing:
		legs_sprite.play("dash")
	else:
		update_leg_animation()
	if not is_attacking:
		update_torso_animation()
	

func update_leg_animation():
	var threshold = 0.01  # Define a small threshold for velocity

	if is_jumping:
		if velocity.y < 0:
			animPlayer_legs.play("jump_up")
			is_falling = false
		elif not is_falling and velocity.y > 0 and is_close_to_floor():
			animPlayer_legs.play("jump_down")
			is_falling = true
	elif direction == Vector2.ZERO or velocity.length() < threshold:
		animPlayer_legs.play("idle_legs")  # Ensure legs go back to idle when not moving
	else:
		if not is_jumping:
			if (facing == LEFT and direction == RIGHT) or (facing == RIGHT and direction == LEFT):
				animPlayer_legs.speed_scale = -1  # Play animation in reverse
			else:
				animPlayer_legs.speed_scale = 1  # Play animation normally
			animPlayer_legs.play("walk")



func print_debug(message: String):
	print(player_name + ": " + message)
	
func _interrupt_attack():
	animPlayer_torso.stop()  # Stop the attack animation
	#animPlayer_torso.play("block_reaction")  # Play block reaction animation
	
# Additional function to debug the is_midSwing_complete state
func _process(_delta):
	#print("is_jumping:", is_jumping)
	pass

#func _on_grounded_updated(is_jumping):
	#pass # Replace with function body.


func _on_torso_animation_player_animation_finished(_anim_name: StringName):
	#if is_attacking and (animPlayer_torso.current_animation == "attack1" or animPlayer_torso.current_animation == "attack2" or animPlayer_torso.current_animation == "attack3"):
	is_attacking = false
	if is_attack_blocked:
		# If the attack was blocked, do not change the stance
		is_attack_blocked = false  # Reset the flag
	else:
		# Change the stance only after the attack animation finishes if not blocked
		if next_stance != "":
			current_stance = next_stance
			next_stance = ""
	update_torso_animation()
	current_torso_animation = ""

func _on_legs_animation_player_animation_finished(_anim_name: StringName):
	if animPlayer_legs.current_animation == "jump_down":
		#is_jumping = false
		update_leg_animation()




