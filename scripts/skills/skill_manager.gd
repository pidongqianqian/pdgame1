extends Node
class_name SkillManager

signal skill_cooldown_changed(slot: int, remaining: float, total: float)
signal skill_used(skill_id: String, slot: int)

var _player: Player
var _cooldowns: Dictionary = {}  # slot (int) -> remaining (float)
var _regen_timer: float = 0.0

const REGEN_INTERVAL: float = 3.0


func setup(p: Player) -> void:
	_player = p


func _process(delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		return
	_update_cooldowns(delta)
	_update_regen(delta)
	_player.stats.update_buffs(delta)


func _update_cooldowns(delta: float) -> void:
	for slot in _cooldowns.keys():
		if _cooldowns[slot] > 0.0:
			_cooldowns[slot] -= delta
			var skill_id: String = SkillDatabase.get_skill_for_slot(GameManager.current_class, slot)
			var total_cd: float = 5.0
			if skill_id != "" and SkillDatabase.ACTIVE_SKILLS.has(skill_id):
				total_cd = SkillDatabase.ACTIVE_SKILLS[skill_id]["cooldown"]
			skill_cooldown_changed.emit(slot, maxf(_cooldowns[slot], 0.0), total_cd)
			if _cooldowns[slot] <= 0.0:
				_cooldowns[slot] = 0.0


func _update_regen(delta: float) -> void:
	if not _player.stats:
		return
	var regen_amount: float = _player.stats.get_passive_value("regen_amount")
	if regen_amount <= 0.0:
		return
	_regen_timer += delta
	if _regen_timer >= REGEN_INTERVAL:
		_regen_timer -= REGEN_INTERVAL
		_player.stats.heal(int(regen_amount))


func can_use_skill(slot: int) -> bool:
	if _player.current_state == Player.State.DEAD:
		return false
	if _player.current_state == Player.State.HURT:
		return false
	return _cooldowns.get(slot, 0.0) <= 0.0


func use_skill(slot: int) -> void:
	if not can_use_skill(slot):
		return
	var skill_id: String = SkillDatabase.get_skill_for_slot(GameManager.current_class, slot)
	if skill_id == "":
		return
	var data: Dictionary = SkillDatabase.ACTIVE_SKILLS[skill_id]
	_cooldowns[slot] = data["cooldown"]
	skill_used.emit(skill_id, slot)
	_execute_skill(skill_id, data)


func _execute_skill(skill_id: String, data: Dictionary) -> void:
	var effect_map: Dictionary = {
		"warrior_whirlwind": "res://scripts/skills/effects/skill_whirlwind.gd",
		"warrior_warcry": "res://scripts/skills/effects/skill_warcry.gd",
		"mage_fireball": "res://scripts/skills/effects/skill_fireball.gd",
		"mage_ice_nova": "res://scripts/skills/effects/skill_ice_nova.gd",
		"ranger_arrow_rain": "res://scripts/skills/effects/skill_arrow_rain.gd",
		"ranger_trap": "res://scripts/skills/effects/skill_trap.gd",
		"rogue_shadow_strike": "res://scripts/skills/effects/skill_shadow_strike.gd",
		"rogue_smoke_bomb": "res://scripts/skills/effects/skill_smoke_bomb.gd",
	}
	var script_path: String = effect_map.get(skill_id, "")
	if script_path == "":
		return
	var script = load(script_path)
	if not script:
		return
	var effect = Node2D.new()
	effect.set_script(script)
	_player.get_parent().add_child(effect)
	effect.execute(_player, data)
