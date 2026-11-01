extends Control

@onready var winner_label: Label = $Center/VBox/WinnerLabel
@onready var adoption_speech: Label = $Center/VBox/AdoptionSpeech
@onready var menu_btn: Button = $Center/VBox/Buttons/MenuBtn
@onready var aquarium_btn: Button = $Center/VBox/Buttons/AquariumBtn

func _ready() -> void:
	if menu_btn:
		menu_btn.pressed.connect(_on_menu_pressed)
	if aquarium_btn:
		aquarium_btn.pressed.connect(_on_aquarium_pressed)
	
	var sorted_players = GameManager.players.duplicate()
	sorted_players.sort_custom(func(a, b): return a.total_score > b.total_score)
	
	if sorted_players.size() > 0:
		var top_fish = sorted_players[0]
		if winner_label:
			winner_label.text = "👑 %s WINS THE ADOPTION! 👑\nScore: %d Points" % [top_fish.player_name, top_fish.total_score]
		if adoption_speech:
			adoption_speech.text = "The aquarium owner reaches into the tank with a gentle net and selects %s to take home to a luxury fish palace!" % top_fish.player_name

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")

func _on_aquarium_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/aquarium_lobby/AquariumLobby.tscn")
