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
	(get_parent() as Player).move_and_slide()


func _on_transitioned(state_name: String) -> void:
	var new_state: State = states.get(state_name.to_lower())
	if new_state == null or new_state == current_state:
		return
	current_state.exit()
	current_state = new_state
	current_state.enter()
