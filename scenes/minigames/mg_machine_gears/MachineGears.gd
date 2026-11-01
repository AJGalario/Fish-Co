extends MinigameBase

# Machine Party style: Hazard machines / spinning cog hazard sweepers
@onready var sweeper: AnimatableBody2D = $SweeperArm
var rotation_speed: float = 2.0

func _ready() -> void:
	minigame_title = "Machine Gears"
	minigame_instructions = "JUMP OVER THE ROTATING SUB-GEAR! DON'T GET CRUSHED!"
	round_time = 30.0
	super._ready()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_active and sweeper:
		sweeper.rotation += rotation_speed * delta

func _on_sweeper_hit(body: Node2D) -> void:
	if body is FishPlayer:
		body.die("Caught in the submarine gear machinery!")
