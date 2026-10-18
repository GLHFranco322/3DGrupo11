class_name Hud
extends CanvasLayer

@export var player1: Player
@export var player2: Player

@onready var score_label_1: Label = $ScoreLabel1
@onready var score_label_2: Label = $ScoreLabel2
@onready var time_label: Label = $TimeLabel
@onready var message_label: Label = $MessageLabel

## Cuando quedan menos de estos segundos, el tiempo se muestra en rojo.
@export_range(0.0, 60.0, 1.0, "suffix:s") var warning_time: float = 10.0
## Color del tiempo cuando está por terminar.
@export var warning_color: Color = Color(1.0, 0.3, 0.3)


func _ready() -> void:
	if player1:
		player1.score_changed.connect(_on_player1_score_changed)
		_on_player1_score_changed(player1.score)
	if player2:
		player2.score_changed.connect(_on_player2_score_changed)
		_on_player2_score_changed(player2.score)


func _on_player1_score_changed(new_score: int) -> void:
	score_label_1.text = "P1: %d" % new_score


func _on_player2_score_changed(new_score: int) -> void:
	score_label_2.text = "P2: %d" % new_score


func set_time(seconds: float) -> void:
	var total := int(ceil(seconds))
	@warning_ignore("integer_division")
	var minutes := total / 60
	time_label.text = "%d:%02d" % [minutes, total % 60]
	var warning := seconds <= warning_time
	time_label.modulate = warning_color if warning else Color.WHITE


func show_message(text: String) -> void:
	message_label.text = text
	message_label.visible = true
