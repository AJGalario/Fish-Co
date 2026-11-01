extends Control

# Visual Aquarium Lobby
# When a player joins (local or remote), an aquarium hand drops a fish into the tank!

const AmbientFishScript = preload("res://scenes/aquarium_lobby/AmbientFish.gd")

@onready var tank_area: Control = $TankArea
@onready var water_bg: ColorRect = $TankArea/WaterBackground
@onready var fish_container: Node2D = $TankArea/FishContainer
@onready var player_count_label: Label = $HUD/Margin/VBox/PlayerCountLabel
@onready var hand_visual: ColorRect = $HandVisual
@onready var settings_modal: Control = $SettingsLayer/MatchSettingsDialog

var fish_colors = [
	Color("#FFD166"), # P1
	Color("#06D6A0"), # P2
	Color("#118AB2"), # P3
	Color("#EF476F")  # P4
]

func _ready() -> void:
	EventBus.network_player_connected.connect(_on_network_player_connected)
	
	if settings_modal:
		settings_modal.config_saved.connect(_on_config_saved)
		settings_modal.visible = false
		
	_apply_current_theme()
	_refresh_lobby_ui()
	_populate_initial_fishes()

func _apply_current_theme() -> void:
	if water_bg and GameManager.match_config:
		water_bg.color = GameManager.match_config.get_bg_color()

func _on_config_saved() -> void:
	_apply_current_theme()
	# Refresh player list to reflect added bots if any
	GameManager.setup_local_players(2)
	_populate_initial_fishes()
	_refresh_lobby_ui()

func _populate_initial_fishes() -> void:
	for child in fish_container.get_children():
		child.queue_free()
	
	for i in range(GameManager.players.size()):
		_drop_fish_animation(i, GameManager.players[i].player_name)

func _on_network_player_connected(peer_id: int, p_data: Dictionary) -> void:
	_refresh_lobby_ui()
	var idx = GameManager.players.size() - 1
	_drop_fish_animation(idx, p_data.get("player_name", "New Fish"))

func drop_player_fish(player_idx: int, p_name: String) -> void:
	_drop_fish_animation(player_idx, p_name)
	_refresh_lobby_ui()

func _drop_fish_animation(player_idx: int, p_name: String) -> void:
	# Spawn hand from top
	hand_visual.position = Vector2(400 + player_idx * 280, -120)
	hand_visual.visible = true
	
	var tween = create_tween()
	# Hand reaches down
	tween.tween_property(hand_visual, "position:y", 120.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		_spawn_swimming_fish(player_idx, hand_visual.position.x, p_name)
	)
	# Hand retracts back up
	tween.tween_property(hand_visual, "position:y", -140.0, 0.4).set_delay(0.15)
	tween.tween_callback(func(): hand_visual.visible = false)

func _spawn_swimming_fish(player_idx: int, spawn_x: float, p_name: String) -> void:
	var fish_body = CharacterBody2D.new()
	fish_body.position = Vector2(spawn_x, 150)
	fish_body.set_script(AmbientFishScript)
	
	var lbl = Label.new()
	lbl.text = p_name
	lbl.position = Vector2(-40, -42)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size = Vector2(80, 20)
	fish_body.add_child(lbl)
	
	fish_container.add_child(fish_body)

func _refresh_lobby_ui() -> void:
	if player_count_label:
		player_count_label.text = "Fishes in Aquarium: %d / 4 (Theme: %s | Round: %ds)" % [
			GameManager.players.size(),
			MatchConfig.THEME_NAMES.get(GameManager.match_config.background_theme, "Ocean"),
			int(GameManager.match_config.round_time)
		]

# Match Settings Dialog Button
func _on_settings_pressed() -> void:
	if settings_modal:
		settings_modal.open_settings()

# Game Mode Starters
func _on_vs_mode_pressed() -> void:
	GameManager.start_game_loop(GameManager.GameCategory.VS)

func _on_coop_mode_pressed() -> void:
	GameManager.start_game_loop(GameManager.GameCategory.COOP)

func _on_add_player_pressed() -> void:
	if GameManager.players.size() < 4:
		var new_id = GameManager.players.size()
		var p = PlayerData.new()
		p.player_id = new_id
		p.player_name = ["Bubbles", "Finley", "Nemo", "Grim"][new_id]
		GameManager.players.append(p)
		drop_player_fish(new_id, p.player_name)
