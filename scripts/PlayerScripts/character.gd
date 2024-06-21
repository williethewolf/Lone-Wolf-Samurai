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


# Double-tap detection
var last_tap_time_left = 0
var last_tap_time_right = 0
var double_tap_interval = 0.3

# Reference to the AnimationPlayer nodes
@onready var animPlayer_legs = $LegsAnimationPlayer
@onready var animPlayer_torso = $TorsoAnimationPlayer
@onready var animPlayer_full_body = $FullBodyAnimationPlayer

# Reference to the AnimatedSprite2D nodes
@onready var legs_sprite = $AnimatedSprite2DLegs
@onready var torso_sprite = $AnimatedSprite2DTorso
@onready var full_body_sprite = $AnimatedSprite2DFullBody

#References to raycasts
@onready var front_ray = $AnimatedSprite2DTorso/FrontRaycast
@onready var back_ray = $AnimatedSprite2DTorso/BackRaycast

#Raycast flags
var is_facing_right = true

# Current animation state
var current_torso_animation = ""

#Blood emitter
@onready var blood_emitter = $BloodEmitterContainer/BloodParticleEmitter
@onready var emitter_original_position = $BloodEmitterContainer.position.y
var tween

#Modules
@onready var stamina_module = $StaminaModule
@onready var movement_module = $MovementModule
@onready var combat_module = $CombatModule

#for camera help
signal grounded_updated (is_jumping)
#this passes the transform to the parent so the camera can be there.
#signal transform_changed(new_transform)

func _ready():
	set_process(true)
	animPlayer_legs.play("idle_legs")
	full_body_sprite.visible = false
	blood_emitter.emitting = false
	update_torso_animation()
	animPlayer_legs.connect("animation_finished", Callable(self, "_on_legs_animation_player_animation_finished"))
	animPlayer_torso.connect("animation_finished", Callable(self, "_on_torso_animation_player_animation_finished"))
	movement_module.connect("grounded_updated", Callable(self, "_on_grounded_updated"))
	stamina_module.connect("stamina_changed", Callable(self, "_on_stamina_changed"))
	stamina_module.connect("stamina_exhausted", Callable(self, "_on_stamina_exhausted"))


func _physics_process(delta):
	# Update movement module states
	movement_module.apply_gravity(delta)
	movement_module.move_and_slide()
	movement_module.handle_jump(delta)
	
	update_facing_direction()  # Update facing direction based on raycast
	update_animation()  # This is called every frame to update animations
	
	# Update stamina module states
	stamina_module.set_attacking(combat_module.is_attacking)  # Update attacking state
	stamina_module.set_moving(movement_module.direction != Vector2.ZERO)  # Update moving state
	stamina_module.regenerate_stamina(delta)
	
	#Debug

# Combat-related functions

