extends Control

## ─────────────────────────────────────────────────────────────
##  AquariumLobby — the pre-game aquarium tank screen.
##
##  When a player is added (human or bot) a "hand" drops their
##  fish from the top into the tank.  Each fish is placed in its
##  own column so they never collide on entry.
##
##  · Human fish  → player can move them freely in 6 directions
##                   to identify themselves ("MOVE TO CLAIM!")
##  · Bot fish    → wander autonomously in 6 directions
## ─────────────────────────────────────────────────────────────

const LobbyFishScript = preload("res://scenes/aquarium_lobby/LobbyFish.gd")

@onready var tank_area       : Control      = $TankArea
@onready var water_bg        : ColorRect    = $TankArea/WaterBackground
@onready var fish_container  : Node2D       = $TankArea/FishContainer
@onready var player_count_label : Label     = $HUD/Margin/VBox/PlayerCountLabel
@onready var controls_hint   : Label        = $HUD/Margin/VBox/ControlsHint
@onready var hand_visual     : ColorRect    = $HandVisual
@onready var settings_modal  : Control      = $SettingsLayer/MatchSettingsDialog

# ── Layout constants ───────────────────────────────────────────
# 4 fixed columns inside the 1920-wide tank so fish never overlap
const COLUMNS      : Array[float] = [340.0, 700.0, 1060.0, 1420.0]
const SPAWN_Y      : float        = 160.0   # just below hand drop height
const TANK_LEFT    : float        = 60.0
const TANK_RIGHT   : float        = 1860.0
const TANK_TOP     : float        = 60.0
const TANK_BOTTOM  : float        = 850.0

# Track per-player lobby fish nodes
var _lobby_fish : Dictionary = {}   # player_id -> LobbyFish

# ── Ready ──────────────────────────────────────────────────────
func _ready() -> void:
	EventBus.network_player_connected.connect(_on_network_player_connected)

	if settings_modal:
		settings_modal.config_saved.connect(_on_config_saved)
		settings_modal.visible = false

	_apply_current_theme()
	_refresh_lobby_ui()
	_populate_initial_fishes()


# ── Theme ──────────────────────────────────────────────────────
func _apply_current_theme() -> void:
	if water_bg and GameManager.match_config:
		water_bg.color = GameManager.match_config.get_bg_color()


# ── Config saved callback ──────────────────────────────────────
func _on_config_saved() -> void:
	_apply_current_theme()
	# Re-setup players with any newly configured bots
	GameManager.setup_local_players(2)
	_populate_initial_fishes()
	_refresh_lobby_ui()


# ── Network callback ───────────────────────────────────────────
func _on_network_player_connected(peer_id: int, p_data: Dictionary) -> void:
	_refresh_lobby_ui()
	var idx : int = GameManager.players.size() - 1
	_drop_fish(idx)


# ── Populate all current players ──────────────────────────────
func _populate_initial_fishes() -> void:
	# Remove existing lobby fish
	for child in fish_container.get_children():
		child.queue_free()
	_lobby_fish.clear()

	for i in range(GameManager.players.size()):
		_drop_fish(i)


# ── Core: drop one fish into its column ───────────────────────
func _drop_fish(player_idx: int) -> void:
	if player_idx < 0 or player_idx >= GameManager.players.size():
		return

	var pd    : PlayerData = GameManager.players[player_idx]
	var col_x : float      = COLUMNS[player_idx % COLUMNS.size()]

	# ── Hand animation ─────────────────────────────────────────
	hand_visual.position = Vector2(col_x - 40.0, -140.0)
	hand_visual.visible  = true

	var tween : Tween = create_tween()
	# Hand reaches down to just above the water surface
	tween.tween_property(hand_visual, "position:y", 100.0, 0.38)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Release fish
	tween.tween_callback(func() -> void:
		_spawn_lobby_fish(pd, col_x)
	)
	# Hand retracts
	tween.tween_property(hand_visual, "position:y", -160.0, 0.35)\
		.set_delay(0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: hand_visual.visible = false)


