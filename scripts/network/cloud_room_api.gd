extends Node

signal rooms_listed(rooms: Array)
signal room_created(room: Dictionary)
signal room_joined(room: Dictionary)
signal request_failed(error: String)

const DEFAULT_API_URL: String = "http://106.14.75.44:8888"

var api_url: String = DEFAULT_API_URL
var current_room_code: String = ""
var _heartbeat_timer: float = 0.0
const HEARTBEAT_INTERVAL: float = 30.0


func _ready() -> void:
	var saved_url: String = _load_api_url()
	if not saved_url.is_empty():
		api_url = saved_url


func _process(delta: float) -> void:
	if current_room_code.is_empty():
		return
	_heartbeat_timer += delta
	if _heartbeat_timer >= HEARTBEAT_INTERVAL:
		_heartbeat_timer = 0.0
		send_heartbeat()


func set_api_url(url: String) -> void:
	api_url = url.strip_edges().rstrip("/")
	_save_api_url(api_url)


func create_room(room_name: String, port: int = 7777) -> void:
	var lan_ip: String = NetworkManager.get_local_ip()
	var body: Dictionary = {"room_name": room_name, "host_port": port, "host_lan_ip": lan_ip}
	var json_str: String = JSON.stringify(body)
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body_bytes: PackedByteArray):
		http.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
			request_failed.emit("创建房间失败 (HTTP %d)" % code)
			return
		var parsed = JSON.parse_string(body_bytes.get_string_from_utf8())
		if parsed == null:
			request_failed.emit("服务器返回无效数据")
			return
		current_room_code = parsed.get("room_code", "")
		_heartbeat_timer = 0.0
		room_created.emit(parsed)
	)
	http.request(
		api_url + "/api/rooms",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		json_str,
	)


func list_rooms() -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body_bytes: PackedByteArray):
		http.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
			request_failed.emit("获取房间列表失败 (HTTP %d)" % code)
			return
		var parsed = JSON.parse_string(body_bytes.get_string_from_utf8())
		if parsed == null or not (parsed is Array):
			request_failed.emit("服务器返回无效数据")
			return
		rooms_listed.emit(parsed)
	)
	http.request(api_url + "/api/rooms")


func join_room(code: String) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result: int, status_code: int, _h: PackedStringArray, body_bytes: PackedByteArray):
		http.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or status_code < 200 or status_code >= 300:
			var err_msg: String = "加入房间失败"
			if status_code == 404:
				err_msg = "房间不存在"
			elif status_code == 409:
				err_msg = "房间已满"
			elif status_code == 410:
				err_msg = "房间已关闭"
			request_failed.emit(err_msg)
			return
		var parsed = JSON.parse_string(body_bytes.get_string_from_utf8())
		if parsed == null:
			request_failed.emit("服务器返回无效数据")
			return
		current_room_code = parsed.get("room_code", "")
		room_joined.emit(parsed)
	)
	http.request(
		api_url + "/api/rooms/" + code.to_upper() + "/join",
		["Content-Type: application/json"],
		HTTPClient.METHOD_PUT,
	)


func leave_room() -> void:
	if current_room_code.is_empty():
		return
	var code: String = current_room_code
	current_room_code = ""
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r: int, _c: int, _h: PackedStringArray, _b: PackedByteArray):
		http.queue_free()
	)
	http.request(
		api_url + "/api/rooms/" + code + "/leave",
		["Content-Type: application/json"],
		HTTPClient.METHOD_PUT,
	)


func close_room() -> void:
	if current_room_code.is_empty():
		return
	var code: String = current_room_code
	current_room_code = ""
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r: int, _c: int, _h: PackedStringArray, _b: PackedByteArray):
		http.queue_free()
	)
	http.request(
		api_url + "/api/rooms/" + code,
		[],
		HTTPClient.METHOD_DELETE,
	)


func update_status(new_status: String) -> void:
	if current_room_code.is_empty():
		return
	var body: String = JSON.stringify({"status": new_status})
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r: int, _c: int, _h: PackedStringArray, _b: PackedByteArray):
		http.queue_free()
	)
	http.request(
		api_url + "/api/rooms/" + current_room_code + "/status",
		["Content-Type: application/json"],
		HTTPClient.METHOD_PUT,
		body,
	)


func send_heartbeat() -> void:
	if current_room_code.is_empty():
		return
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r: int, _c: int, _h: PackedStringArray, _b: PackedByteArray):
		http.queue_free()
	)
	http.request(
		api_url + "/api/rooms/" + current_room_code + "/heartbeat",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
	)


func ping_server(callback: Callable) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray):
		http.queue_free()
		callback.call(result == HTTPRequest.RESULT_SUCCESS and code == 200)
	)
	http.request(api_url + "/api/ping")


const SAVE_PATH: String = "user://cloud_config.cfg"

func _save_api_url(url: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("cloud", "api_url", url)
	cfg.save(SAVE_PATH)


func _load_api_url() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		return cfg.get_value("cloud", "api_url", "")
	return ""
