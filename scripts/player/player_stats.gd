extends Resource
class_name PlayerStats

signal hp_changed(current_hp: int, max_hp: int)
signal died

@export var max_hp: int = 100
@export var current_hp: int = 100
@export var attack: int = 10
@export var defense: int = 5
@export var speed: float = 60.0
@export var dodge_speed: float = 150.0
@export var dodge_duration: float = 0.25
@export var dodge_cooldown: float = 0.6
@export var attack_cooldown: float = 0.35
@export var invincible_duration: float = 0.5

var equipment: Dictionary = {}
var inventory: Array[Dictionary] = []
const MAX_INVENTORY_SIZE = 20

var xp: int = 0
var level: int = 1
var skill_points: int = 0
var learned_passives: Array = []
var passive_stacks: Dictionary = {}

# buff 系统（战吼等临时增益）
var active_buffs: Array[Dictionary] = []  # [{"id": "warcry", "atk_bonus": ..., "def_bonus": ..., "timer": ...}]


func reset() -> void:
	var bonus = GameManager.permanent_upgrades
	var cd = GameManager.CLASS_DATA[GameManager.current_class]
	max_hp          = cd["max_hp"]       + bonus["max_hp_bonus"]
	attack          = cd["attack"]       + bonus["attack_bonus"]
	defense         = cd["defense"]      + bonus["defense_bonus"]
	speed           = cd["speed"]        + bonus["speed_bonus"]
	attack_cooldown = cd["attack_cooldown"]
	dodge_speed     = cd["dodge_speed"]
	dodge_duration  = cd["dodge_duration"]
	current_hp = max_hp
	equipment = {}
	inventory = []
	xp = 0
	level = 1
	skill_points = 0
	learned_passives = []
	passive_stacks = {}
	active_buffs = []


func heal(amount: int) -> void:
	var total_max = get_total_max_hp()
	current_hp = mini(total_max, current_hp + amount)
	hp_changed.emit(current_hp, total_max)


func get_equipment_stat(stat_name: String) -> int:
	var total = 0
	for slot in equipment:
		var item = equipment[slot]
		if item.has(stat_name):
			total += item[stat_name]
	return total


func equip_item(item: Dictionary) -> Dictionary:
	var slot = item["slot"]
	var old_item = {}
	if equipment.has(slot):
		old_item = equipment[slot]
		inventory.append(old_item)
	equipment[slot] = item
	if item in inventory:
		inventory.erase(item)
	return old_item


func unequip_item(slot: int) -> void:
	if equipment.has(slot) and inventory.size() < MAX_INVENTORY_SIZE:
		inventory.append(equipment[slot])
		equipment.erase(slot)


func add_to_inventory(item: Dictionary) -> bool:
	if inventory.size() >= MAX_INVENTORY_SIZE:
		return false
	inventory.append(item)
	return true


func remove_from_inventory(item: Dictionary) -> void:
	inventory.erase(item)


# ═══════════════════════════════════════════════════════════════
# XP / 升级
# ═══════════════════════════════════════════════════════════════

func get_required_xp() -> int:
	return 20 + level * 15


func add_xp(amount: int) -> bool:
	xp += amount
	var required: int = get_required_xp()
	GameManager.xp_changed.emit(xp, required)
	if xp >= required:
		xp -= required
		level += 1
		GameManager.level_up.emit(level)
		GameManager.xp_changed.emit(xp, get_required_xp())
		return true
	return false


# ═══════════════════════════════════════════════════════════════
# 被动天赋
# ═══════════════════════════════════════════════════════════════

func learn_passive(passive_id: String) -> void:
	learned_passives.append(passive_id)
	passive_stacks[passive_id] = passive_stacks.get(passive_id, 0) + 1


func get_passive_value(stat_name: String) -> float:
	var total: float = 0.0
	for pid in passive_stacks:
		if not SkillDatabase.PASSIVE_TALENTS.has(pid):
			continue
		var data: Dictionary = SkillDatabase.PASSIVE_TALENTS[pid]
		if data["stat"] == stat_name:
			total += data["per_stack"] * passive_stacks[pid]
	return total


func get_total_attack() -> int:
	var base: int = attack + get_equipment_stat("attack") + int(get_passive_value("attack_flat"))
	var buff_atk: int = 0
	for b in active_buffs:
		buff_atk += b.get("atk_bonus", 0)
	base += buff_atk
	# 狂暴
	if get_passive_value("berserker_mult") > 0.0:
		var hp_ratio: float = float(current_hp) / float(maxi(get_total_max_hp(), 1))
		if hp_ratio < 0.3:
			base = int(base * (1.0 + get_passive_value("berserker_mult")))
	return base


func get_total_defense() -> int:
	var base: int = defense + get_equipment_stat("defense") + int(get_passive_value("defense_flat"))
	var buff_def: int = 0
	for b in active_buffs:
		buff_def += b.get("def_bonus", 0)
	return base + buff_def


func get_total_speed() -> float:
	var base: float = speed + get_equipment_stat("speed")
	var mult: float = 1.0 + get_passive_value("speed_mult")
	return base * mult


func get_total_max_hp() -> int:
	return max_hp + get_equipment_stat("hp")


func take_damage(amount: int) -> int:
	# 闪避判定
	var evasion: float = get_passive_value("evasion_chance")
	if evasion > 0.0 and randf() < evasion:
		return 0
	var total_def: int = get_total_defense()
	var actual: int = maxi(1, amount - total_def)
	current_hp = maxi(0, current_hp - actual)
	hp_changed.emit(current_hp, get_total_max_hp())
	if current_hp <= 0:
		died.emit()
	return actual


func update_buffs(delta: float) -> void:
	var expired: Array[int] = []
	for i in active_buffs.size():
		active_buffs[i]["timer"] -= delta
		if active_buffs[i]["timer"] <= 0.0:
			expired.append(i)
	expired.reverse()
	for idx in expired:
		active_buffs.remove_at(idx)


func add_buff(buff: Dictionary) -> void:
	active_buffs.append(buff)