func update_facing_direction():
	if combat_module and is_instance_valid(combat_module):
		# Remove enemies no longer in range
		for enemy in combat_module.enemies_in_range:
			if not is_instance_valid(enemy) or (global_position.distance_to(enemy.global_position) > 100):
				combat_module.enemies_in_range.erase(enemy)

		# Add new enemies in range
		if front_ray.is_colliding() and front_ray.get_collider() is Character:
			var enemy = front_ray.get_collider()
			if not combat_module.enemies_in_range.has(enemy):
				combat_module.enemies_in_range.append(enemy)
		if back_ray.is_colliding() and back_ray.get_collider() is Character:
			var enemy = back_ray.get_collider()
			if not combat_module.enemies_in_range.has(enemy):
				combat_module.enemies_in_range.append(enemy)

		# Manage engagement
		if combat_module.enemies_in_range.size() > 0:
			if not combat_module.is_engaged:
				combat_module.is_engaged = true
				engage_enemy(combat_module.enemies_in_range[0])
		else:
			combat_module.is_engaged = false

		# Update facing direction based on engagement
		if combat_module.is_engaged:
			if not front_ray.is_colliding():
				combat_module.is_engaged = false  # Disengage if the front ray is no longer colliding
		else:
			if front_ray.is_colliding() and front_ray.get_collider() is Character:
				combat_module.is_engaged = true
				is_facing_right = movement_module.facing == movement_module.RIGHT  # Maintain current facing direction
			elif back_ray.is_colliding() and back_ray.get_collider() is Character:
				combat_module.is_engaged = true
				is_facing_right = movement_module.facing == movement_module.LEFT
				legs_sprite.scale.x = -legs_sprite.scale.x  # Flip the character
				torso_sprite.scale.x = -torso_sprite.scale.x
				full_body_sprite.scale.x = -full_body_sprite.scale.x
				#full_body_sprite.position = Vector2(full_body_sprite_xPos, full_body_sprite.position.y) if full_body_sprite.scale.x > 0 else Vector2(-full_body_sprite_xPos, full_body_sprite.position.y)
				movement_module.facing = movement_module.LEFT if is_facing_right else movement_module.RIGHT

		# Update facing direction based on engagement
		if not combat_module.is_engaged:
			if movement_module.direction.x > 0:
				movement_module.facing = movement_module.RIGHT
				is_facing_right = true
				legs_sprite.scale.x = 1
				torso_sprite.scale.x = 1
				full_body_sprite.scale.x = 1.215
				#full_body_sprite.position = Vector2(-full_body_sprite_xPos, full_body_sprite.position.y)
			elif movement_module.direction.x < 0:
				movement_module.facing = movement_module.LEFT
				is_facing_right = false
				legs_sprite.scale.x = -1
				torso_sprite.scale.x = -1
				full_body_sprite.scale.x = -1
				#full_body_sprite.position = Vector2(full_body_sprite_xPos, full_body_sprite.position.y)


func engage_enemy(enemy):
	if life > 0:
		movement_module.facing = movement_module.RIGHT if global_position.x < enemy.global_position.x else movement_module.LEFT
		legs_sprite.scale.x = 1 if movement_module.facing == movement_module.RIGHT else -1
		torso_sprite.scale.x = 1 if movement_module.facing == movement_module.RIGHT else -1
		full_body_sprite.scale.x = 1 if movement_module.facing == movement_module.RIGHT else -1
		#full_body_sprite.position = Vector2(-full_body_sprite_xPos, full_body_sprite.position.y) if full_body_sprite.scale.x > 0 else Vector2(full_body_sprite_xPos, full_body_sprite.position.y)
	

func switch_engagement(facing_direction):
	if combat_module and is_instance_valid(combat_module):
		if combat_module.enemies_in_range.size() > 0:
			for enemy in combat_module.enemies_in_range:
				if (facing_direction == movement_module.RIGHT and global_position.x < enemy.global_position.x) or (facing_direction == movement_module.LEFT and global_position.x > enemy.global_position.x):
					engage_enemy(enemy)
					break
func handle_target_switch():
	if combat_module and is_instance_valid(combat_module):
		# Switch engagement based on joystick direction
		if Input.is_action_pressed(controls.stance_midL) and movement_module.facing == movement_module.RIGHT:
			switch_engagement(movement_module.RIGHT)
		elif Input.is_action_pressed(controls.stance_mid) and movement_module.facing == movement_module.LEFT:
			combat_module.stance_button_held = true
			switch_engagement(movement_module.LEFT)

func is_facing_each_other(entity) -> bool:
	var self_facing_direction = 1 if movement_module.facing == movement_module.RIGHT else -1
	var entity_facing_direction = 1 if entity.movement_module.facing == movement_module.RIGHT else -1
	return (global_position - entity.global_position).x * self_facing_direction < 0 and self_facing_direction != entity_facing_direction

