extends Node

# Dependencies
var character: Character

# Unseath variables
var sword_sheathed = true

# Attack in progress flag
var is_attacking = false
var next_stance = ""
var stance_button_held = false
var is_midSwing_complete = false

# Attack variables for signals to AI and impact logic
var current_attack_stance = ""
var is_attack_blocked = false
# Signals
signal stance_changed(new_stance: String)
signal attack_stance_changed(new_attack_stance: String)

# Receiving damage flags
var is_taking_damage = false

var is_engaged = false

# To manage engagement
var enemies_in_range = []

# Cooldown timers
var attack_cooldown = false
var stance_change_cooldown = false

var attack_animation_lengths = {
	"Top": 0.18,  # Top attack animation length
	"Mid": 0.18,  # Mid attack animation length
	"Low": 0.18,  # Low attack animation length
}

# Time tracking
var attack_start_time = 0.0

@onready var stamina_module = $"../StaminaModule"

func _ready():
	character = $".."
# Handle stance change
func handle_stance_change():
	if stance_change_cooldown:
		return  # Prevent stance change during cooldown

	stance_button_held = false

	if Input.is_action_pressed(character.controls.stance_top):
		stance_button_held = true
		if character.current_stance != "Top":
			change_stance("Top")
	elif Input.is_action_pressed(character.controls.stance_low):
		stance_button_held = true
		if character.current_stance != "Low":
			change_stance("Low")
	elif Input.is_action_pressed(character.controls.stance_mid) and character.movement_module.facing == character.movement_module.RIGHT:
		stance_button_held = true
		if character.current_stance != "Mid":
			change_stance("Mid")
	elif Input.is_action_pressed(character.controls.stance_midL) and character.movement_module.facing == character.movement_module.LEFT:
		stance_button_held = true
		if character.current_stance != "Mid":
			change_stance("Mid")

	if not is_attacking:
		character.update_torso_animation()

# Handle attacks
func handle_attacks():
	if attack_cooldown:
		return  # Prevent attacks during cooldown

	if Input.is_action_just_pressed(character.controls.attack_top):
		perform_attack("Top")
	elif Input.is_action_just_pressed(character.controls.attack_mid):
		perform_attack("Mid")
	elif Input.is_action_just_pressed(character.controls.attack_low):
		perform_attack("Low")

# Perform attack
func perform_attack(attack_stance) -> void:
	if is_attacking or stamina_module.is_exhausted:
		return  # Prevent starting a new attack if already attacking
	stamina_module.deplete_stamina(20) #MAKE THIS A PUBLIC VARIABLE
	is_attacking = true  # Set attacking flag to true
	is_attack_blocked = false # Reset the attack blocked flag
	emit_signal("attack_stance_changed", attack_stance)  # Emit signal for attack stance change
	attack_start_time = Time.get_ticks_msec() / 1000.0
	unseathe_sword()
	var penalty_duration = character.stance_penalty_duration

	current_attack_stance = attack_stance # Set the global attack stance

	if character.current_stance == "Mid" and attack_stance == "Mid":
		penalty_duration *= 0.005  # Apply a small penalty duration for consecutive mid stance attacks to prevent spamming the animation.
		if is_midSwing_complete:
			character.animPlayer_torso.play("stanceMid2")
		else:
			character.animPlayer_torso.play("stanceMid")
		stance_change_cooldown = true  # Start stance change cooldown
		await get_tree().create_timer(penalty_duration).timeout
		stance_change_cooldown = false 
	elif character.current_stance != attack_stance or stance_button_held:
		if attack_stance == "Mid":
			penalty_duration *= 0.5  # Reduce penalty by 50% for mid stance
		next_stance = attack_stance
		character.animPlayer_torso.play("stance" + attack_stance)
		stance_change_cooldown = true  # Start stance change cooldown
		await get_tree().create_timer(penalty_duration).timeout
		stance_change_cooldown = false  # End stance change cooldown

	# Start attack cooldown
	attack_cooldown = true
	if attack_stance == "Top":
		next_stance = "Low"
		character.animPlayer_torso.play("attack1")
	elif attack_stance == "Mid":
		if is_midSwing_complete:
			character.animPlayer_torso.play("attack22")
			is_midSwing_complete = false
		else:
			character.animPlayer_torso.play("attack2")
			is_midSwing_complete = true
		next_stance = "Mid"
	elif attack_stance == "Low":
		next_stance = "Top"
		character.animPlayer_torso.play("attack3")

	# Wait for the duration of the animation before allowing another attack
	var attack_duration = attack_animation_lengths[attack_stance]
	await get_tree().create_timer(attack_duration).timeout

	if is_attack_blocked:
		call_deferred("_apply_block_penalty")
		attack_cooldown = false  # End attack cooldown
		is_attacking = false  # Ensure is_attacking flag is reset after the cooldown
		character.update_torso_animation()
		return

	attack_cooldown = false  # End attack cooldown
	is_attacking = false  # Ensure is_attacking flag is reset after the cooldown
	character.update_torso_animation()

