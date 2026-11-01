extends MinigameBase

# Minigame 2: Flappy Fish
# Instantiates CoralPillarPair.tscn visual scenes across the arena

const PillarScene = preload("res://scenes/minigames/mg_flappy_fish/CoralPillarPair.tscn")

@export var spawn_interval: float = 1.8
var pipe_spawn_timer: float = 0.0

@onready var pillar_container: Node2D = $PillarContainer

func _ready() -> void:
	minigame_title = "Flappy Fish"
	minigame_instructions = "PRESS SPACE OR JUMP TO FLAP! AVOID THE CORAL COLUMNS!"
	round_time = 40.0
	super._ready()

func setup_players() -> void:
	super.setup_players()
	var idx = 0
	for child in get_children():
		if child is FishPlayer:
			# Stagger each player's starting column slightly so they don't overlap
			child.position = Vector2(250 + idx * 55, 540)
			child.base_speed = 0.0 # Flappy fish stays in vertical swim column
			child.can_air_jump = true # Mid-air flapping
			child.jump_impulse = -450.0
			child.velocity = Vector2.ZERO # Ensure stationary float
			idx += 1

func _process(delta: float) -> void:
	super._process(delta)
	if not is_active:
		return
		
	pipe_spawn_timer += delta
	if pipe_spawn_timer >= spawn_interval:
		pipe_spawn_timer = 0.0
		_spawn_pillar_pair()

func _spawn_pillar_pair() -> void:
	var pillar = PillarScene.instantiate() as CoralPillarPair
	pillar.position = Vector2(2050.0, 0.0)
	pillar_container.add_child(pillar)
	var gap_center = randf_range(300.0, 780.0)
	pillar.randomize_gap(gap_center, 240.0)