func play_death_animation(current_attack_stance):
	print("play_death_animation called with stance: ", current_attack_stance)
	legs_sprite.visible = false
	torso_sprite.visible = false
	full_body_sprite.visible = true
	blood_emitter.emitting = true
	
	fluctuate_particle_emission(current_attack_stance)
	animPlayer_full_body.play("death1")
	
func blood_emitter_offset(current_attack_stance):
# Adjust position depending on where the cut is coming from
	var cut_offset = 0.0
	if current_attack_stance == "Top":
		cut_offset = 0.0  # No change
	elif current_attack_stance == "Mid":
		cut_offset = 20.0  # Lower the emitter
	elif current_attack_stance == "Low":
		cut_offset = 40.0  # Even lower

	print("Cut offset: ", cut_offset)
	$BloodEmitterContainer.position.y += cut_offset
	print("BloodEmitterContainer new position: ", $BloodEmitterContainer.position)

func fluctuate_particle_emission(current_attack_stance):
	$BloodEmitterContainer.position.y = emitter_original_position
	blood_emitter_offset(current_attack_stance)
	# Calculate base direction with fuzziness
	var base_y = randf_range(-3, 3)
	var base_x = randf_range(1, 3) if base_y < 0 else 3
	
	# Set the direction with calculated variance
	blood_emitter.process_material.direction = Vector3(base_x, base_y, 0)
	
	var iterations = randi_range(3, 7)
	var initial_max_velocity = blood_emitter.process_material.initial_velocity_min
	var custom_max_velocity = 80
	for i in range(iterations):
		tween = create_tween()
		var decrease_time = randf_range(0.2, 0.7)
		var increase_time = randf_range(0.3, 1.0)
		var max_value = 1.0 / (i + 1)  # Calculate the max value for each iteration
		# Set initial velocity for each iteration
		if i == 0:
			blood_emitter.process_material.initial_velocity_min = initial_max_velocity
		else:
			blood_emitter.process_material.initial_velocity_min = randf_range(custom_max_velocity, initial_max_velocity)
		if tween:
			tween.kill()
			tween = create_tween()
			# Tween to increase emission to a max value
			tween.tween_property(blood_emitter, "amount_ratio", max_value, increase_time)
			# Tween to decrease emission to 0
			tween.tween_property(blood_emitter, "amount_ratio", 0.0, decrease_time)
			await tween.finished
	blood_emitter.emitting = false
func update_torso_animation():
	if combat_module and is_instance_valid(combat_module):
		if not combat_module.is_attacking:
			var new_animation = ""
			if current_stance == "Mid":
				if combat_module.is_midSwing_complete:
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
	if combat_module and is_instance_valid(combat_module):
		if movement_module.is_dashing:
			legs_sprite.play("dash")
		else:
			update_leg_animation()
		if not combat_module.is_attacking:
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
	
# Additional function to debug the is_midSwing_complete state
func _process(_delta):
	#print("is_jumping:", is_jumping)
	pass

#func _on_grounded_updated(is_jumping):
	#movement_module.is_jumping = is_jumping


func _on_torso_animation_player_animation_finished(_anim_name: StringName):
	if combat_module and is_instance_valid(combat_module):
		combat_module.is_attacking = false
		if combat_module.is_attack_blocked:
			# If the attack was blocked, do not change the stance
			combat_module.is_attack_blocked = false  # Reset the flag
		else:
			# Change the stance only after the attack animation finishes if not blocked
			if combat_module.next_stance != "":
				current_stance = combat_module.next_stance
				combat_module.next_stance = ""
		update_torso_animation()
		current_torso_animation = ""

func _on_legs_animation_player_animation_finished(_anim_name: StringName):
	if animPlayer_legs.current_animation == "jump_down":
		#is_jumping = false
		update_leg_animation()
		
func _on_stamina_changed(current_stamina: int):
	# Handle stamina change (e.g., update UI)
	pass

func _on_stamina_exhausted():
	# Handle stamina exhaustion (e.g., prevent attacking or dashing)
	pass





