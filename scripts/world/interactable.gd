class_name Interactable
extends Node3D
## Базовий клас для всього, з чим гравець взаємодіє кнопкою "Взаємодія".

var enabled := true

func _ready() -> void:
	add_to_group("interactable")

func prompt() -> String:
	return ""

func interact(_player: Node) -> void:
	pass
