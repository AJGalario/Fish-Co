extends Control

@onready var enter_aquarium_btn: Button = $CenterContainer/VBox/EnterAquariumBtn
@onready var host_btn: Button = $CenterContainer/VBox/NetworkBox/HostBtn
@onready var join_btn: Button = $CenterContainer/VBox/NetworkBox/JoinBtn
@onready var ip_edit: LineEdit = $CenterContainer/VBox/NetworkBox/IPEdit

func _ready() -> void:
	enter_aquarium_btn.pressed.connect(_on_enter_aquarium_pressed)
	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)

func _on_enter_aquarium_pressed() -> void:
	GameManager.setup_local_players(2) # Default 2 local fish in aquarium
	get_tree().change_scene_to_file("res://scenes/aquarium_lobby/AquariumLobby.tscn")

func _on_host_pressed() -> void:
	NetworkManager.host_game()
	get_tree().change_scene_to_file("res://scenes/aquarium_lobby/AquariumLobby.tscn")

func _on_join_pressed() -> void:
	var ip = ip_edit.text.strip_edges()
	if ip == "":
		ip = "127.0.0.1"
	NetworkManager.join_game(ip)
	get_tree().change_scene_to_file("res://scenes/aquarium_lobby/AquariumLobby.tscn")
