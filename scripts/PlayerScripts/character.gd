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

#Multiplayer coop control variables
@export var controls: Resource = null

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

#References to raycasts
@onready var front_ray = $AnimatedSprite2DTorso/FrontRaycast
@onready var back_ray = $AnimatedSprite2DTorso/BackRaycast

#Raycast flags
var is_facing_right = true
var is_engaged = false

#To manage engagement
var enemies_in_range = []

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

#Modules
@onready var stamina_module = $StaminaModule
@onready var movement_module = $MovementModule

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
	movement_module.connect("grounded_updated", Callable(self, "_on_grounded_updated"))


func _physics_process(delta):
	movement_module.apply_gravity(delta)
	movement_module.move_and_slide()
	movement_module.handle_jump(delta)
	update_facing_direction()  # Update facing direction based on raycast
	update_animation()  # This is called every frame to update animations


func update_facing_direction():
	# Remove enemies no longer in range
	for enemy in enemies_in_range:
		if not is_instance_valid(enemy) or (global_position.distance_to(enemy.global_position) > 100):
			enemies_in_range.erase(enemy)

	# Add new enemies in range
	if front_ray.is_colliding() and front_ray.get_collider() is Character:
		var enemy = front_ray.get_collider()
		if not enemies_in_range.has(enemy):
			enemies_in_range.append(enemy)
	if back_ray.is_colliding() and back_ray.get_collider() is Character:
		var enemy = back_ray.get_collider()
		if not enemies_in_range.has(enemy):
			enemies_in_range.append(enemy)

	# Manage engagement
	if enemies_in_range.size() > 0:
		if not is_engaged:
			is_engaged = true
			engage_enemy(enemies_in_range[0])
	else:
		is_engaged = false

	# Update facing direction based on engagement
	if is_engaged:
		if not front_ray.is_colliding():
			is_engaged = false  # Disengage if the front ray is no longer colliding
	else:
		if front_ray.is_colliding() and front_ray.get_collider() is Character:
			is_engaged = true
			is_facing_right = movement_module.facing == movement_module.RIGHT  # Maintain current facing direction
		elif back_ray.is_colliding() and back_ray.get_collider() is Character:
			is_engaged = true
			is_facing_right = movement_module.facing == movement_module.LEFT
			legs_sprite.scale.x = -legs_sprite.scale.x  # Flip the character
			torso_sprite.scale.x = -torso_sprite.scale.x
			movement_module.facing = movement_module.LEFT if is_facing_right else movement_module.RIGHT

	# Update facing direction based on engagement
	if not is_engaged:
		if movement_module.direction.x > 0:
			movement_module.facing = movement_module.RIGHT
			is_facing_right = true
			legs_sprite.scale.x = 1
			torso_sprite.scale.x = 1
		elif movement_module.direction.x < 0:
			movement_module.facing = movement_module.LEFT
			is_facing_right = false
			legs_sprite.scale.x = -1
			torso_sprite.scale.x = -1

func engage_enemy(enemy):
	movement_module.facing = movement_module.RIGHT if global_position.x < enemy.global_position.x else movement_module.LEFT
	legs_sprite.scale.x = 1 if movement_module.facing == movement_module.RIGHT else -1
	torso_sprite.scale.x = 1 if movement_module.facing == movement_module.RIGHT else -1

func switch_engagement(facing_direction):
	if enemies_in_range.size() > 0:
		for enemy in enemies_in_range:
			if (facing_direction == movement_module.RIGHT and global_position.x < enemy.global_position.x) or (facing_direction == movement_module.LEFT and global_position.x > enemy.global_position.x):
				engage_enemy(enemy)
				break
func handle_target_switch():
	# Switch engagement based on joystick direction
	if Input.is_action_pressed(controls.stance_midL) and movement_module.facing == movement_module.RIGHT:
		switch_engagement(movement_module.RIGHT)
	elif Input.is_action_pressed(controls.stance_mid) and movement_module.facing == movement_module.LEFT:
		stance_button_held = true
		switch_engagement(movement_module.LEFT)

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
	elif Input.is_action_pressed(controls.stance_mid) and movement_module.facing == movement_module.RIGHT:
		stance_button_held = true
		if current_stance != "Mid":
			change_stance("Mid")
	elif Input.is_action_pressed(controls.stance_midL) and movement_module.facing == movement_module.LEFT:
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
			var defender_stance = entity.current_stance  # Assuming the defender also has current_stance variable
			if is_facing_each_other(entity):
				if is_blocked(attacker_stance, defender_stance):
					print_debug(attacker_stance + " attack blocked by " + entity.player_name)
					is_attack_blocked = true  # Set the attack blocked flag
					call_deferred("_interrupt_attack")  # Defer the attack interruption
				else:
					print_debug("sword colliding with hurtbox " + entity.player_name)
					entity.take_damage(attack_damage_calculator())
			else:
				print_debug("sword colliding with hurtbox " + entity.player_name)
				entity.take_damage(attack_damage_calculator())

		
func is_blocked(attacker_stance: String, defender_stance: String) -> bool:
	return attacker_stance == defender_stance
	
func is_facing_each_other(entity) -> bool:
	var self_facing_direction = 1 if movement_module.facing == movement_module.RIGHT else -1
	var entity_facing_direction = 1 if entity.movement_module.facing == movement_module.RIGHT else -1
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
	if movement_module.is_dashing:
		legs_sprite.play("dash")
	else:
		update_leg_animation()
	if not is_attacking:
		update_torso_animation()
	

func update_leg_animation():
	var threshold = 0.01  # Define a small threshold for velocity

	if movement_module.is_jumping:
		if velocity.y < 0:
			animPlayer_legs.play("jump_up")
			movement_module.is_falling = false
		elif not movement_module.is_falling and velocity.y > 0 and movement_module.is_close_to_floor():
			animPlayer_legs.play("jump_down")
			movement_module.is_falling = true
	elif movement_module.direction == Vector2.ZERO or velocity.length() < threshold:
		animPlayer_legs.play("idle_legs")  # Ensure legs go back to idle when not moving
	else:
		if not movement_module.is_jumping:
			if ((movement_module.facing == movement_module.LEFT and movement_module.direction == movement_module.RIGHT) or 
				(movement_module.facing == movement_module.RIGHT and movement_module.direction == movement_module.LEFT)):
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




