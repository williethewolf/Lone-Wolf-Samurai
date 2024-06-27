extends Node

# Unseath variables
var sword_sheathed : bool = true

# Attack in progress flag
var is_attacking : bool = false
var next_stance : String = ""
#var stance_button_held : bool = false
var TopStance_button_held : bool = false
var MidStance_button_held : bool = false
var LowStance_button_held : bool = false

var previous_top_stance_input : bool = false
var previous_mid_stance_input : bool = false
var previous_low_stance_input : bool = false

var stance_set_by_attack: bool = false

var is_midSwing_complete : bool = false

# Attack variables for signals to AI and impact logic
var current_attack_stance : String = ""
var is_attack_blocked : bool = false
# Signals
signal stance_changed(new_stance: String)
signal attack_stance_changed(new_attack_stance: String)

# Receiving damage flags
var is_taking_damage : bool = false

var is_engaged : bool = false

# To manage engagement
var enemies_in_range : Array = []

# Cooldown timers
var attack_cooldown : bool = false
var stance_change_cooldown : bool = false

var attack_animation_lengths : Dictionary = {
	"Top": 0.18,  # Top attack animation length
	"Mid": 0.18,  # Mid attack animation length
	"Low": 0.18,  # Low attack animation length
}
	
# Time tracking
var attack_start_time : float = 0.0

@onready var stamina_module : Node = $"../StaminaModule"
@onready var movement_module : Node = $"../MovementModule"

#Set dependencies
@onready var character: Character = $".."

func _ready() -> void:
	if not character:
		print("Character node not found!")

# Handle stance change
func handle_stance_change() -> void:
	if stance_change_cooldown:
		return  # Prevent stance change during cooldown

	# Update button held states
	var current_top_stance_input: bool = Input.is_action_pressed(character.controls.stance_top)
	var current_mid_stance_input: bool = Input.is_action_pressed(character.controls.stance_mid) and character.movement_module.facing == character.movement_module.RIGHT
	var current_low_stance_input: bool = Input.is_action_pressed(character.controls.stance_low)
	
	# Additional condition for Mid stance when facing LEFT
	if not current_mid_stance_input:
		current_mid_stance_input = Input.is_action_pressed(character.controls.stance_midL) and character.movement_module.facing == character.movement_module.LEFT

	# Reset mid stance if transitioning through top or low stance
	if stance_set_by_attack:
		stance_change_cooldown = true  # Start stance change cooldown
		await get_tree().create_timer(character.stance_penalty_duration).timeout
		stance_change_cooldown = false 
		if current_top_stance_input and not TopStance_button_held:
			MidStance_button_held = false
			if character.current_stance != "Top":
				change_stance("Top")
		elif current_low_stance_input and not LowStance_button_held:
			MidStance_button_held = false
			if character.current_stance != "Low":
				change_stance("Low")
		elif current_mid_stance_input and not MidStance_button_held:
			if character.current_stance != "Mid":
				change_stance("Mid")
	else:
		if current_top_stance_input or TopStance_button_held:
			MidStance_button_held = false
			if character.current_stance != "Top":
				change_stance("Top")
		elif current_low_stance_input or LowStance_button_held:
			MidStance_button_held = false
			if character.current_stance != "Low":
				change_stance("Low")
		elif current_mid_stance_input or MidStance_button_held:
			if character.current_stance != "Mid":
				change_stance("Mid")

	if not is_attacking:
		character.update_torso_animation()

	# Update the previous input states
	TopStance_button_held = current_top_stance_input
	MidStance_button_held = current_mid_stance_input
	LowStance_button_held = current_low_stance_input

func change_stance(new_stance: String) -> void:
	is_attack_blocked = false
	if character.current_stance == new_stance and character.current_stance != "Mid":
		return  # Prevent stance change if it's the same as the current stance (except for Mid)
	character.current_stance = new_stance
	unseathe_sword()
	if new_stance in ["Low", "Top"]:
		is_midSwing_complete= false
	emit_signal("stance_changed", new_stance)  # Emit signal for stance change
	
	# Reset stance button held states
	reset_stance_button_states()
	
	if is_attacking:
		character.animPlayer_torso.stop()
		is_attacking = false
	stance_change_cooldown = true  # Start stance change cooldown
	await get_tree().create_timer(character.stanceChangeCooldown).timeout
	stance_change_cooldown = false  # End stance change cooldown

func set_current_stance(new_stance: String) -> void:
	character.current_stance = new_stance

func stance_button_held() -> bool:
	return TopStance_button_held or MidStance_button_held or LowStance_button_held

func reset_stance_button_states() -> void:
	TopStance_button_held = false
	MidStance_button_held = false
	LowStance_button_held = false

