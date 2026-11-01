extends Control

# Configuration Modal for Match Settings
signal config_saved
signal config_discarded

@onready var bg_option: OptionButton = $Panel/Margin/VBox/Grid/BGOption
@onready var time_slider: HSlider = $Panel/Margin/VBox/Grid/TimeBox/TimeSlider
@onready var time_val_label: Label = $Panel/Margin/VBox/Grid/TimeBox/TimeValueLabel

# Minigame Checkboxes
@onready var check_typing: CheckBox = $Panel/Margin/VBox/MinigameBox/CheckTyping
@onready var check_flappy: CheckBox = $Panel/Margin/VBox/MinigameBox/CheckFlappy
@onready var check_debris: CheckBox = $Panel/Margin/VBox/MinigameBox/CheckDebris
@onready var check_pellet: CheckBox = $Panel/Margin/VBox/MinigameBox/CheckPellet

# Bots
@onready var bot_count_option: OptionButton = $Panel/Margin/VBox/Grid/BotCountOption
@onready var bot_diff_option: OptionButton = $Panel/Margin/VBox/Grid/BotDiffOption

# Actions
@onready var save_btn: Button = $Panel/Margin/VBox/ButtonRow/SaveBtn
@onready var discard_btn: Button = $Panel/Margin/VBox/ButtonRow/DiscardBtn

var temp_config: MatchConfig

func _ready() -> void:
	_setup_ui_options()
	if time_slider:
		time_slider.value_changed.connect(_on_time_changed)
	if save_btn:
		save_btn.pressed.connect(_on_save_pressed)
	if discard_btn:
		discard_btn.pressed.connect(_on_discard_pressed)

func open_settings() -> void:
	# Clone current config to allow clean discarding
	temp_config = GameManager.match_config.duplicate_config()
	_load_config_into_ui(temp_config)
	visible = true

func _setup_ui_options() -> void:
	if bg_option:
		bg_option.clear()
		bg_option.add_item("Deep Ocean Blue", 0)
		bg_option.add_item("Vibrant Coral Reef", 1)
		bg_option.add_item("Sunken Ruins Teal", 2)
		bg_option.add_item("Midnight Abyss", 3)
	
	if bot_count_option:
		bot_count_option.clear()
		bot_count_option.add_item("0 Bots (Humans Only)", 0)
		bot_count_option.add_item("1 Bot", 1)
		bot_count_option.add_item("2 Bots", 2)
		bot_count_option.add_item("3 Bots", 3)
	
	if bot_diff_option:
		bot_diff_option.clear()
		bot_diff_option.add_item("Easy", 0)
		bot_diff_option.add_item("Medium", 1)
		bot_diff_option.add_item("Hard", 2)

func _load_config_into_ui(cfg: MatchConfig) -> void:
	if bg_option:
		bg_option.selected = int(cfg.background_theme)
	if time_slider:
		time_slider.value = clampf(cfg.round_time, 30.0, 60.0)
	if time_val_label and time_slider:
		time_val_label.text = "%d sec" % int(time_slider.value)
	
	if check_typing:
		check_typing.button_pressed = "res://scenes/minigames/mg_typing_race/TypingRace.tscn" in cfg.enabled_minigames
	if check_flappy:
		check_flappy.button_pressed = "res://scenes/minigames/mg_flappy_fish/FlappyFish.tscn" in cfg.enabled_minigames
	if check_debris:
		check_debris.button_pressed = "res://scenes/minigames/mg_debris_dash/DebrisDash.tscn" in cfg.enabled_minigames
	if check_pellet:
		check_pellet.button_pressed = "res://scenes/minigames/mg_pellet_catch/PelletCatch.tscn" in cfg.enabled_minigames
	
	if bot_count_option:
		bot_count_option.selected = cfg.bot_count
	if bot_diff_option:
		bot_diff_option.selected = int(cfg.bot_difficulty)

func _on_time_changed(val: float) -> void:
	if time_val_label:
		time_val_label.text = "%d sec" % int(val)

func _on_save_pressed() -> void:
	if bg_option:
		GameManager.match_config.background_theme = bg_option.selected as MatchConfig.BackgroundTheme
	if time_slider:
		GameManager.match_config.round_time = time_slider.value
	
	var selected_games: Array[String] = []
	if check_typing and check_typing.button_pressed:
		selected_games.append("res://scenes/minigames/mg_typing_race/TypingRace.tscn")
	if check_flappy and check_flappy.button_pressed:
		selected_games.append("res://scenes/minigames/mg_flappy_fish/FlappyFish.tscn")
	if check_debris and check_debris.button_pressed:
		selected_games.append("res://scenes/minigames/mg_debris_dash/DebrisDash.tscn")
	if check_pellet and check_pellet.button_pressed:
		selected_games.append("res://scenes/minigames/mg_pellet_catch/PelletCatch.tscn")
		
	if selected_games.is_empty():
		selected_games = GameManager.all_vs_minigames.duplicate()
	GameManager.match_config.enabled_minigames = selected_games
	
	if bot_count_option:
		GameManager.match_config.bot_count = bot_count_option.selected
	if bot_diff_option:
		GameManager.match_config.bot_difficulty = bot_diff_option.selected as PlayerData.BotDifficulty
	
	visible = false
	config_saved.emit()

func _on_discard_pressed() -> void:
	visible = false
	config_discarded.emit()
