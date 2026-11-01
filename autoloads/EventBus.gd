extends Node

# Centralized signal hub for loose coupling across minigames and systems
signal player_died(player_id: int)
signal player_scored(player_id: int, points: int)
signal minigame_started(minigame_name: String)
signal minigame_finished(results: Array)
signal modifier_activated(mod_id: String, mod_label: String)
signal modifier_deactivated(mod_id: String)
signal network_player_connected(peer_id: int, player_data: Dictionary)
signal network_player_disconnected(peer_id: int)
