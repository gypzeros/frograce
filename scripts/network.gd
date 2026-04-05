extends Node
## Cliente WebSocket para conectar al servidor multijugador

signal connected
signal match_found(player_num: int, game_seed: int, opponent_pet: String, init_obstacles: Array)
signal tick_received(obstacles: Array)
signal waiting
signal opponent_moved(grid_row: int, grid_col: int)
signal opponent_died
signal opponent_disconnected
signal opponent_respawned
signal score_updated(player_num: int, score: int)
signal game_over(winner: int)
signal connection_failed

const SERVER_URL = "ws://localhost:3000"

var socket: WebSocketPeer
var _connected := false


func _ready():
	socket = WebSocketPeer.new()


func connect_to_server():
	var err = socket.connect_to_url(SERVER_URL)
	if err != OK:
		print("[Network] Failed to connect: ", err)
		connection_failed.emit()


func _process(_delta):
	if not socket:
		return

	socket.poll()

	var state = socket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		if not _connected:
			_connected = true
			print("[Network] Connected to server")
			connected.emit()

		while socket.get_available_packet_count() > 0:
			var raw = socket.get_packet().get_string_from_utf8()
			_handle_message(raw)

	elif state == WebSocketPeer.STATE_CLOSED:
		if _connected:
			_connected = false
			print("[Network] Disconnected")


func _handle_message(raw: String):
	var msg = JSON.parse_string(raw)
	if not msg:
		return

	var type = msg.get("type", "")

	match type:
		"waiting":
			print("[Network] Waiting for opponent...")
			waiting.emit()
		"match_found":
			var player_num: int = msg.get("playerNum", 1)
			var game_seed: int = msg.get("gameSeed", randi())
			var opponent_pet: String = msg.get("opponentPet", "")
			var init_obs: Array = msg.get("obstacles", [])
			print("[Network] Match found! Player ", player_num)
			match_found.emit(player_num, game_seed, opponent_pet, init_obs)
		"tick":
			tick_received.emit(msg.get("obstacles", []))
		"opponent_moved":
			opponent_moved.emit(msg.get("gridRow", 0), msg.get("gridCol", 0))
		"opponent_died":
			opponent_died.emit()
		"opponent_disconnected":
			print("[Network] Opponent disconnected")
			opponent_disconnected.emit()
		"opponent_respawned":
			opponent_respawned.emit()
		"score_update":
			score_updated.emit(msg.get("playerNum", 1), msg.get("score", 0))
		"game_over":
			game_over.emit(msg.get("winner", 1))


func send_find_match(pet_path: String = "", device_id: String = ""):
	_send({"type": "find_match", "pet": pet_path, "deviceId": device_id})


func send_move(grid_row: int, grid_col: int):
	_send({"type": "player_move", "gridRow": grid_row, "gridCol": grid_col})


func send_died():
	_send({"type": "player_died"})


func send_scored():
	_send({"type": "player_scored"})


func _send(data: Dictionary):
	if _connected:
		socket.send_text(JSON.stringify(data))


func disconnect_from_server():
	if socket:
		socket.close()
		_connected = false
