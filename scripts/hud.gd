class_name Hud
extends CanvasLayer

@export var player1: Player
@export var player2: Player

@onready var score_label_1: Label = $ScoreLabel1
@onready var score_label_2: Label = $ScoreLabel2


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
