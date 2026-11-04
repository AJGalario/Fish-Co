class_name MatchConfig
extends Resource

enum BackgroundTheme { DEEP_OCEAN, CORAL_REEF, SUNKEN_RUINS, MIDNIGHT_TRENCH }

@export var round_time: float = 30.0 # 30s min, 60s max
@export var background_theme: BackgroundTheme = BackgroundTheme.DEEP_OCEAN

# Active minigames selection (scene paths)
@export var enabled_minigames: Array[String] = [
	"res://scenes/minigames/mg_treasure_dig/TreasureDig.tscn",
	"res://scenes/minigames/mg_flappy_fish/FlappyFish.tscn",
	"res://scenes/minigames/mg_debris_dash/DebrisDash.tscn",
	"res://scenes/minigames/mg_pellet_catch/PelletCatch.tscn"
]

# Bot settings
@export var bot_count: int = 0 # 0 to 3 bots
@export var bot_difficulty: PlayerData.BotDifficulty = PlayerData.BotDifficulty.MEDIUM

# Background colors mapped to themes
const THEME_COLORS: Dictionary = {
	BackgroundTheme.DEEP_OCEAN: Color("#0b2545"),
	BackgroundTheme.CORAL_REEF: Color("#134074"),
	BackgroundTheme.SUNKEN_RUINS: Color("#1d2d44"),
	BackgroundTheme.MIDNIGHT_TRENCH: Color("#03071e")
}

const THEME_NAMES: Dictionary = {
	BackgroundTheme.DEEP_OCEAN: "Deep Ocean Blue",
	BackgroundTheme.CORAL_REEF: "Vibrant Coral Reef",
	BackgroundTheme.SUNKEN_RUINS: "Sunken Ruins Teal",
	BackgroundTheme.MIDNIGHT_TRENCH: "Midnight Abyss"
}

func get_bg_color() -> Color:
	return THEME_COLORS.get(background_theme, Color("#0b2545"))

func duplicate_config() -> MatchConfig:
	var copy = MatchConfig.new()
	copy.round_time = round_time
	copy.background_theme = background_theme
	copy.enabled_minigames = enabled_minigames.duplicate()
	copy.bot_count = bot_count
	copy.bot_difficulty = bot_difficulty
	return copy
