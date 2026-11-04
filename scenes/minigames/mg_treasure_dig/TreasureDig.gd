extends MinigameBase

## SUNKEN SCRAMBLE — Quick-Brickles-style button sequence game
##
## Sequences store INDICES (0-3) into each player's key pool.
## Labels are looked up directly by index — no modulo tricks.
## Press correct key → dig advances. Wrong key → DAZED 1.2 s.
## Complete 5-key sequence → earn 1 treasure chest.
## Most chests at time-up → highest rank.

# ── Sequence settings ───────────────────────────────────────────
const SEQ_LENGTH       = 5
const DAZE_DURATION    = 1.2
const TREASURE_PER_SEQ = 1

# ── Key pools per player (untyped arrays — KEY_* are ints) ──────
# Index 0 1 2 3 maps one-to-one with KEY_LABELS_P below.
const KEY_POOL_P = [
	[KEY_W,    KEY_S,    KEY_A,    KEY_D    ],  # P0  WASD
	[KEY_UP,   KEY_DOWN, KEY_LEFT, KEY_RIGHT],  # P1  Arrows
	[KEY_I,    KEY_K,    KEY_J,    KEY_L    ],  # P2  IJKL
	[KEY_KP_8, KEY_KP_5, KEY_KP_4, KEY_KP_6],  # P3  Numpad
]

# ── Display labels — exact same index order as KEY_POOL_P ───────
# Index order: up, down, left, right  (matches GP_POOL_P* action order too)
const KEY_LABELS_P = [
	["W",  "S",  "A",  "D"],
	["\u2191",  "\u2193",  "\u2190",  "\u2192"],
	["I",  "K",  "J",  "L"],
	["8",  "5",  "4",  "6"],
]

# Labels shown when a player slot is using a gamepad (d-pad arrows)
const GP_LABELS = ["\u25b2", "\u25bc", "\u25c4", "\u25ba"]  # up down left right (dpad symbols)

# ── Gamepad action names for P2 and P3 ──────────────────────────
const GP_POOL_P2 = ["p3_up", "p3_down", "p3_left", "p3_right"]
const GP_POOL_P3 = ["p4_up", "p4_down", "p4_left", "p4_right"]

# X-centre of each player's column (matches spawn points in .tscn)
const PLAYER_COL_X = [275.0, 675.0, 1125.0, 1575.0]
# Y of the sequence panel strip — below the sand/dig sites
const SEQ_PANEL_Y  = 862.0

# ── Per-player runtime state ────────────────────────────────────
var _treasure_count = {}   # pid -> int
var _sequences      = {}   # pid -> Array of indices 0-3
var _seq_index      = {}   # pid -> int  (next slot to press)
var _dazed          = {}   # pid -> bool
var _last_seq_time  = {}   # pid -> float (tiebreaker)
var _fish_nodes     = {}   # pid -> FishPlayer
var _seq_rows       = {}   # pid -> Array of PanelContainers
var _status_labels  = {}   # pid -> Label
var _chest_labels   = {}   # pid -> Label
var _time_elapsed   = 0.0

# ── StyleBoxes (duplicated per-panel to avoid shared references) ─
var _style_normal  : StyleBoxFlat
var _style_current : StyleBoxFlat
var _style_done    : StyleBoxFlat
var _style_daze    : StyleBoxFlat


# ══════════════════════════════════════════════════════════════
func _ready() -> void:
	minigame_title        = "Sunken Scramble"
	minigame_instructions = "PRESS THE KEYS IN ORDER!\nDig up sunken treasure faster than your rivals!"
	_build_styleboxes()
	super._ready()


# ── StyleBox factory ────────────────────────────────────────────
func _build_styleboxes() -> void:
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color         = Color(0.08, 0.10, 0.18, 0.92)
	_style_normal.border_color     = Color(0.60, 0.65, 0.75, 0.80)
	_style_normal.set_border_width_all(2)
	_style_normal.set_corner_radius_all(6)

	_style_current = StyleBoxFlat.new()
	_style_current.bg_color        = Color(0.14, 0.18, 0.30, 0.95)
	_style_current.border_color    = Color(0.95, 0.97, 1.00, 1.00)
	_style_current.set_border_width_all(3)
	_style_current.set_corner_radius_all(6)

	_style_done = StyleBoxFlat.new()
	_style_done.bg_color           = Color(0.07, 0.35, 0.15, 0.90)
	_style_done.border_color       = Color(0.20, 0.85, 0.45, 0.90)
	_style_done.set_border_width_all(2)
	_style_done.set_corner_radius_all(6)

	_style_daze = StyleBoxFlat.new()
	_style_daze.bg_color           = Color(0.25, 0.06, 0.06, 0.92)
	_style_daze.border_color       = Color(1.00, 0.25, 0.25, 1.00)
	_style_daze.set_border_width_all(3)
	_style_daze.set_corner_radius_all(6)


