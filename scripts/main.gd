extends Node2D

@onready var current_scene_holder: Node2D = $CurrentScene

var current_scene: Node = null


func _ready() -> void:
	GameManager.player_died.connect(_on_player_died)
	NetworkManager.game_start_requested.connect(_on_network_start)
	_load_scene("res://scenes/ui/title_screen.tscn")


func _load_scene(scene_path: String) -> void:
	if current_scene:
		current_scene.queue_free()
		current_scene = null
	var scene_res = load(scene_path)
	if scene_res:
		current_scene = scene_res.instantiate()
		current_scene_holder.add_child(current_scene)


func go_to_lobby() -> void:
	GameManager.current_state = GameManager.GameState.CLASS_SELECT
	_load_scene("res://scenes/ui/lobby_screen.tscn")


func go_to_class_select() -> void:
	GameManager.current_state = GameManager.GameState.CLASS_SELECT
	_load_scene("res://scenes/ui/class_select_screen.tscn")


func start_game() -> void:
	GameManager.start_new_run()
	# 如果有存档进度，恢复层数和金币（玩家状态由 game_world 在 _spawn_player 后恢复）
	var run = SaveManager.get_run_summary()
	if not run.is_empty():
		GameManager.current_class = int(run.get("class", GameManager.current_class))
		GameManager.current_floor = int(run.get("floor", 1))
		GameManager.gold = int(run.get("gold", 0))
	_load_scene("res://scenes/game_world.tscn")


func start_game_new() -> void:
	SaveManager.clear_run()
	GameManager.start_new_run()
	_load_scene("res://scenes/game_world.tscn")


func return_to_title() -> void:
	get_tree().paused = false
	if NetworkManager.is_multiplayer_active():
		NetworkManager.disconnect_all()
	GameManager.current_state = GameManager.GameState.TITLE
	_load_scene("res://scenes/ui/title_screen.tscn")


func _on_network_start() -> void:
	# Called when NetworkManager triggers game start (multiplayer lobby ready)
	# The lobby screen handles this itself; this is a backup for edge cases
	pass


func _on_player_died() -> void:
	GameManager.end_run(false)
	SaveManager.save_game()
	# 不再自动跳转标题，由 game_world 显示死亡 UI 让玩家选择
