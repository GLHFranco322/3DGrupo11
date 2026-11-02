class_name StateMachine
extends Node

@export var initial_state: State

var current_state: State
var states: Dictionary = {}


func _ready() -> void:
	var player := get_parent() as Player
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.player = player
			child.transitioned.connect(_on_transitioned)

	if initial_state:
		current_state = initial_state
		current_state.enter()


func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)
	var player := get_parent() as Player
	player.move_and_slide()

	# Sin gravedad ni piso: al chocar con colisiones inclinadas (arbustos,
	# piedras, cerca) el deslizamiento lo empuja hacia abajo. Se lo mantiene a
	# la altura del piso, salvo cuando cae al pozo o vuela por una patada.
	if not is_current("falling") and not is_current("kicked"):
		player.velocity.y = 0.0
		player.global_position.y = player.spawn_position.y


func _on_transitioned(state_name: String) -> void:
	var new_state: State = states.get(state_name.to_lower())
	if new_state == null or new_state == current_state:
		return
	current_state.exit()
	current_state = new_state
	current_state.enter()

func force_state(state_name: String) -> void:
	_on_transitioned(state_name)

func is_current(state_name: String) -> bool:
	return current_state != null and current_state.name.to_lower() == state_name.to_lower()