# ══════════════════════════════════════════════════════════════
#  Player setup
# ══════════════════════════════════════════════════════════════
func setup_players() -> void:
	super.setup_players()

	for child in get_children():
		if child is FishPlayer:
			_fish_nodes[child.player_id] = child
			child.set_physics_process(false)

	for pd in GameManager.players:
		var pid = pd.player_id
		_treasure_count[pid] = 0
		_dazed[pid]          = false
		_last_seq_time[pid]  = 0.0
		_seq_index[pid]      = 0
		_sequences[pid]      = _generate_sequence(pid)

	_build_seq_panels()


# Block MinigameBase.start_countdown() from re-enabling fish physics.
# TreasureDig is stationary — fish must NEVER move.
func _set_all_fish_physics(_enabled: bool) -> void:
	pass


# Block MinigameBase._on_player_died from ending the game early.
# TreasureDig ends only when the timer expires.
func _on_player_died(_player_id: int) -> void:
	pass


# Override countdown so the GO-label says "DIG!" and physics stays OFF.
func start_countdown() -> void:
	is_active = false
	if instructions_label:
		instructions_label.visible = true

	for count in [3, 2, 1]:
		if instructions_label:
			instructions_label.text = "%s\n\nStarting in %d..." % [minigame_instructions, count]
		await get_tree().create_timer(1.0).timeout

	if instructions_label:
		instructions_label.text = "DIG!"

	# DO NOT call _set_all_fish_physics(true) — fish stay stationary
	is_active = true

	await get_tree().create_timer(0.6).timeout
	if instructions_label:
		instructions_label.visible = false


# ── Sequence generation — stores indices (0 to pool_size-1) ────
func _generate_sequence(player_id: int) -> Array:
	var pool_size = KEY_POOL_P[player_id % KEY_POOL_P.size()].size()
	var seq  = []
	var prev = -1
	for _i in range(SEQ_LENGTH):
		var pick = prev
		while pick == prev:
			pick = randi() % pool_size
		seq.append(pick)
		prev = pick
	return seq


# ══════════════════════════════════════════════════════════════
#  HUD — per-player panel built directly onto $HUD CanvasLayer
# ══════════════════════════════════════════════════════════════
func _build_seq_panels() -> void:
	var hud : CanvasLayer = $HUD

	for pd in GameManager.players:
		var pid   = pd.player_id
		var col_x = PLAYER_COL_X[pid % PLAYER_COL_X.size()]
		# Use d-pad symbols if on a gamepad, otherwise keyboard labels
		var lbls  = GP_LABELS if pd.device_id >= 0 else KEY_LABELS_P[pid % KEY_LABELS_P.size()]

		# Root container free-positioned in screen space on the CanvasLayer
		var root : VBoxContainer = VBoxContainer.new()
		root.name = "SeqPanel_P%d" % pid
		root.set_anchors_preset(Control.PRESET_TOP_LEFT)
		root.set_position(Vector2(col_x - 115.0, SEQ_PANEL_Y))
		root.custom_minimum_size = Vector2(230, 0)
		root.add_theme_constant_override("separation", 6)
		hud.add_child(root)

		# Chest / score label
		var chest_lbl : Label = Label.new()
		chest_lbl.text               = "Chest: 0"
		chest_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chest_lbl.add_theme_font_size_override("font_size", 16)
		chest_lbl.add_theme_color_override("font_color", _player_color(pid))
		chest_lbl.custom_minimum_size = Vector2(230, 0)
		root.add_child(chest_lbl)
		_chest_labels[pid] = chest_lbl

		# Key-button row
		var row : HBoxContainer = HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 6)
		root.add_child(row)

		var btn_list = []
		for i in range(SEQ_LENGTH):
			var btn : PanelContainer = PanelContainer.new()
			btn.custom_minimum_size = Vector2(42, 42)
			btn.add_theme_stylebox_override("panel", _style_normal.duplicate())

			var key_lbl : Label = Label.new()
			key_lbl.name                = "Lbl"
			key_lbl.text                = lbls[_sequences[pid][i]]
			key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			key_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
			key_lbl.add_theme_font_size_override("font_size", 20)
			key_lbl.add_theme_color_override("font_color", Color(0.80, 0.82, 0.90))
			btn.add_child(key_lbl)
			row.add_child(btn)
			btn_list.append(btn)

		_seq_rows[pid] = btn_list

		# DAZED status label
		var status : Label = Label.new()
		status.text               = ""
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status.add_theme_font_size_override("font_size", 15)
		status.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		root.add_child(status)
		_status_labels[pid] = status

	_refresh_all_seq_displays()


