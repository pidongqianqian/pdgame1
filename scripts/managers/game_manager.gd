extends Node

signal floor_changed(floor_num: int)
signal player_died
signal run_started
signal run_ended(success: bool)
signal gold_changed(amount: int)
signal souls_changed(amount: int)
signal xp_changed(current_xp: int, required_xp: int)
signal level_up(new_level: int)

enum GameState { TITLE, CLASS_SELECT, HUB, DUNGEON, PAUSED, GAME_OVER }
enum PlayerClass { WARRIOR, MAGE, RANGER, ROGUE }

# 职业定义：名称、描述、属性、专属颜色
const CLASS_DATA = {
	PlayerClass.WARRIOR: {
		"name": "战士",
		"title": "铁壁战士",
		"desc": "近身宽弧挥砍，受击无敌帧长\n适合喜欢正面硬刚的玩家",
		"color": Color(0.55, 0.75, 1.0),
		"icon": "⚔",
		"max_hp": 130, "attack": 12, "defense": 8,
		"speed": 55.0, "attack_cooldown": 0.40,
		"dodge_speed": 140.0, "dodge_duration": 0.28,
	},
	PlayerClass.MAGE: {
		"name": "法师",
		"title": "深渊法师",
		"desc": "发射追踪魔法弹，穿透一个敌人\n适合喜欢远程输出的玩家",
		"color": Color(0.75, 0.45, 1.0),
		"icon": "✦",
		"max_hp": 75,  "attack": 20, "defense": 3,
		"speed": 65.0, "attack_cooldown": 0.55,
		"dodge_speed": 220.0, "dodge_duration": 0.15,
	},
	PlayerClass.RANGER: {
		"name": "游侠",
		"title": "暗林游侠",
		"desc": "射出长程穿透箭矢，可移动时射击\n适合喜欢风筝走位的玩家",
		"color": Color(0.45, 1.0, 0.55),
		"icon": "➶",
		"max_hp": 100, "attack": 14, "defense": 5,
		"speed": 72.0, "attack_cooldown": 0.45,
		"dodge_speed": 180.0, "dodge_duration": 0.20,
	},
	PlayerClass.ROGUE: {
		"name": "刺客",
		"title": "暗影刺客",
		"desc": "极速双刀两连斩，闪避可穿刺冲锋\n适合喜欢高风险高回报的玩家",
		"color": Color(1.0, 0.55, 0.35),
		"icon": "匕",
		"max_hp": 88,  "attack": 11, "defense": 4,
		"speed": 78.0, "attack_cooldown": 0.18,
		"dodge_speed": 200.0, "dodge_duration": 0.22,
	},
}

var current_state: GameState = GameState.TITLE
var current_class: int = PlayerClass.WARRIOR
var current_floor: int = 1
var max_floor_reached: int = 0
var gold: int = 0
var souls: int = 0
var run_active: bool = false
var player_node: Node2D = null          # Local player (single-player compat)
var player_nodes: Dictionary = {}       # peer_id -> Player (multiplayer)

var permanent_upgrades: Dictionary = {
	"max_hp_bonus": 0,
	"attack_bonus": 0,
	"defense_bonus": 0,
	"luck_bonus": 0,
	"speed_bonus": 0,
}


func start_new_run() -> void:
	current_floor = 1
	gold = 0
	run_active = true
	current_state = GameState.DUNGEON
	run_started.emit()


func end_run(success: bool) -> void:
	run_active = false
	if current_floor > max_floor_reached:
		max_floor_reached = current_floor
	current_state = GameState.GAME_OVER if not success else GameState.HUB
	run_ended.emit(success)


func advance_floor() -> void:
	current_floor += 1
	floor_changed.emit(current_floor)


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


func add_souls(amount: int) -> void:
	souls += amount
	souls_changed.emit(souls)


func spend_souls(amount: int) -> bool:
	if souls >= amount:
		souls -= amount
		souls_changed.emit(souls)
		return true
	return false


func get_luck_modifier() -> float:
	var base: float = 1.0 + (permanent_upgrades["luck_bonus"] * 0.05) + (current_floor - 1) * 0.02
	if player_node and is_instance_valid(player_node) and player_node.get("stats") != null:
		base += player_node.stats.get_passive_value("luck_bonus")
	return base