func _apply_block_penalty():
	stance_change_cooldown = true  # Start stance change cooldown
	await get_tree().create_timer(character.stance_penalty_duration).timeout
	stance_change_cooldown = false  # End stance change cooldown
	is_attack_blocked = false  # Reset the attack blocked flag

func change_stance(new_stance: String):
	is_attack_blocked = false
	if character.current_stance == new_stance and character.current_stance != "Mid":
		return  # Prevent stance change if it's the same as the current stance (except for Mid)
	character.current_stance = new_stance
	unseathe_sword()
	is_midSwing_complete= false
	emit_signal("stance_changed", new_stance)  # Emit signal for stance change
	if is_attacking:
		character.animPlayer_torso.stop()
		is_attacking = false
	stance_change_cooldown = true  # Start stance change cooldown
	await get_tree().create_timer(character.stanceChangeCooldown).timeout
	stance_change_cooldown = false  # End stance change cooldown

func set_current_stance(new_stance: String):
	character.current_stance = new_stance

func unseathe_sword():
	if sword_sheathed:
		sword_sheathed = false

func _on_sword_hit_area_area_entered(area):
	var entity = area.owner
	if area.is_in_group("hurtbox") and entity != character:
		if entity is Character and is_instance_valid(entity) and is_instance_valid(entity.combat_module):
			var attacker_stance = current_attack_stance
			var defender_stance = entity.current_stance  # Assuming the defender also has current_stance variable
			if character.is_facing_each_other(entity):
				if is_blocked(attacker_stance, defender_stance):
					character.print_debug(attacker_stance + " attack blocked by " + entity.player_name)
					is_attack_blocked = true  # Set the attack blocked flag
					call_deferred("_interrupt_attack")  # Defer the attack interruption
				else:
					character.print_debug("sword colliding with hurtbox " + entity.player_name)
					entity.combat_module.take_damage(attack_damage_calculator(),attacker_stance)
			else:
				character.print_debug("sword colliding with hurtbox " + entity.player_name)
				entity.combat_module.take_damage(attack_damage_calculator())

func is_blocked(attacker_stance: String, defender_stance: String) -> bool:
	return attacker_stance == defender_stance

func attack_damage_calculator():
	return randi_range(character.damageRange[0], character.damageRange[1])

func take_damage(amount: int, attack_stance: String):
	if is_taking_damage:
		return # Prevent taking damage if already in the process of taking damage

	
	character.life -= amount
	
	if character.life <= 0:
		# Character dies
		character.play_death_animation(attack_stance)
		#character.modulate = Color(0, 0, 0)  # Turn completely black
		# Defer the freeing of the node
		#character.call_deferred("queue_free")
	else:
		stamina_module.deplete_stamina(10) #MAKE THIS A PUBLIC VARIABLE
		is_taking_damage = true
		character.modulate = Color(1, 0, 0)  # Flash red
		await get_tree().create_timer(0.1).timeout  # Flash duration
		character.modulate = Color(1, 1, 1)  # Reset color back to normal
		is_taking_damage = false

func _interrupt_attack():
	character.animPlayer_torso.stop()  # Stop the attack animation
	

