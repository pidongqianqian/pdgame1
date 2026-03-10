extends Node

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
enum SlotType { WEAPON, HELMET, ARMOR, BOOTS, ACCESSORY }

const RARITY_NAMES = {
	Rarity.COMMON: "普通",
	Rarity.UNCOMMON: "精良",
	Rarity.RARE: "稀有",
	Rarity.EPIC: "史诗",
	Rarity.LEGENDARY: "传说",
}

const RARITY_COLORS = {
	Rarity.COMMON: Color.WHITE,
	Rarity.UNCOMMON: Color.GREEN,
	Rarity.RARE: Color.CORNFLOWER_BLUE,
	Rarity.EPIC: Color.MEDIUM_PURPLE,
	Rarity.LEGENDARY: Color.ORANGE,
}

const RARITY_MULTIPLIERS = {
	Rarity.COMMON: 1.0,
	Rarity.UNCOMMON: 1.3,
	Rarity.RARE: 1.7,
	Rarity.EPIC: 2.2,
	Rarity.LEGENDARY: 3.0,
}

const SLOT_NAMES = {
	SlotType.WEAPON: "武器",
	SlotType.HELMET: "头盔",
	SlotType.ARMOR: "护甲",
	SlotType.BOOTS: "靴子",
	SlotType.ACCESSORY: "饰品",
}

var item_templates: Array[Dictionary] = []


func _ready() -> void:
	_init_item_templates()


func _init_item_templates() -> void:
	item_templates = [
		{"id": "sword_iron", "name": "铁剑", "slot": SlotType.WEAPON, "base_attack": 5, "base_defense": 0, "base_hp": 0, "base_speed": 0},
		{"id": "sword_flame", "name": "炎剑", "slot": SlotType.WEAPON, "base_attack": 8, "base_defense": 0, "base_hp": 0, "base_speed": 0},
		{"id": "sword_shadow", "name": "暗影刃", "slot": SlotType.WEAPON, "base_attack": 12, "base_defense": 0, "base_hp": 0, "base_speed": 5},
		{"id": "dagger_swift", "name": "疾风匕首", "slot": SlotType.WEAPON, "base_attack": 4, "base_defense": 0, "base_hp": 0, "base_speed": 10},
		{"id": "axe_heavy", "name": "重斧", "slot": SlotType.WEAPON, "base_attack": 15, "base_defense": 0, "base_hp": 0, "base_speed": -5},
		{"id": "helm_iron", "name": "铁盔", "slot": SlotType.HELMET, "base_attack": 0, "base_defense": 3, "base_hp": 5, "base_speed": 0},
		{"id": "helm_wisdom", "name": "智慧之冠", "slot": SlotType.HELMET, "base_attack": 2, "base_defense": 2, "base_hp": 10, "base_speed": 0},
		{"id": "helm_shadow", "name": "暗影兜帽", "slot": SlotType.HELMET, "base_attack": 0, "base_defense": 1, "base_hp": 0, "base_speed": 8},
		{"id": "armor_leather", "name": "皮甲", "slot": SlotType.ARMOR, "base_attack": 0, "base_defense": 5, "base_hp": 10, "base_speed": 0},
		{"id": "armor_plate", "name": "板甲", "slot": SlotType.ARMOR, "base_attack": 0, "base_defense": 12, "base_hp": 20, "base_speed": -5},
		{"id": "armor_robe", "name": "法袍", "slot": SlotType.ARMOR, "base_attack": 3, "base_defense": 2, "base_hp": 5, "base_speed": 3},
		{"id": "boots_iron", "name": "铁靴", "slot": SlotType.BOOTS, "base_attack": 0, "base_defense": 3, "base_hp": 0, "base_speed": 5},
		{"id": "boots_wind", "name": "风行靴", "slot": SlotType.BOOTS, "base_attack": 0, "base_defense": 1, "base_hp": 0, "base_speed": 15},
		{"id": "boots_heavy", "name": "重铁靴", "slot": SlotType.BOOTS, "base_attack": 0, "base_defense": 8, "base_hp": 5, "base_speed": -3},
		{"id": "ring_power", "name": "力量之戒", "slot": SlotType.ACCESSORY, "base_attack": 5, "base_defense": 0, "base_hp": 0, "base_speed": 0},
		{"id": "ring_guard", "name": "守护之戒", "slot": SlotType.ACCESSORY, "base_attack": 0, "base_defense": 5, "base_hp": 15, "base_speed": 0},
		{"id": "amulet_luck", "name": "幸运护符", "slot": SlotType.ACCESSORY, "base_attack": 2, "base_defense": 2, "base_hp": 5, "base_speed": 5},
	]


func generate_item(rarity: Rarity, floor_level: int = 1) -> Dictionary:
	var template = item_templates[randi() % item_templates.size()].duplicate()
	var mult = RARITY_MULTIPLIERS[rarity]
	var rand_factor = randf_range(0.85, 1.15)
	var floor_bonus = 1.0 + (floor_level - 1) * 0.1

	template["rarity"] = rarity
	template["rarity_name"] = RARITY_NAMES[rarity]
	template["color"] = RARITY_COLORS[rarity]
	template["attack"] = int(template["base_attack"] * mult * rand_factor * floor_bonus)
	template["defense"] = int(template["base_defense"] * mult * rand_factor * floor_bonus)
	template["hp"] = int(template["base_hp"] * mult * rand_factor * floor_bonus)
	template["speed"] = int(template["base_speed"] * mult * rand_factor * floor_bonus)
	template["sell_price"] = int((rarity + 1) * 5 * rand_factor * floor_bonus)
	template["uid"] = str(randi()) + str(Time.get_ticks_msec())

	return template


func get_item_display_name(item: Dictionary) -> String:
	return "[%s] %s" % [RARITY_NAMES[item["rarity"]], item["name"]]
