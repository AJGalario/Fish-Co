extends MinigameBase

# Minigame 4: osu!catch Pellets with Fish Slap Stun
# Uses FishPellet.tscn scenes spawned over time

const PelletScene = preload("res://scenes/minigames/mg_pellet_catch/FishPellet.tscn")

@export var pellet_spawn_rate: float = 0.25
var pellet_timer: float = 0.0
var player_catches: Dictionary = {} # player_id -> count

@onready var catch_score_label: Label = $HUD/Margin/TopBar/CatchScoreLabel

func _ready() -> void:
	minigame_title = "Pellet Frenzy"
	minigame_instructions = "CATCH RAINING FISH FLAKES! PRESS ACTION TO SLAP & STUN RIVALS!"
	round_time = 35.0
	super._ready()
	
	for p in GameManager.players:
		player_catches[p.player_id] = 0
	_update_catch_ui()

func _process(delta: float) -> void:
	super._process(delta)
	if not is_active:
		return
		
	pellet_timer += delta
	if pellet_timer >= pellet_spawn_rate:
		pellet_timer = 0.0
		_spawn_pellet_instance()

func _spawn_pellet_instance() -> void:
	var pellet = PelletScene.instantiate() as FishPellet
	pellet.position = Vector2(randf_range(200.0, 1720.0), 100.0)
	pellet.pellet_eaten.connect(_on_pellet_eaten)
	add_child(pellet)

func _on_pellet_eaten(player_id: int, _pellet: FishPellet) -> void:
	if player_catches.has(player_id):
		player_catches[player_id] += 1
	_update_catch_ui()

func _update_catch_ui() -> void:
	if not catch_score_label:
		return
	var text_parts = []
	for pid in player_catches:
		text_parts.append("P%d: %d" % [pid + 1, player_catches[pid]])
	catch_score_label.text = "Pellets: " + " | ".join(text_parts)

func finish_minigame() -> void:
	if not is_active:
		return
	is_active = false
	
	var sorted_pids = player_catches.keys()
	sorted_pids.sort_custom(func(a, b): return player_catches[a] > player_catches[b])
	GameManager.complete_minigame(sorted_pids)
