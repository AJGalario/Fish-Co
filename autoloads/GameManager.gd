extends Node

enum GameCategory { COOP, VS }
enum GameState { MAIN_MENU, LOBBY_AQUARIUM, MINIGAME, ROUND_RESULTS, PODIUM }

var current_state: GameState = GameState.MAIN_MENU
var current_category: GameCategory = GameCategory.VS

# Match Configuration
var match_config: MatchConfig = MatchConfig.new()

# Array of PlayerData
var players: Array[PlayerData] = []
var current_round: int = 0
var max_rounds: int = 4

# All possible VS Minigames
var all_vs_minigames: Array[String] = [
	"res://scenes/minigames/mg_typing_race/TypingRace.tscn",
	"res://scenes/minigames/mg_flappy_fish/FlappyFish.tscn",
	"res://scenes/minigames/mg_debris_dash/DebrisDash.tscn",
	"res://scenes/minigames/mg_pellet_catch/PelletCatch.tscn"
]

# Co-op Minigame catalog
var coop_minigames: Array[String] = [
	"res://scenes/minigames/mg_pico_leak/PicoLeak.tscn"
]

# Randomized queue to prevent repeating minigames until all have been played
var _shuffled_queue: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func setup_local_players(human_count: int = 2) -> void:
	players.clear()
	var names = ["Bubbles", "Finley", "Nemo", "Grim"]
	
	# Human players
	for i in range(human_count):
		var p = PlayerData.new()
		p.player_id = i
		p.peer_id = 1
		p.player_name = names[i % names.size()]
		p.character_skin = i
		p.is_local_controlled = true
		p.is_bot = false
		players.append(p)
		
	# Populate Bots according to match configuration
	var total_slots = 4
	var bots_to_add = min(match_config.bot_count, total_slots - players.size())
	for b in range(bots_to_add):
		var bot_id = players.size()
		var bot = PlayerData.new()
		bot.player_id = bot_id
		bot.peer_id = 1
		bot.player_name = "Bot " + ["Angler", "Manta", "Sharky", "Barnaby"][b % 4]
		bot.character_skin = bot_id
		bot.is_local_controlled = false
		bot.is_bot = true
		bot.bot_difficulty = match_config.bot_difficulty
		players.append(bot)

func start_game_loop(category: GameCategory = GameCategory.VS) -> void:
	current_category = category
	current_round = 0
	for p in players:
		p.total_score = 0
	_build_shuffled_queue()
	next_round()

func _build_shuffled_queue() -> void:
	var pool = []
	if current_category == GameCategory.VS:
		# Use user-selected enabled minigames if available
		if match_config.enabled_minigames.size() > 0:
			pool = match_config.enabled_minigames.duplicate()
		else:
			pool = all_vs_minigames.duplicate()
	else:
		pool = coop_minigames.duplicate()
		
	_shuffled_queue = pool.duplicate()
	_shuffled_queue.shuffle()

func next_round() -> void:
	current_round += 1
	var max_r = match_config.enabled_minigames.size() if current_category == GameCategory.VS else coop_minigames.size()
	
	if current_round > max_r or current_round > max_rounds:
		show_podium()
		return
	
	if _shuffled_queue.is_empty():
		_build_shuffled_queue()
		
	var chosen_scene = _shuffled_queue.pop_front()
	current_state = GameState.MINIGAME
	get_tree().change_scene_to_file(chosen_scene)

func complete_minigame(ranked_player_ids: Array) -> void:
	# Award scores: 1st: 3pts, 2nd: 2pts, 3rd: 1pt, 4th: 0pt
	var points = [3, 2, 1, 0]
	for i in range(ranked_player_ids.size()):
		var pid = ranked_player_ids[i]
		var pd = get_player_data(pid)
		if pd:
			var pts = points[min(i, points.size() - 1)]
			pd.total_score += pts
	
	current_state = GameState.ROUND_RESULTS
	get_tree().change_scene_to_file("res://scenes/ui/RoundResults.tscn")

func show_podium() -> void:
	current_state = GameState.PODIUM
	get_tree().change_scene_to_file("res://scenes/ui/Podium.tscn")

func get_player_data(player_id: int) -> PlayerData:
	for p in players:
		if p.player_id == player_id:
			return p
	return null
