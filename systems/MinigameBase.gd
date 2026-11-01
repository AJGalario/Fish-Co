class_name MinigameBase
extends Node2D

@export var minigame_title: String = "Minigame"
@export var minigame_instructions: String = "Survive!"
@export var round_time: float = 30.0

var time_remaining: float = 30.0
var is_active: bool = false
var surviving_player_ids: Array = []
var eliminated_order: Array = []

@onready var hud: CanvasLayer = $HUD
@onready var timer_label: Label = $HUD/Margin/TopBar/TimerLabel
@onready var instructions_label: Label = $HUD/CenterInfo/InstructionsLabel

func _ready() -> void:
	# Pull user custom match time (30s min, 60s max)
	if GameManager.match_config:
		round_time = clampf(GameManager.match_config.round_time, 30.0, 60.0)
	time_remaining = round_time
	
	# Apply chosen custom background theme
	_apply_background_theme()
	
	EventBus.player_died.connect(_on_player_died)
	
	setup_players()
	start_countdown()

func _apply_background_theme() -> void:
	if not GameManager.match_config:
		return
	var bg_color = GameManager.match_config.get_bg_color()
	var bg = get_node_or_null("WaterBackground")
	if bg and bg is ColorRect:
		bg.color = bg_color

func setup_players() -> void:
	surviving_player_ids.clear()
	eliminated_order.clear()
	
	var spawn_points = $SpawnPoints.get_children()
	var fish_scene = preload("res://entities/fish/FishPlayer.tscn")
	
	for i in range(GameManager.players.size()):
		var pd = GameManager.players[i]
		pd.reset_for_round()
		surviving_player_ids.append(pd.player_id)
		
		var fish = fish_scene.instantiate()
		fish.player_id = pd.player_id
		fish.peer_id = pd.peer_id
		var pt = spawn_points[i % spawn_points.size()] as Marker2D
		fish.global_position = pt.global_position
		add_child(fish)
		
	# Pause fish physics initially during countdown so they stay afloat & prepared
	_set_all_fish_physics(false)

func _set_all_fish_physics(enabled: bool) -> void:
	for child in get_children():
		if child is FishPlayer:
			child.set_physics_process(enabled)

func start_countdown() -> void:
	is_active = false
	if instructions_label:
		instructions_label.visible = true
		
	# 3-Second Visual Countdown
	for count in [3, 2, 1]:
		if instructions_label:
			instructions_label.text = "%s\n\nStarting in %d..." % [minigame_instructions, count]
		await get_tree().create_timer(1.0).timeout
		
	if instructions_label:
		instructions_label.text = "SWIM! 🚀"
		
	# Enable fish physics and activate gameplay
	_set_all_fish_physics(true)
	is_active = true
	
	await get_tree().create_timer(0.6).timeout
	if instructions_label:
		instructions_label.visible = false

func _process(delta: float) -> void:
	if not is_active:
		return
		
	time_remaining -= delta
	if timer_label:
		timer_label.text = "%02d" % max(0, int(time_remaining))
		
	if time_remaining <= 0.0:
		finish_minigame()

func _on_player_died(player_id: int) -> void:
	if player_id in surviving_player_ids:
		surviving_player_ids.erase(player_id)
		eliminated_order.append(player_id)
	
	# If no players are left alive at all, end the minigame immediately
	if surviving_player_ids.is_empty():
		finish_minigame()
	# In multiplayer VS games, if only 1 last survivor remains, declare them winner and end
	elif surviving_player_ids.size() == 1 and GameManager.players.size() > 1:
		finish_minigame()

func finish_minigame() -> void:
	if not is_active:
		return
	is_active = false
	
	var final_rankings = surviving_player_ids.duplicate()
	eliminated_order.reverse()
	final_rankings.append_array(eliminated_order)
	
	# Defers the scene change so physics collision step finishes safely
	GameManager.call_deferred("complete_minigame", final_rankings)
