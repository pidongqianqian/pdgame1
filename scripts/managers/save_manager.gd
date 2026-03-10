extends Node

const SAVE_PATH = "user://save_data.json"

var save_data: Dictionary = {}


func _ready() -> void:
	load_game()


func save_game() -> void:
	save_data = {
		"max_floor_reached": GameManager.max_floor_reached,
		"souls": GameManager.souls,
		"permanent_upgrades": GameManager.permanent_upgrades,
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json = JSON.new()
	var result = json.parse(file.get_as_text())
	file.close()
	if result != OK:
		return
	save_data = json.data
	GameManager.max_floor_reached = save_data.get("max_floor_reached", 0)
	GameManager.souls = save_data.get("souls", 0)
	var upgrades = save_data.get("permanent_upgrades", {})
	for key in upgrades:
		if GameManager.permanent_upgrades.has(key):
			GameManager.permanent_upgrades[key] = upgrades[key]


func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	save_data = {}
