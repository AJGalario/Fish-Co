class_name FishPellet
extends Area2D

signal pellet_eaten(player_id: int, pellet: FishPellet)

@export var fall_speed: float = 380.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position.y += fall_speed * delta
	if position.y > 900.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body is FishPlayer:
		pellet_eaten.emit(body.player_id, self)
		queue_free()
