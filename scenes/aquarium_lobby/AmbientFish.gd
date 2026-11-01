class_name AmbientFish
extends CharacterBody2D

var vel_x: float = 120.0
var vel_y: float = 40.0
var sprite: Sprite2D

func _ready() -> void:
	# Add the animated sprite from the sheet
	sprite = Sprite2D.new()
	sprite.texture = load("res://entities/fish/Fish_Sprite_Sheet_16.png")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.hframes = 16
	sprite.vframes = 24
	sprite.frame = randi() % 4 * 16 # Random fish row
	sprite.scale = Vector2(2.5, 2.5)
	add_child(sprite)

func _physics_process(delta: float) -> void:
	position.x += vel_x * delta
	position.y += sin(Time.get_ticks_msec() * 0.003) * 60.0 * delta
	
	# Swim frame bobbing
	if sprite:
		var base = int(sprite.frame / 16) * 16
		sprite.frame = base + (int(Time.get_ticks_msec() / 160) % 4)
		
	if position.x > 1800.0 or position.x < 120.0:
		vel_x = -vel_x
		scale.x = -scale.x
