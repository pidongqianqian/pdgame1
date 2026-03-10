extends RefCounted
class_name EquipmentSystem

static func get_stat_summary(item: Dictionary) -> String:
	var parts: Array[String] = []
	if item.get("attack", 0) > 0:
		parts.append("攻击+%d" % item["attack"])
	if item.get("defense", 0) > 0:
		parts.append("防御+%d" % item["defense"])
	if item.get("hp", 0) > 0:
		parts.append("生命+%d" % item["hp"])
	var spd = item.get("speed", 0)
	if spd != 0:
		parts.append("速度%+d" % spd)
	return " ".join(parts)


static func compare_items(a: Dictionary, b: Dictionary) -> int:
	var score_a = a.get("attack", 0) + a.get("defense", 0) + a.get("hp", 0) + a.get("speed", 0)
	var score_b = b.get("attack", 0) + b.get("defense", 0) + b.get("hp", 0) + b.get("speed", 0)
	if score_a > score_b:
		return 1
	elif score_a < score_b:
		return -1
	return 0


static func get_item_tooltip(item: Dictionary) -> String:
	var rarity_name = item.get("rarity_name", "未知")
	var slot_name = ItemDatabase.SLOT_NAMES.get(item.get("slot", 0), "未知")
	var name = item.get("name", "未知物品")
	var stats_text = get_stat_summary(item)
	var price = item.get("sell_price", 0)
	return "[%s] %s\n类型: %s\n%s\n售价: %d金币" % [rarity_name, name, slot_name, stats_text, price]
