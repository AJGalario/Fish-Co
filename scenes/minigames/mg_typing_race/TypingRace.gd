extends MinigameBase

# Minigame 1: Typing Race with Real-time Character Highlighting (RichTextLabel)
# Correct typed prefix turns GREEN [color=#2ecc71]
# First mistyped character turns RED [color=#e74c3c]
# Remaining untyped text stays DIM WHITE [color=#95a5a6]

const TARGET_PARAGRAPH: String = "The swift colorful fish dashes through bubbles and coral reefs to escape the net!"

@onready var rich_prompt: RichTextLabel = $HUD/TypingContainer/RichPromptLabel
@onready var input_edit: LineEdit = $HUD/TypingContainer/PlayerLineEdit
@onready var lane_positions: Node2D = $LanePositions

var player_progress: Dictionary = {} # player_id -> float (0.0 to 1.0)
var fish_nodes: Dictionary = {}
var finished_order: Array = []

func _ready() -> void:
	minigame_title = "Typing Reef Race"
	minigame_instructions = "TYPE THE SENTENCE ACCURATELY TO SWIM FORWARD!"
	round_time = 45.0
	super._ready()
	
	_render_highlighted_text("")
	if input_edit:
		input_edit.text_changed.connect(_on_text_changed)
		input_edit.grab_focus()

func setup_players() -> void:
	super.setup_players()
	for i in range(GameManager.players.size()):
		var pid = GameManager.players[i].player_id
		player_progress[pid] = 0.0
	
	# Cache fish nodes and disable direct WASD movement
	for child in get_children():
		if child is FishPlayer:
			fish_nodes[child.player_id] = child
			child.set_physics_process(false)

func _on_text_changed(new_text: String) -> void:
	if not is_active:
		return
		
	_render_highlighted_text(new_text)
	
	# Calculate match count from the beginning
	var match_count = 0
	var min_len = min(new_text.length(), TARGET_PARAGRAPH.length())
	var has_error = false
	
	for i in range(min_len):
		if not has_error and new_text[i] == TARGET_PARAGRAPH[i]:
			match_count += 1
		else:
			has_error = true
			
	var p0_id = GameManager.players[0].player_id
	var progress = float(match_count) / float(TARGET_PARAGRAPH.length())
	_update_player_race_position(p0_id, progress)
	
	if match_count >= TARGET_PARAGRAPH.length() and not has_error:
		if p0_id not in finished_order:
			finished_order.append(p0_id)
			_check_all_finished()

func _render_highlighted_text(typed: String) -> void:
	if not rich_prompt:
		return
		
	var bbcode = ""
	var has_mismatch = false
	
	for i in range(TARGET_PARAGRAPH.length()):
		var target_char = TARGET_PARAGRAPH[i]
		# Escaping for BBCode safety
		var display_char = target_char
		if display_char == "[":
			display_char = "[lb]"
			
		if i < typed.length():
			if not has_mismatch and typed[i] == target_char:
				# Correct character -> GREEN
				bbcode += "[color=#2ecc71][b]" + display_char + "[/b][/color]"
			else:
				# Mistyped character -> RED
				has_mismatch = true
				bbcode += "[color=#e74c3c][underline][b]" + display_char + "[/b][/underline][/color]"
		else:
			# Untyped character -> MUTED WHITE
			bbcode += "[color=#bdc3c7]" + display_char + "[/color]"
			
	rich_prompt.text = bbcode

func _process(delta: float) -> void:
	super._process(delta)
	if not is_active:
		return
		
	# Other players / AI advance naturally
	for i in range(1, GameManager.players.size()):
		var pid = GameManager.players[i].player_id
		var curr = player_progress.get(pid, 0.0)
		var increment = randf_range(0.015, 0.035) * delta
		var next_prog = minf(1.0, curr + increment)
		_update_player_race_position(pid, next_prog)
		if next_prog >= 1.0 and pid not in finished_order:
			finished_order.append(pid)
			_check_all_finished()

func _update_player_race_position(player_id: int, progress: float) -> void:
	player_progress[player_id] = progress
	if fish_nodes.has(player_id):
		var start_x = 300.0
		var end_x = 1620.0
		var fish = fish_nodes[player_id]
		fish.position.x = lerp(start_x, end_x, progress)

func _check_all_finished() -> void:
	if finished_order.size() >= GameManager.players.size():
		finish_minigame_with_rankings(finished_order)

func finish_minigame() -> void:
	var remaining = []
	for pid in player_progress:
		if pid not in finished_order:
			remaining.append(pid)
	remaining.sort_custom(func(a, b): return player_progress[a] > player_progress[b])
	
	var final_rank = finished_order.duplicate()
	final_rank.append_array(remaining)
	finish_minigame_with_rankings(final_rank)

func finish_minigame_with_rankings(rankings: Array) -> void:
	if not is_active:
		return
	is_active = false
	GameManager.complete_minigame(rankings)
