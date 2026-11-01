extends MinigameBase

# Pico Park cooperative mechanic: All surviving players must stand on buttons to plug the leak!
var buttons_pressed: int = 0
var required_buttons: int = 2

@onready var button_a: Area2D = $ButtonA
@onready var button_b: Area2D = $ButtonB
@onready var leak_visual: ColorRect = $LeakHazard

func _ready() -> void:
	minigame_title = "Pico Leak"
	minigame_instructions = "CO-OP: ALL fish must plug both leaks simultaneously before time runs out!"
	round_time = 25.0
	super._ready()
	
	required_buttons = min(2, max(1, GameManager.players.size()))
	button_a.body_entered.connect(_on_btn_a_entered)
	button_a.body_exited.connect(_on_btn_a_exited)
	button_b.body_entered.connect(_on_btn_b_entered)
	button_b.body_exited.connect(_on_btn_b_exited)

var a_pressed = false
var b_pressed = false

func _on_btn_a_entered(body: Node2D) -> void:
	if body is FishPlayer:
		a_pressed = true
		_check_victory()

func _on_btn_a_exited(body: Node2D) -> void:
	if body is FishPlayer:
		a_pressed = false

func _on_btn_b_entered(body: Node2D) -> void:
	if body is FishPlayer:
		b_pressed = true
		_check_victory()

func _on_btn_b_exited(body: Node2D) -> void:
	if body is FishPlayer:
		b_pressed = false

func _check_victory() -> void:
	if a_pressed and b_pressed:
		instructions_label.text = "🎉 LEAK PLUGGED! CO-OP VICTORY!"
		instructions_label.visible = true
		# Everyone gets equal top score in co-op!
		finish_minigame()
