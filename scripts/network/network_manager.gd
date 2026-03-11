extends Node

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal connection_failed
signal connected_to_host
signal host_disconnected
signal all_players_ready
signal game_start_requested
signal lobby_state_changed

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 4

# peer_id -> { "class": int, "ready": bool }
var player_info: Dictionary = {}
var is_hosting: bool = false
var is_cloud_room: bool = false
var current_dungeon_seed: int = 0

# Track dead players for game-over check
var _dead_peers: Array[int] = []


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


# ══════════════════════════════════════════════════════════════
# Public API
# ══════════════════════════════════════════════════════════════

func create_server() -> Error:
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(DEFAULT_PORT, MAX_PLAYERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_hosting = true
	var my_id: int = multiplayer.get_unique_id()
	player_info[my_id] = { "class": GameManager.current_class, "ready": false }
	lobby_state_changed.emit()
	return OK


func join_server(ip: String, port: int = DEFAULT_PORT) -> Error:
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_hosting = false
	return OK


func disconnect_all() -> void:
	if is_cloud_room:
		if is_hosting:
			CloudRoomAPI.close_room()
		else:
			CloudRoomAPI.leave_room()
	is_cloud_room = false
	var peer = multiplayer.multiplayer_peer
	if peer is ENetMultiplayerPeer:
		peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	player_info.clear()
	_dead_peers.clear()
	is_hosting = false
	GameManager.player_nodes.clear()
	lobby_state_changed.emit()


func get_player_count() -> int:
	if multiplayer.multiplayer_peer == null:
		return 1
	return player_info.size()


func is_multiplayer_active() -> bool:
	return multiplayer.multiplayer_peer is ENetMultiplayerPeer


func get_local_peer_id() -> int:
	if multiplayer.multiplayer_peer == null:
		return 1
	return multiplayer.get_unique_id()


func get_sorted_peer_ids() -> Array:
	var ids: Array = player_info.keys()
	ids.sort()
	return ids


func get_local_ip() -> String:
	for addr in IP.get_local_addresses():
		if addr.begins_with("192.168.") or addr.begins_with("10.") or addr.begins_with("172."):
			return addr
	return "127.0.0.1"


func set_local_class(cls: int) -> void:
	var my_id: int = get_local_peer_id()
	if player_info.has(my_id):
		player_info[my_id]["class"] = cls
	if is_multiplayer_active():
		_rpc_update_class.rpc(my_id, cls)


func set_local_ready(rdy: bool) -> void:
	var my_id: int = get_local_peer_id()
	if player_info.has(my_id):
		player_info[my_id]["ready"] = rdy
	if is_multiplayer_active():
		_rpc_update_ready.rpc(my_id, rdy)
	_check_all_ready()


func host_start_game() -> void:
	if not is_hosting:
		return
	_dead_peers.clear()
	current_dungeon_seed = randi()
	if is_cloud_room:
		CloudRoomAPI.update_status("playing")
	var info_snapshot: Dictionary = {}
	for pid in player_info:
		info_snapshot[pid] = player_info[pid].duplicate()
	_rpc_start_game.rpc(current_dungeon_seed, info_snapshot)


func register_player_death(peer_id: int) -> void:
	if peer_id not in _dead_peers:
		_dead_peers.append(peer_id)
	# Check if all players are dead
	if _dead_peers.size() >= get_player_count():
		GameManager.player_died.emit()


func revive_all() -> void:
	_dead_peers.clear()


# ══════════════════════════════════════════════════════════════
# Internal
# ══════════════════════════════════════════════════════════════

func _check_all_ready() -> void:
	if player_info.is_empty():
		return
	for pid in player_info:
		if not player_info[pid]["ready"]:
			return
	all_players_ready.emit()


# ══════════════════════════════════════════════════════════════
# Peer lifecycle
# ══════════════════════════════════════════════════════════════

func _on_peer_connected(peer_id: int) -> void:
	if is_hosting:
		# Send existing player list to newly joined peer
		for pid in player_info:
			_rpc_register_player.rpc_id(peer_id, pid,
				player_info[pid]["class"], player_info[pid]["ready"])
		# Add placeholder for new peer (they'll fill it in via _rpc_register_player)
		player_info[peer_id] = { "class": 0, "ready": false }
		lobby_state_changed.emit()
		player_connected.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	player_info.erase(peer_id)
	_dead_peers.erase(peer_id)
	lobby_state_changed.emit()
	player_disconnected.emit(peer_id)


func _on_connected_to_server() -> void:
	var my_id: int = multiplayer.get_unique_id()
	player_info[my_id] = { "class": GameManager.current_class, "ready": false }
	# Register ourselves with all peers
	_rpc_register_player.rpc(my_id, GameManager.current_class, false)
	connected_to_host.emit()
	lobby_state_changed.emit()


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	connection_failed.emit()


func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	player_info.clear()
	_dead_peers.clear()
	is_hosting = false
	GameManager.player_nodes.clear()
	host_disconnected.emit()


# ══════════════════════════════════════════════════════════════
# RPCs
# ══════════════════════════════════════════════════════════════

@rpc("any_peer", "call_local", "reliable")
func _rpc_register_player(peer_id: int, cls: int, rdy: bool) -> void:
	player_info[peer_id] = { "class": cls, "ready": rdy }
	lobby_state_changed.emit()


@rpc("any_peer", "call_local", "reliable")
func _rpc_update_class(peer_id: int, cls: int) -> void:
	if player_info.has(peer_id):
		player_info[peer_id]["class"] = cls
	lobby_state_changed.emit()


@rpc("any_peer", "call_local", "reliable")
func _rpc_update_ready(peer_id: int, rdy: bool) -> void:
	if player_info.has(peer_id):
		player_info[peer_id]["ready"] = rdy
	lobby_state_changed.emit()
	_check_all_ready()


@rpc("authority", "call_local", "reliable")
func _rpc_start_game(seed_val: int, info_snapshot: Dictionary) -> void:
	current_dungeon_seed = seed_val
	player_info = info_snapshot
	game_start_requested.emit()
