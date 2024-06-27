extends Node

# Constants for movement and controls
const LEFT = Vector2(-1, 0)
const RIGHT = Vector2(1, 0)

# Jump properties
@export var jump_height : float = 200.0  # Jump height in pixels
@export var min_jump_height : float = 50.0  # Minimum jump height in pixels
@export var gravity : float = 5500.0  # Increased gravity strength
@export var jump_speed : float = -1500.0  # Increased initial jump speed (more negative to move up faster)
@export var jump_duration : float = 0.3  # Duration to reach full jump height

#Floor detection raycast
@onready var floorRaycast : RayCast2D = $"../FloorDetectionRayCast2D"

# Movement variables
var direction : Vector2 = Vector2.ZERO
var facing : Vector2 = RIGHT

# Dash variables
var is_dashing : bool = false
@export var dash_speed: float = 1200.0  # Adjusted dash speed
var dash_duration : float = 0.2
var dash_timer : float = 0

#Run variables
var is_running : bool = false
@export var run_speed: float = 800.0  # Adjusted run speed
@export var run_stamina_cost_per_second: float = 3  # Stamina cost per second while running
var run_timer :float = 0.0

# Jump variables
var is_jumping : bool = false
var is_falling : bool = false


#stamina variables
var is_exhausted : bool = false

#other Modules

# Signal for camera help
signal grounded_updated(is_jumping : bool)

func _ready() -> void :
	var stamina_module : Node = get_parent().get_node("StaminaModule")
	if stamina_module:
		stamina_module.connect("exhausted_changed", Callable(self, "_on_exhausted_changed"))

func apply_gravity(delta : float) -> void :
	if not get_parent().is_on_floor():
		get_parent().velocity.y += gravity * delta

func jump() -> void :
	is_jumping = true
	get_parent().velocity.y = jump_speed  # Set the initial jump speed
	#get_parent().animPlayer_legs.play("jump_up")  # Play the first half of the jump animation
	emit_signal("grounded_updated", is_jumping)

func is_close_to_floor() -> bool:
	return floorRaycast.is_colliding()

func handle_jump(_delta : float) -> void :
	if get_parent().is_on_floor():
		is_jumping = false
		emit_signal("grounded_updated", is_jumping)
	else:
		is_jumping = true

func run() -> void :
	if not is_exhausted:
		is_running = true
		get_parent().velocity.x = direction.x * run_speed
		#if not is_jumping:
		#	get_parent().play_run_animation()

func stop_run() -> void :
	is_running = false
	get_parent().velocity.x = direction.x * get_parent().speed
	get_parent().stop_run_animation()

	
func move_and_slide() -> void :
	if is_running:
		get_parent().velocity.x = direction.x * run_speed
	else:
		get_parent().velocity.x = direction.x * get_parent().speed
	get_parent().move_and_slide()


func _on_exhausted_changed(is_exhausted_flag: bool) -> void :
	self.is_exhausted = is_exhausted_flag
	if is_exhausted:
		stop_run()

func _physics_process(delta : float) -> void :
	if is_running:
		run_timer += delta
		if run_timer >= 1.0:
			get_parent().stamina_module.deplete_stamina(run_stamina_cost_per_second)
			run_timer = 0.0
		if get_parent().stamina_module.is_exhausted:
			stop_run()
	get_parent().stamina_module.set_is_jumping(is_jumping)
