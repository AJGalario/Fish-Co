class_name SinkingDebris
extends Area2D

@export var rot_speed: float = 1.5

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	rotation += rot_speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body is FishPlayer:
		body.die("Crushed by sinking submarine debris!")