# ── Spawn the LobbyFish node ───────────────────────────────────
func _spawn_lobby_fish(pd: PlayerData, col_x: float) -> void:
	# Remove any stale fish for this player first
	if _lobby_fish.has(pd.player_id):
		var old : Node = _lobby_fish[pd.player_id]
		if is_instance_valid(old):
			old.queue_free()
		_lobby_fish.erase(pd.player_id)

	# Build LobbyFish
	var fish : CharacterBody2D = CharacterBody2D.new()
	fish.position = Vector2(col_x, SPAWN_Y)
	fish.set_script(LobbyFishScript)

	# Assign identity BEFORE adding to tree so _ready() reads them
	fish.player_id    = pd.player_id
	fish.is_bot       = pd.is_bot
	fish.player_name  = "%s  P%d" % [pd.player_name, pd.player_id + 1]
	fish.player_color = PlayerData.PLAYER_COLORS[pd.player_id % PlayerData.PLAYER_COLORS.size()]
	fish.tank_left    = TANK_LEFT
	fish.tank_right   = TANK_RIGHT
	fish.tank_top     = TANK_TOP
	fish.tank_bottom  = TANK_BOTTOM

	# Add a collision shape so move_and_slide works without errors,
	# but lobby fish don't block each other (use separate layers)
	var shape_owner : CollisionShape2D = CollisionShape2D.new()
	var circ        : CircleShape2D    = CircleShape2D.new()
	circ.radius = 22.0
	shape_owner.shape = circ
	fish.add_child(shape_owner)

	# Disable collision vs other fish — they're only here for visuals
	fish.collision_layer = 0
	fish.collision_mask  = 0

	fish_container.add_child(fish)
	_lobby_fish[pd.player_id] = fish

	# Entry drop tween: fish falls into place with a small bounce
	fish.position.y = SPAWN_Y - 160.0
	var entry : Tween = create_tween()
	entry.tween_property(fish, "position:y", SPAWN_Y, 0.45)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ── HUD refresh ────────────────────────────────────────────────
func _refresh_lobby_ui() -> void:
	if player_count_label:
		player_count_label.text = "🐠 Fishes in Tank: %d / 4   |   Theme: %s   |   Round: %ds" % [
			GameManager.players.size(),
			MatchConfig.THEME_NAMES.get(GameManager.match_config.background_theme, "Ocean"),
			int(GameManager.match_config.round_time)
		]

	if controls_hint:
		# Show per-player control reminder
		var lines : PackedStringArray = []
		for pd in GameManager.players:
			if pd.is_bot:
				lines.append("P%d [%s] 🤖 Bot — auto-swim" % [pd.player_id + 1, pd.player_name])
			else:
				var keys : String = _get_control_keys(pd.player_id)
				lines.append("P%d [%s] — %s" % [pd.player_id + 1, pd.player_name, keys])
		controls_hint.text = "   ".join(lines)


func _get_control_keys(pid: int) -> String:
	match pid:
		0: return "WASD + Space"
		1: return "Arrow keys + ↑"
		2: return "IJKL + I"
		3: return "Numpad 8456"
		_: return "Gamepad"


# ── Button callbacks ───────────────────────────────────────────
func _on_settings_pressed() -> void:
	if settings_modal:
		settings_modal.open_settings()


func _on_vs_mode_pressed() -> void:
	GameManager.start_game_loop(GameManager.GameCategory.VS)


func _on_coop_mode_pressed() -> void:
	GameManager.start_game_loop(GameManager.GameCategory.COOP)


func _on_add_player_pressed() -> void:
	if GameManager.players.size() >= 4:
		return

	var new_id : int       = GameManager.players.size()
	var p      : PlayerData = PlayerData.new()
	p.player_id           = new_id
	p.player_name         = ["Bubbles", "Finley", "Nemo", "Grim"][new_id % 4]
	p.is_local_controlled = true
	p.is_bot              = false
	GameManager.players.append(p)

	_drop_fish(new_id)
	_refresh_lobby_ui()