# Handle attacks
func handle_attacks() -> void:
	if attack_cooldown:
		return  # Prevent attacks during cooldown

	if Input.is_action_just_pressed(character.controls.attack_top):
		perform_attack("Top")
	elif Input.is_action_just_pressed(character.controls.attack_mid):
		perform_attack("Mid")
	elif Input.is_action_just_pressed(character.controls.attack_low):
		perform_attack("Low")

# Perform attack
func perform_attack(attack_stance: String) -> void:
	if is_attacking or stamina_module.is_exhausted:
		return  # Prevent starting a new attack if already attacking
	is_attacking = true  # Set attacking flag to true
	is_attack_blocked = false  # Reset the attack blocked flag
	emit_signal("attack_stance_changed", attack_stance)  # Emit signal for attack stance change
	attack_start_time = Time.get_ticks_msec() / 1000.0
	unseathe_sword()
	var penalty_duration: float = character.stance_penalty_duration

	current_attack_stance = attack_stance  # Set the global attack stance

	if character.current_stance == "Mid" and attack_stance == "Mid":
		penalty_duration *= 0.005  # Apply a small penalty duration for consecutive mid stance attacks to prevent spamming the animation.
		if is_midSwing_complete:
			character.animPlayer_torso.play("stanceMid2")
		else:
			character.animPlayer_torso.play("stanceMid")
		stance_change_cooldown = true  # Start stance change cooldown
		await get_tree().create_timer(penalty_duration).timeout
		stance_change_cooldown = false
	elif character.current_stance != attack_stance:
		if attack_stance == "Mid":
			penalty_duration *= 0.5  # Reduce penalty by 50% for mid stance
		character.animPlayer_torso.play("stance" + attack_stance)
		stance_change_cooldown = true  # Start stance change cooldown
		await get_tree().create_timer(penalty_duration).timeout
		stance_change_cooldown = false  # End stance change cooldown
	#Apply stamina change after animation
	stamina_module.deplete_stamina(20)  # MAKE THIS A PUBLIC VARIABLE
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
	var attack_duration: float = attack_animation_lengths[attack_stance]
	await get_tree().create_timer(attack_duration).timeout

	if is_attack_blocked:
		call_deferred("_apply_block_penalty")
		attack_cooldown = false  # End attack cooldown
		is_attacking = false  # Ensure is_attacking flag is reset after the cooldown
		character.update_torso_animation()
		return

	attack_cooldown = false  # End attack cooldown
	is_attacking = false  # Ensure is_attacking flag is reset after the cooldown

	# Reset stance to attack stance after the attack
	
	change_stance(next_stance)
	stance_set_by_attack = true 
	character.update_torso_animation()
	stance_set_by_attack = false  # Reset the flag after the attack cooldown

func _apply_block_penalty() -> void:
	stance_change_cooldown = true  # Start stance change cooldown
	await get_tree().create_timer(character.stance_penalty_duration).timeout
	stance_change_cooldown = false  # End stance change cooldown
	is_attack_blocked = false  # Reset the attack blocked flag

func unseathe_sword() -> void:
	if sword_sheathed:
		sword_sheathed = false

func _on_sword_hit_area_area_entered(area : Area2D) -> void:
	var entity : Object = area.owner
	if area.is_in_group("hurtbox") and entity != character:
		if entity is Character and is_instance_valid(entity) and is_instance_valid(entity.combat_module):
			var attacker_stance : String = current_attack_stance
			var defender_stance : String = entity.current_stance  # Assuming the defender also has current_stance variable
			if character.is_facing_each_other(entity):
				if is_blocked(attacker_stance, defender_stance) and not movement_module.is_running:
					character.print_debug(attacker_stance + " attack blocked by " + entity.player_name)
					stamina_module.deplete_stamina(25)
					entity.stamina_module.deplete_stamina(-5)  # Hackish but it is giving 5 points of stamina to the blocker and that's why the attack costs 25 instead of 20
					is_attack_blocked = true  # Set the attack blocked flag
					call_deferred("_interrupt_attack")  # Defer the attack interruption
				else:
					character.print_debug("sword colliding with hurtbox " + entity.player_name)
					entity.combat_module.take_damage(attack_damage_calculator(), attacker_stance)
					entity.blood_slash_splatter(attacker_stance)
			else:
				character.print_debug("sword colliding with hurtbox " + entity.player_name)
				entity.combat_module.take_damage(attack_damage_calculator(), attacker_stance)
				entity.blood_slash_splatter(attacker_stance)

func is_blocked(attacker_stance: String, defender_stance: String) -> bool:
	return attacker_stance == defender_stance and not movement_module.is_running

func attack_damage_calculator() -> float:
	return randi_range(character.damageRange[0], character.damageRange[1])

func take_damage(amount: int, attack_stance: String) -> void:
	if is_taking_damage:
		return # Prevent taking damage if already in the process of taking damage

	
	character.life -= amount
	
	if character.life <= 0:
		# Character dies
		character.current_stance="null"
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

func _interrupt_attack() -> void:
	character.animPlayer_torso.stop()  # Stop the attack animation

	