# ══════════════════════════════════════════════════════════════
#  Keyboard input  (_unhandled_key_input fires ONLY for key events)
#  Skips any player whose device_id >= 0 (they use a gamepad).
# ══════════════════════════════════════════════════════════════
func _unhandled_key_input(event: InputEvent) -> void:
	if not is_active:
		return

	var ke = event as InputEventKey
	if ke == null or not ke.pressed or ke.echo:
		return

	for pd in GameManager.players:
		if pd.is_bot:
			continue
		var pid = pd.player_id
		# Skip players who are on a gamepad — they're polled in _process
		if pd.device_id >= 0:
			continue
		if pid >= KEY_POOL_P.size():
			continue
		if _dazed.get(pid, false):
			continue
		var pool = KEY_POOL_P[pid]
		for idx in range(pool.size()):
			if ke.physical_keycode == pool[idx]:
				_handle_key_input(pid, idx)
				get_viewport().set_input_as_handled()
				break


# ══════════════════════════════════════════════════════════════
#  Game loop — polls gamepad inputs for any player on a controller
# ══════════════════════════════════════════════════════════════
func _process(delta: float) -> void:
	super._process(delta)
	if not is_active:
		return

	_time_elapsed += delta

	# Action pools indexed by player slot (p3_* and p4_*)
	var gp_action_pools = [GP_POOL_P2, GP_POOL_P3]

	for pd in GameManager.players:
		if pd.is_bot:
			continue
		var pid = pd.player_id
		# Only process players on a gamepad
		if pd.device_id < 0:
			continue
		if not _sequences.has(pid):
			continue
		if _dazed.get(pid, false):
			continue
		# Pick the action pool for this slot (pid 2 → GP_POOL_P2, pid 3 → GP_POOL_P3)
		var pool_idx = pid - 2
		if pool_idx < 0 or pool_idx >= gp_action_pools.size():
			continue
		var actions = gp_action_pools[pool_idx]
		for idx in range(actions.size()):
			if Input.is_action_just_pressed(actions[idx]):
				_handle_key_input(pid, idx)
				break


# ── Dispatch ────────────────────────────────────────────────────
func _handle_key_input(player_id: int, pressed_index: int) -> void:
	if not _sequences.has(player_id):
		return
	var expected = _sequences[player_id][_seq_index[player_id]]
	if pressed_index == expected:
		_on_correct_key(player_id)
	else:
		_on_wrong_key(player_id)


# ══════════════════════════════════════════════════════════════
#  Game logic
# ══════════════════════════════════════════════════════════════
func _on_correct_key(player_id: int) -> void:
	_seq_index[player_id] += 1
	_refresh_seq_display(player_id)

	if _seq_index[player_id] >= SEQ_LENGTH:
		_treasure_count[player_id] += TREASURE_PER_SEQ
		_last_seq_time[player_id]   = _time_elapsed
		_seq_index[player_id]       = 0
		_sequences[player_id]       = _generate_sequence(player_id)
		_refresh_seq_display(player_id)
		_update_chest_label(player_id)
		_play_treasure_fanfare(player_id)


