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


func take_damage(amount: int) -> int:
	var total_def = defense + get_equipment_stat("defense")
	var actual = maxi(1, amount - total_def)
	current_hp = maxi(0, current_hp - actual)
	hp_changed.emit(current_hp, max_hp)
	if current_hp <= 0:
		died.emit()
	return actual


func heal(amount: int) -> void:
	var total_max = max_hp + get_equipment_stat("hp")
	current_hp = mini(total_max, current_hp + amount)
	hp_changed.emit(current_hp, total_max)


func get_total_attack() -> int:
	return attack + get_equipment_stat("attack")


func get_total_speed() -> float:
	return speed + get_equipment_stat("speed")


func get_total_max_hp() -> int:
	return max_hp + get_equipment_stat("hp")


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
