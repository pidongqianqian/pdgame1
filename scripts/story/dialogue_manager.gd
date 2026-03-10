extends Node
class_name DialogueManager

signal dialogue_started
signal dialogue_ended
signal line_displayed(speaker: String, text: String)

var dialogue_data: Dictionary = {}
var current_dialogue: Array = []
var current_line_index: int = -1
var is_active: bool = false


func load_dialogue_file(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json = JSON.new()
	var result = json.parse(file.get_as_text())
	file.close()
	if result == OK:
		dialogue_data = json.data


func start_dialogue(dialogue_id: String) -> void:
	if not dialogue_data.has(dialogue_id):
		return
	current_dialogue = dialogue_data[dialogue_id]
	current_line_index = 0
	is_active = true
	dialogue_started.emit()
	_display_current_line()


func advance() -> void:
	if not is_active:
		return
	current_line_index += 1
	if current_line_index >= current_dialogue.size():
		end_dialogue()
		return
	_display_current_line()


func end_dialogue() -> void:
	is_active = false
	current_dialogue = []
	current_line_index = -1
	dialogue_ended.emit()


func _display_current_line() -> void:
	if current_line_index >= current_dialogue.size():
		return
	var line = current_dialogue[current_line_index]
	var speaker = line.get("speaker", "")
	var text = line.get("text", "")
	line_displayed.emit(speaker, text)
