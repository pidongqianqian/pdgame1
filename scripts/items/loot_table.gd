extends Node

const BASE_DROP_CHANCE = 0.15

const RARITY_WEIGHTS = {
	ItemDatabase.Rarity.COMMON: 60.0,
	ItemDatabase.Rarity.UNCOMMON: 25.0,
	ItemDatabase.Rarity.RARE: 10.0,
	ItemDatabase.Rarity.EPIC: 4.0,
	ItemDatabase.Rarity.LEGENDARY: 1.0,
}


func should_drop(is_boss: bool = false) -> bool:
	var chance = BASE_DROP_CHANCE
	if is_boss:
		chance = 1.0
	return randf() < chance


func roll_rarity(luck_modifier: float = 1.0, is_boss: bool = false) -> ItemDatabase.Rarity:
	var weights = RARITY_WEIGHTS.duplicate()
	if luck_modifier > 1.0:
		weights[ItemDatabase.Rarity.COMMON] *= (1.0 / luck_modifier)
		weights[ItemDatabase.Rarity.UNCOMMON] *= luck_modifier
		weights[ItemDatabase.Rarity.RARE] *= luck_modifier * 1.2
		weights[ItemDatabase.Rarity.EPIC] *= luck_modifier * 1.5
		weights[ItemDatabase.Rarity.LEGENDARY] *= luck_modifier * 2.0

	if is_boss:
		weights[ItemDatabase.Rarity.COMMON] *= 0.3
		weights[ItemDatabase.Rarity.RARE] *= 2.0
		weights[ItemDatabase.Rarity.EPIC] *= 3.0
		weights[ItemDatabase.Rarity.LEGENDARY] *= 5.0

	var total = 0.0
	for w in weights.values():
		total += w

	var roll = randf() * total
	var cumulative = 0.0
	for rarity in weights:
		cumulative += weights[rarity]
		if roll <= cumulative:
			return rarity

	return ItemDatabase.Rarity.COMMON


func generate_loot(is_boss: bool = false) -> Array[Dictionary]:
	var drops: Array[Dictionary] = []
	var luck = GameManager.get_luck_modifier()
	var drop_count = 1
	if is_boss:
		drop_count = randi_range(2, 4)

	for i in drop_count:
		if should_drop(is_boss):
			var rarity = roll_rarity(luck, is_boss)
			var item = ItemDatabase.generate_item(rarity, GameManager.current_floor)
			drops.append(item)

	# 技能卷轴掉落（稀有度>=Rare时5%几率）
	if not drops.is_empty():
		var best_rarity: int = 0
		for d in drops:
			best_rarity = maxi(best_rarity, d.get("rarity", 0))
		if best_rarity >= 2 and randf() < 0.05:
			drops.append(_make_skill_scroll())

	return drops


func _make_skill_scroll() -> Dictionary:
	var passives = SkillDatabase.get_random_passives(1)
	var pid: String = passives[0] if passives.size() > 0 else "power"
	var pdata: Dictionary = SkillDatabase.PASSIVE_TALENTS[pid]
	return {
		"name": "天赋卷轴·%s" % pdata["name"],
		"rarity": 2,
		"rarity_name": "稀有",
		"color": Color(0.3, 0.5, 1.0),
		"slot": -1,
		"type": "skill_scroll",
		"passive_id": pid,
		"desc": pdata["desc"],
	}