func _on_wrong_key(player_id: int) -> void:
	if _dazed.get(player_id, false):
		return
	_dazed[player_id] = true
	_show_daze_visual(player_id, true)
	_set_status(player_id, "DAZED!")

	await get_tree().create_timer(DAZE_DURATION).timeout

	# Guard: game may have ended during the await
	if not is_instance_valid(self) or not is_active:
		return
	if not _dazed.has(player_id):
		return

	_dazed[player_id] = false
	_show_daze_visual(player_id, false)
	_set_status(player_id, "")


# ══════════════════════════════════════════════════════════════
#  Visual refresh
# ══════════════════════════════════════════════════════════════
func _refresh_all_seq_displays() -> void:
	for pid in _sequences:
		_refresh_seq_display(pid)


func _refresh_seq_display(player_id: int) -> void:
	var btns = _seq_rows.get(player_id, [])
	var pd   = GameManager.get_player_data(player_id)
	var lbls = GP_LABELS if (pd and pd.device_id >= 0) else KEY_LABELS_P[player_id % KEY_LABELS_P.size()]
	var seq  = _sequences.get(player_id, [])
	var cur  = _seq_index.get(player_id, 0)

	for i in range(btns.size()):
		var btn = btns[i]
		if not is_instance_valid(btn):
			continue
		var lbl = btn.get_node_or_null("Lbl")
		if not lbl:
			continue

		if i < seq.size():
			lbl.text = lbls[seq[i]]

		if i < cur:
			btn.add_theme_stylebox_override("panel", _style_done.duplicate())
			lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
			lbl.add_theme_font_size_override("font_size", 17)
		elif i == cur:
			btn.add_theme_stylebox_override("panel", _style_current.duplicate())
			lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
			lbl.add_theme_font_size_override("font_size", 22)
		else:
			btn.add_theme_stylebox_override("panel", _style_normal.duplicate())
			lbl.add_theme_color_override("font_color", Color(0.52, 0.55, 0.65))
			lbl.add_theme_font_size_override("font_size", 20)


func _update_chest_label(player_id: int) -> void:
	if not _chest_labels.has(player_id):
		return
	var lbl = _chest_labels[player_id]
	if is_instance_valid(lbl):
		var n = _treasure_count[player_id]
		lbl.text = "Chests: %d" % n


func _show_daze_visual(player_id: int, dazed: bool) -> void:
	var fish = _fish_nodes.get(player_id)
	if fish and is_instance_valid(fish):
		fish.modulate = Color(1.0, 0.35, 0.35) if dazed else Color(1.0, 1.0, 1.0)

	var btns = _seq_rows.get(player_id, [])
	for btn in btns:
		if not is_instance_valid(btn):
			continue
		if dazed:
			btn.add_theme_stylebox_override("panel", _style_daze.duplicate())
	if not dazed:
		_refresh_seq_display(player_id)


func _set_status(player_id: int, text: String) -> void:
	if not _status_labels.has(player_id):
		return
	var lbl = _status_labels[player_id]
	if is_instance_valid(lbl):
		lbl.text = text


func _play_treasure_fanfare(player_id: int) -> void:
	var fish = _fish_nodes.get(player_id)
	if not fish or not is_instance_valid(fish):
		return
	fish.modulate = Color(1.0, 0.95, 0.3)
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(fish):
		fish.modulate = Color(1.0, 1.0, 1.0)


func _player_color(pid: int) -> Color:
	return PlayerData.PLAYER_COLORS[pid % PlayerData.PLAYER_COLORS.size()]


# ══════════════════════════════════════════════════════════════
#  Finish — rank by chests desc, tiebreak by earlier last-seq
# ══════════════════════════════════════════════════════════════
func finish_minigame() -> void:
	if not is_active:
		return
	is_active = false

	# Collect and sort player IDs
	var pids = _treasure_count.keys()

	# Bubble sort (avoids typed lambda issues across GDScript versions)
	for i in range(pids.size()):
		for j in range(pids.size() - 1 - i):
			var a = pids[j]
			var b = pids[j + 1]
			var should_swap = false
			if _treasure_count[a] < _treasure_count[b]:
				should_swap = true
			elif _treasure_count[a] == _treasure_count[b]:
				if _last_seq_time[a] > _last_seq_time[b]:
					should_swap = true
			if should_swap:
				pids[j]     = b
				pids[j + 1] = a

	GameManager.call_deferred("complete_minigame", pids)
