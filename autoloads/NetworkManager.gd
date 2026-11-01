extends Node

const DEFAULT_PORT: int = 7777
const MAX_CLIENTS: int = 4

var peer: ENetMultiplayerPeer
var is_server: bool = false
var connected_players: Dictionary = {} # peer_id -> PlayerData

signal server_created
signal connection_succeeded
signal connection_failed
signal player_list_changed

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_game(port: int = DEFAULT_PORT) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		push_error("Failed to host game: %d" % err)
		return err
	
	multiplayer.multiplayer_peer = peer
	is_server = true
	
	# Register host local player
	var local_id = multiplayer.get_unique_id() # 1
	_register_network_player(local_id, "Host Fish", 0)
	server_created.emit()
	return OK

func join_game(address: String = "127.0.0.1", port: int = DEFAULT_PORT) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(address, port)
	if err != OK:
		push_error("Failed to connect: %d" % err)
		return err
	
	multiplayer.multiplayer_peer = peer
	is_server = false
	return OK

func _on_peer_connected(id: int) -> void:
	print("Network peer connected: ", id)
	if is_server:
		# Ask client for info or assign slot
		rpc_id(id, "sync_all_players", _serialize_players())

func _on_peer_disconnected(id: int) -> void:
	print("Network peer disconnected: ", id)
	if connected_players.has(id):
		connected_players.erase(id)
		player_list_changed.emit()
		EventBus.network_player_disconnected.emit(id)

func _on_connected_to_server() -> void:
	var my_id = multiplayer.get_unique_id()
	rpc_id(1, "request_registration", my_id, "Guest Fish", connected_players.size())
	connection_succeeded.emit()

func _on_connection_failed() -> void:
	connection_failed.emit()

func _on_server_disconnected() -> void:
	connected_players.clear()
	multiplayer.multiplayer_peer = null

@rpc("any_peer", "call_local", "reliable")
func request_registration(peer_id: int, p_name: String, skin: int) -> void:
	if not is_server:
		return
	_register_network_player(peer_id, p_name, skin)
	rpc("sync_all_players", _serialize_players())

@rpc("authority", "call_local", "reliable")
func sync_all_players(data: Array) -> void:
	connected_players.clear()
	GameManager.players.clear()
	for p_dict in data:
		var pd = PlayerData.new()
		pd.player_id = p_dict["player_id"]
		pd.peer_id = p_dict["peer_id"]
		pd.player_name = p_dict["player_name"]
		pd.character_skin = p_dict["character_skin"]
		pd.is_local_controlled = (pd.peer_id == multiplayer.get_unique_id())
		connected_players[pd.peer_id] = pd
		GameManager.players.append(pd)
	player_list_changed.emit()

func _register_network_player(peer_id: int, p_name: String, skin: int) -> void:
	var p = PlayerData.new()
	p.player_id = connected_players.size()
	p.peer_id = peer_id
	p.player_name = p_name
	p.character_skin = skin
	p.is_local_controlled = (peer_id == multiplayer.get_unique_id())
	connected_players[peer_id] = p
	GameManager.players.append(p)
	player_list_changed.emit()

func _serialize_players() -> Array:
	var list: Array = []
	for pid in connected_players:
		var p: PlayerData = connected_players[pid]
		list.append({
			"player_id": p.player_id,
			"peer_id": p.peer_id,
			"player_name": p.player_name,
			"character_skin": p.character_skin
		})
	return list
