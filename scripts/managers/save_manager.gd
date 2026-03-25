extends Node

const SAVE_PATH = "user://save_data.json"

var save_data: Dictionary = {}


func _ready() -> void:
	load_game()


# ── 持久化存档（跨局数据：灵魂、最高层、永久升级）────────────
func save_game() -> void:
	save_data["max_floor_reached"] = GameManager.max_floor_reached
	save_data["souls"] = GameManager.souls
	save_data["permanent_upgrades"] = GameManager.permanent_upgrades
	_write_file()


# ── 当局进度存档（层数、金币、玩家状态）────────────────────────
func save_run() -> void:
	if not GameManager.run_active:
		return
	var player = GameManager.player_node
	if not player or not is_instance_valid(player) or player.get("stats") == null:
		return
	var st = player.stats

	# 序列化装备（每个槽位的字典，去掉 Callable/Object 类型字段）
	var equipment_data: Dictionary = {}
	for slot in st.equipment:
		equipment_data[slot] = _serialize_item(st.equipment[slot])

	# 序列化背包
	var inventory_data: Array = []
	for item in st.inventory:
		inventory_data.append(_serialize_item(item))

	save_data["run"] = {
		"active": true,
		"class": GameManager.current_class,
		"floor": GameManager.current_floor,
		"gold": GameManager.gold,
		"hp": st.current_hp,
		"max_hp": st.max_hp,
		"attack": st.attack,
		"defense": st.defense,
		"speed": st.speed,
		"level": st.level,
		"xp": st.xp,
		"skill_points": st.skill_points,
		"equipment": equipment_data,
		"inventory": inventory_data,
		"learned_passives": st.learned_passives.duplicate(),
		"passive_stacks": st.passive_stacks.duplicate(),
	}
	# 同时写持久化字段
	save_data["max_floor_reached"] = GameManager.max_floor_reached
	save_data["souls"] = GameManager.souls
	save_data["permanent_upgrades"] = GameManager.permanent_upgrades
	_write_file()


func clear_run() -> void:
	save_data.erase("run")
	_write_file()


func has_active_run() -> bool:
	return save_data.get("run", {}).get("active", false)


func get_run_summary() -> Dictionary:
	return save_data.get("run", {})


# ── 通用 I/O ───────────────────────────────────────────────────
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

	GameManager.max_floor_reached = int(save_data.get("max_floor_reached", 0))
	GameManager.souls = int(save_data.get("souls", 0))
	var upgrades = save_data.get("permanent_upgrades", {})
	for key in upgrades:
		if GameManager.permanent_upgrades.has(key):
			GameManager.permanent_upgrades[key] = upgrades[key]


func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	save_data = {}


# ── 从存档恢复玩家状态（game_world 启动后调用）─────────────────
func restore_run_to_player(player: Node) -> void:
	var run: Dictionary = save_data.get("run", {})
	if run.is_empty() or not player or not is_instance_valid(player):
		return
	if player.get("stats") == null:
		return
	var st = player.stats

	st.max_hp    = int(run.get("max_hp",    st.max_hp))
	st.attack    = int(run.get("attack",    st.attack))
	st.defense   = int(run.get("defense",   st.defense))
	st.speed     = float(run.get("speed",   st.speed))
	st.level     = int(run.get("level",     st.level))
	st.xp        = int(run.get("xp",        st.xp))
	st.skill_points = int(run.get("skill_points", st.skill_points))
	st.current_hp = int(run.get("hp",       st.current_hp))
	st.current_hp = clampi(st.current_hp, 1, st.get_total_max_hp())

	st.equipment.clear()
	var eq_data: Dictionary = run.get("equipment", {})
	for slot in eq_data:
		st.equipment[slot] = eq_data[slot]

	st.inventory.clear()
	for item in run.get("inventory", []):
		st.inventory.append(item)

	st.learned_passives = run.get("learned_passives", [])
	st.passive_stacks   = run.get("passive_stacks", {})


# ── 内部辅助 ───────────────────────────────────────────────────
func _serialize_item(item: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in item:
		var v = item[k]
		# 跳过无法 JSON 序列化的类型
		if v is Callable or v is Object:
			continue
		if v is Color:
			out[k] = {"r": v.r, "g": v.g, "b": v.b, "a": v.a}
		else:
			out[k] = v
	return out


func _write_file() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()
