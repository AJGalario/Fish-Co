extends Control

@onready var scores_container: VBoxContainer = $Center/VBox/ScoresContainer
@onready var next_btn: Button = $Center/VBox/NextBtn

func _ready() -> void:
	next_btn.pressed.connect(_on_next_pressed)
	render_scores()

func render_scores() -> void:
	for child in scores_container.get_children():
		child.queue_free()
		
	# Sort players by total score
	var sorted_players = GameManager.players.duplicate()
	sorted_players.sort_custom(func(a, b): return a.total_score > b.total_score)
	
	for p in sorted_players:
		var lbl = Label.new()
		lbl.text = "%s: %d Stars / Points" % [p.player_name, p.total_score]
		lbl.add_theme_font_size_override("font_size", 32)
		scores_container.add_child(lbl)

func _on_next_pressed() -> void:
	GameManager.next_round()
