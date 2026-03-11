extends Node

enum SkillType { ACTIVE, PASSIVE }
enum SkillSlot { SKILL_U, SKILL_L }

const ACTIVE_SKILLS: Dictionary = {
	# ── 战士 ──
	"warrior_whirlwind": {
		"name": "旋风斩",
		"desc": "旋转攻击周围所有敌人，造成150%攻击力伤害",
		"icon": "🌀",
		"class": GameManager.PlayerClass.WARRIOR,
		"slot": SkillSlot.SKILL_U,
		"cooldown": 5.0,
		"damage_mult": 1.5,
		"radius": 28.0,
	},
	"warrior_warcry": {
		"name": "战吼",
		"desc": "3秒内攻击+30%、防御+30%",
		"icon": "📢",
		"class": GameManager.PlayerClass.WARRIOR,
		"slot": SkillSlot.SKILL_L,
		"cooldown": 10.0,
		"duration": 3.0,
		"atk_mult": 0.3,
		"def_mult": 0.3,
	},
	# ── 法师 ──
	"mage_fireball": {
		"name": "火球术",
		"desc": "发射爆炸火球，落点AoE造成200%攻击力伤害",
		"icon": "🔥",
		"class": GameManager.PlayerClass.MAGE,
		"slot": SkillSlot.SKILL_U,
		"cooldown": 6.0,
		"damage_mult": 2.0,
		"explosion_radius": 24.0,
		"speed": 100.0,
	},
	"mage_ice_nova": {
		"name": "冰霜新星",
		"desc": "冻结周围敌人2秒，造成80%攻击力伤害",
		"icon": "❄",
		"class": GameManager.PlayerClass.MAGE,
		"slot": SkillSlot.SKILL_L,
		"cooldown": 8.0,
		"damage_mult": 0.8,
		"radius": 32.0,
		"freeze_duration": 2.0,
	},
	# ── 游侠 ──
	"ranger_arrow_rain": {
		"name": "箭雨",
		"desc": "扇形发射5支箭，每支造成60%攻击力伤害",
		"icon": "🏹",
		"class": GameManager.PlayerClass.RANGER,
		"slot": SkillSlot.SKILL_U,
		"cooldown": 5.0,
		"damage_mult": 0.6,
		"arrow_count": 5,
		"spread_angle": 60.0,
	},
	"ranger_trap": {
		"name": "陷阱",
		"desc": "放置地面陷阱，触发后造成120%攻击力+减速1.5秒",
		"icon": "⚡",
		"class": GameManager.PlayerClass.RANGER,
		"slot": SkillSlot.SKILL_L,
		"cooldown": 7.0,
		"damage_mult": 1.2,
		"slow_duration": 1.5,
		"trap_lifetime": 15.0,
	},
	# ── 刺客 ──
	"rogue_shadow_strike": {
		"name": "暗影突袭",
		"desc": "瞬移到最近敌人身后，造成250%攻击力伤害",
		"icon": "👤",
		"class": GameManager.PlayerClass.ROGUE,
		"slot": SkillSlot.SKILL_U,
		"cooldown": 6.0,
		"damage_mult": 2.5,
		"range": 80.0,
	},
	"rogue_smoke_bomb": {
		"name": "烟雾弹",
		"desc": "3秒内隐身+周围敌人减速50%",
		"icon": "💨",
		"class": GameManager.PlayerClass.ROGUE,
		"slot": SkillSlot.SKILL_L,
		"cooldown": 10.0,
		"duration": 3.0,
		"slow_percent": 0.5,
		"radius": 36.0,
	},
}

const PASSIVE_TALENTS: Dictionary = {
	"crit": {
		"name": "暴击",
		"desc": "15%几率造成双倍伤害",
		"icon": "⚔",
		"stackable": true,
		"per_stack": 0.15,
		"stat": "crit_chance",
	},
	"lifesteal": {
		"name": "吸血",
		"desc": "击杀敌人回复8HP",
		"icon": "♥",
		"stackable": true,
		"per_stack": 8,
		"stat": "kill_heal",
	},
	"thorns": {
		"name": "荆棘",
		"desc": "受击时反弹15%伤害给攻击者",
		"icon": "🛡",
		"stackable": true,
		"per_stack": 0.15,
		"stat": "thorns_percent",
	},
	"swift": {
		"name": "迅捷",
		"desc": "移动速度提升12%",
		"icon": "💨",
		"stackable": true,
		"per_stack": 0.12,
		"stat": "speed_mult",
	},
	"iron_skin": {
		"name": "铁壁",
		"desc": "防御力+5",
		"icon": "🛡",
		"stackable": true,
		"per_stack": 5,
		"stat": "defense_flat",
	},
	"berserker": {
		"name": "狂暴",
		"desc": "生命低于30%时攻击力+40%",
		"icon": "💢",
		"stackable": false,
		"per_stack": 0.4,
		"stat": "berserker_mult",
	},
	"fortune": {
		"name": "幸运",
		"desc": "提升掉落品质",
		"icon": "🍀",
		"stackable": true,
		"per_stack": 0.1,
		"stat": "luck_bonus",
	},
	"regen": {
		"name": "再生",
		"desc": "每3秒回复2HP",
		"icon": "💚",
		"stackable": true,
		"per_stack": 2,
		"stat": "regen_amount",
	},
	"evasion": {
		"name": "闪避",
		"desc": "10%几率完全免疫伤害",
		"icon": "✦",
		"stackable": true,
		"per_stack": 0.10,
		"stat": "evasion_chance",
	},
	"power": {
		"name": "强攻",
		"desc": "攻击力+8",
		"icon": "⚔",
		"stackable": true,
		"per_stack": 8,
		"stat": "attack_flat",
	},
}


func get_class_skills(cls: int) -> Array:
	var result: Array = []
	for key in ACTIVE_SKILLS:
		if ACTIVE_SKILLS[key]["class"] == cls:
			result.append(key)
	return result


func get_skill_for_slot(cls: int, slot: int) -> String:
	for key in ACTIVE_SKILLS:
		var s = ACTIVE_SKILLS[key]
		if s["class"] == cls and s["slot"] == slot:
			return key
	return ""


func get_random_passives(count: int, exclude: Array = []) -> Array:
	var pool: Array = []
	for key in PASSIVE_TALENTS:
		if key not in exclude or PASSIVE_TALENTS[key]["stackable"]:
			pool.append(key)
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))


func get_random_floor_rewards(count: int, cls: int, learned_passives: Array) -> Array:
	var pool: Array = []
	for key in PASSIVE_TALENTS:
		if key not in learned_passives or PASSIVE_TALENTS[key]["stackable"]:
			pool.append({"type": "passive", "id": key})
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))
