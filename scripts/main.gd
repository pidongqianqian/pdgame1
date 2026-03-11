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
	_load_scene("res://scenes/game_world.tscn")


func return_to_title() -> void:
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
