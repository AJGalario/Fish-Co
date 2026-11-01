class_name PlayerData
extends Resource

enum BotDifficulty { EASY, MEDIUM, HARD }

@export var player_id: int = 0          # 0-3
@export var peer_id: int = 1            # Network peer ID (1 is host / local)
@export var player_name: String = "Puffer"
@export var character_skin: int = 0     # 0: Puffer, 1: Swordfish, 2: Clownfish, 3: Anglerfish
@export var total_score: int = 0
@export var is_alive: bool = true
@export var is_local_controlled: bool = true

# Bot Configuration
@export var is_bot: bool = false
@export var bot_difficulty: BotDifficulty = BotDifficulty.MEDIUM

# Oxygen/energy mechanics
@export var oxygen: float = 100.0

const PLAYER_COLORS: Array[Color] = [
	Color("#FFD166"), # P1: Gold / Yellow
	Color("#06D6A0"), # P2: Aquamarine / Mint
	Color("#118AB2"), # P3: Deep Ocean Cyan
	Color("#EF476F"), # P4: Coral Pink
]

func get_color() -> Color:
	return PLAYER_COLORS[player_id % PLAYER_COLORS.size()]

func reset_for_round() -> void:
	is_alive = true
	oxygen = 100.0
