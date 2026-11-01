extends MinigameBase

# Mario Party "Bumper Balls" style: Arena shrinks or outer perimeter is deadly
@onready var lava_zone: Area2D = $LavaWaterZone

func _ready() -> void:
	minigame_title = "Bubble Sumo"
	minigame_instructions = "Knock others into the spicy boiling water! Keep moving!"
	round_time = 30.0
	super._ready()
	
	if lava_zone:
		lava_zone.body_entered.connect(_on_lava_entered)

func _on_lava_entered(body: Node2D) -> void:
	if body is FishPlayer:
		body.die("Fell into boiling coral water!")
