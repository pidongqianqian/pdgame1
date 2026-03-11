extends Node2D

const PlayerScene   = preload("res://scenes/player/player.tscn")
const SlimeScene    = preload("res://scenes/enemies/enemy_slime.tscn")
const SkeletonScene = preload("res://scenes/enemies/enemy_skeleton.tscn")
const BossScene     = preload("res://scenes/enemies/boss_dark_knight.tscn")
const LootDropScene = preload("res://scenes/items/loot_drop.tscn")
const HUDScene      = preload("res://scenes/ui/hud.tscn")
const InventoryScene = preload("res://scenes/ui/inventory_screen.tscn")

var dungeon: DungeonGenerator
var player: Player
var entities: Node2D
var hud: CanvasLayer
var inventory_ui: CanvasLayer
var ambience: Node
var enemies_alive: int = 0
var _floor_clear_ui: CanvasLayer = null
var _game_over_ui: CanvasLayer = null
var _skill_select_ui: CanvasLayer = null


func _ready() -> void:
	GameManager.player_died.connect(_on_game_over)
	if NetworkManager.is_multiplayer_active():
		NetworkManager.host_disconnected.connect(_on_host_disconnected)
	_setup_dungeon()
	_setup_canvas_modulate()
	_spawn_player()
	_spawn_enemies()
	_setup_hud()
	_setup_inventory()
	_setup_ambience()
	_spawn_torch_lights()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		if inventory_ui and not inventory_ui.visible:
			inventory_ui.open()


func _setup_dungeon() -> void:
	dungeon = DungeonGenerator.new()
	dungeon.name = "DungeonGenerator"
	var tilemap_layer = TileMapLayer.new()
	tilemap_layer.name = "TileMapLayer"
	dungeon.add_child(tilemap_layer)
	add_child(dungeon)
	move_child(dungeon, 0)
	_create_runtime_tileset(tilemap_layer)
	dungeon.tilemap = tilemap_layer
	var player_count: int = NetworkManager.get_player_count()
	var seed_val: int = NetworkManager.current_dungeon_seed
	dungeon.generate(GameManager.current_floor, player_count, seed_val)
	dungeon.all_rooms_cleared.connect(_on_all_rooms_cleared)


func _create_runtime_tileset(tilemap_layer: TileMapLayer) -> void:
	var ts = TileSet.new()
	ts.tile_size = Vector2i(16, 16)

	var floor_tex = load("res://assets/sprites/tiles/floor.png")
	var wall_tex  = load("res://assets/sprites/tiles/wall.png")
	var void_tex  = load("res://assets/sprites/tiles/void.png")

	if floor_tex:
		var floor_src = TileSetAtlasSource.new()
		floor_src.texture = floor_tex
		floor_src.texture_region_size = Vector2i(16, 16)
		floor_src.create_tile(Vector2i(0, 0))
		ts.add_source(floor_src, 0)

	if wall_tex:
		var wall_src = TileSetAtlasSource.new()
		wall_src.texture = wall_tex
		wall_src.texture_region_size = Vector2i(16, 16)
		wall_src.create_tile(Vector2i(0, 0))
		ts.add_source(wall_src, 1)

		ts.add_physics_layer()
		ts.set_physics_layer_collision_layer(0, 1)
		ts.set_physics_layer_collision_mask(0, 6)
		var tile_data = wall_src.get_tile_data(Vector2i(0, 0), 0)
		tile_data.add_collision_polygon(0)
		var polygon = PackedVector2Array([
			Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)
		])
		tile_data.set_collision_polygon_points(0, 0, polygon)

	if void_tex:
		var void_src = TileSetAtlasSource.new()
		void_src.texture = void_tex
		void_src.texture_region_size = Vector2i(16, 16)
		void_src.create_tile(Vector2i(0, 0))
		ts.add_source(void_src, 2)

	tilemap_layer.tile_set = ts
	tilemap_layer.collision_enabled = true


func _setup_canvas_modulate() -> void:
	pass


func _spawn_player() -> void:
	entities = $Entities
	if NetworkManager.is_multiplayer_active():
		_spawn_all_players()
		return
	# Single-player path (unchanged)
	if player and is_instance_valid(player):
		player.position = dungeon.get_spawn_position()
		return
	player = PlayerScene.instantiate()
	player.position = dungeon.get_spawn_position()
	entities.add_child(player)
	GameManager.player_node = player


func _spawn_all_players() -> void:
	var my_id: int = NetworkManager.get_local_peer_id()
	var spawn_center: Vector2 = dungeon.get_spawn_position()
	var sorted_ids: Array = NetworkManager.get_sorted_peer_ids()

	for i in sorted_ids.size():
		var peer_id: int = sorted_ids[i]
		var cls: int = NetworkManager.player_info[peer_id].get("class", 0)
		var offset: Vector2 = Vector2(i * 14 - (sorted_ids.size() - 1) * 7, 0)
		var spos: Vector2 = dungeon.clamp_to_floor(spawn_center + offset, spawn_center)

		# Keep existing node if already spawned (floor transition)
		var existing: Player = GameManager.player_nodes.get(peer_id) as Player
		if existing and is_instance_valid(existing):
			existing.position = spos
			continue

		var p: Player = PlayerScene.instantiate()
		p.name = "Player_%d" % peer_id
		p.position = spos
		p.set_multiplayer_authority(peer_id)
		p.initial_class = cls
		entities.add_child(p)

		GameManager.player_nodes[peer_id] = p
		if peer_id == my_id:
			player = p
			GameManager.player_node = p


func _spawn_enemies() -> void:
	enemies_alive = 0
	var player_count: int = NetworkManager.get_player_count()
	# Enemy HP scales with player count
	var hp_mult: float = 1.0 + (player_count - 1) * 0.3
	# In multiplayer only host spawns enemies (all clients get identical enemies via RNG seed)
	var is_host: bool = (not NetworkManager.is_multiplayer_active()) or multiplayer.is_server()

	for i in range(1, dungeon.rooms.size()):
		var is_boss_room: bool = (i == dungeon.boss_room_index)
		var base_count: int = randi_range(2 + player_count - 1, 3 + GameManager.current_floor + player_count - 1)
		var enemy_count: int = 1 if is_boss_room else base_count
		dungeon.room_enemy_counts[i] = enemy_count

		if is_boss_room:
			var boss = BossScene.instantiate()
			boss.name = "Boss_Room_%d" % i
			boss.position = dungeon.get_room_center(i)
			boss.room_index = i
			if hp_mult > 1.0:
				boss.max_hp = int(boss.max_hp * hp_mult)
			boss.died_in_room.connect(_on_enemy_died_in_room)
			if is_host:
				boss.set_multiplayer_authority(1)
			entities.add_child(boss)
			enemies_alive += 1
		else:
			for j in enemy_count:
				var enemy: Node2D
				if randf() > 0.5:
					enemy = SlimeScene.instantiate()
				else:
					enemy = SkeletonScene.instantiate()
				enemy.name = "Enemy_%d_%d" % [i, j]
				var epos: Vector2 = dungeon.get_random_position_in_room(i)
				# 二次校验，确保位置落在地板上
				if not dungeon.is_floor_at(epos):
					epos = dungeon.get_room_center(i)
				enemy.position = epos
				enemy.room_index = i
				if hp_mult > 1.0:
					(enemy as EnemyBase).max_hp = int((enemy as EnemyBase).max_hp * hp_mult)
				enemy.died_in_room.connect(_on_enemy_died_in_room)
				if is_host:
					enemy.set_multiplayer_authority(1)
				entities.add_child(enemy)
				enemies_alive += 1


func _spawn_torch_lights() -> void:
	if not ambience or not ambience.has_method("add_torch_light"):
		return

	var ts: int = dungeon.TILE_SIZE
	for i in range(dungeon.rooms.size()):
		var room: Rect2i = dungeon.rooms[i]
		var rw: int = room.size.x
		var rh: int = room.size.y
		var area: int = rw * rh

		var left:   float = (room.position.x + 1) * ts + ts / 2.0
		var right:  float = (room.position.x + rw - 2) * ts + ts / 2.0
		var top:    float = (room.position.y + 1) * ts + ts / 2.0
		var bottom: float = (room.position.y + rh - 2) * ts + ts / 2.0
		var cx: float = (room.position.x + rw / 2.0) * ts
		var cy: float = (room.position.y + rh / 2.0) * ts

		if area >= 80:
			ambience.add_torch_light(Vector2(left, top))
			ambience.add_torch_light(Vector2(right, top))
			ambience.add_torch_light(Vector2(left, bottom))
			ambience.add_torch_light(Vector2(right, bottom))
			ambience.add_torch_light(Vector2(cx, cy))
		elif area >= 50:
			ambience.add_torch_light(Vector2(left, top))
			ambience.add_torch_light(Vector2(right, bottom))
			ambience.add_torch_light(Vector2(cx, cy))
		else:
			ambience.add_torch_light(Vector2(left, cy))
			ambience.add_torch_light(Vector2(right, cy))


func _setup_hud() -> void:
	hud = HUDScene.instantiate()
	add_child(hud)


func _setup_inventory() -> void:
	inventory_ui = InventoryScene.instantiate()
	add_child(inventory_ui)


func _setup_ambience() -> void:
	var ambience_script = load("res://scripts/dungeon/dungeon_ambience.gd")
	ambience = CanvasLayer.new()
	ambience.set_script(ambience_script)
	add_child(ambience)


func _on_enemy_died_in_room(room_index: int, enemy_pos: Vector2, is_boss: bool, gold: int, xp: int = 12) -> void:
	enemies_alive -= 1
	dungeon.on_enemy_killed_in_room(room_index)
	_try_spawn_loot(enemy_pos, is_boss)
	_spawn_gold_coins(enemy_pos, gold, is_boss)
	_grant_xp(xp)


func _spawn_gold_coins(pos: Vector2, total_gold: int, is_boss: bool) -> void:
	var GoldScript = load("res://scripts/items/loot_gold.gd")
	if not GoldScript:
		return
	var coins: Array[Dictionary] = []
	if is_boss:
		coins.append({"amount": total_gold, "offset": Vector2.ZERO})
	else:
		var count = 2 if total_gold < 10 else 3
		var per = total_gold / count
		for i in count:
			coins.append({
				"amount": per + (total_gold % count if i == 0 else 0),
				"offset": Vector2(randf_range(-6, 6), randf_range(-6, 6))
			})

	for coin_data in coins:
		var raw_pos: Vector2 = pos + coin_data["offset"]
		var safe_pos: Vector2 = dungeon.clamp_to_floor(raw_pos, pos)
		var coin = Area2D.new()
		coin.set_script(GoldScript)
		coin.position = safe_pos
		coin.gold_amount = coin_data["amount"]
		entities.add_child(coin)


func _grant_xp(amount: int) -> void:
	if NetworkManager.is_multiplayer_active():
		# Host 给所有存活玩家分发 XP
		if multiplayer.is_server():
			for peer_id in GameManager.player_nodes:
				var p: Node2D = GameManager.player_nodes[peer_id]
				if p and is_instance_valid(p) and (p as Player).current_state != Player.State.DEAD:
					_rpc_grant_xp.rpc_id(peer_id, amount)
		return
	_apply_local_xp(amount)


@rpc("authority", "call_local", "reliable")
func _rpc_grant_xp(amount: int) -> void:
	_apply_local_xp(amount)


func _apply_local_xp(amount: int) -> void:
	if not player or not is_instance_valid(player):
		return
	if player.current_state == Player.State.DEAD:
		return
	var kill_heal: int = int(player.stats.get_passive_value("kill_heal"))
	if kill_heal > 0:
		player.stats.heal(kill_heal)
	var leveled: bool = player.stats.add_xp(amount)
	if leveled:
		_show_level_up_select()


func _show_level_up_select() -> void:
	if _skill_select_ui:
		return
	var ui_script = load("res://scripts/ui/skill_select_ui.gd")
	if not ui_script:
		return
	_skill_select_ui = CanvasLayer.new()
	_skill_select_ui.set_script(ui_script)
	_skill_select_ui.layer = 18
	add_child(_skill_select_ui)
	_skill_select_ui.setup_passive_select(player)
	_skill_select_ui.selection_made.connect(_on_skill_selected)


func _on_skill_selected() -> void:
	if _skill_select_ui:
		_skill_select_ui.queue_free()
		_skill_select_ui = null


func _try_spawn_loot(pos: Vector2, is_boss: bool) -> void:
	var drops = LootTable.generate_loot(is_boss)
	for item in drops:
		var raw_pos: Vector2 = pos + Vector2(randf_range(-6, 6), randf_range(-6, 6))
		var safe_pos: Vector2 = dungeon.clamp_to_floor(raw_pos, pos)
		var loot = LootDropScene.instantiate()
		loot.position = safe_pos
		loot.item_data = item
		entities.add_child(loot)


func _on_all_rooms_cleared() -> void:
	await get_tree().create_timer(0.8).timeout
	if NetworkManager.is_multiplayer_active() and multiplayer.is_server():
		_rpc_show_floor_clear.rpc()
	else:
		_show_floor_clear_ui()


@rpc("authority", "call_local", "reliable")
func _rpc_show_floor_clear() -> void:
	_show_floor_clear_ui()


const SHOP_POOL = [
	{"name": "生命药水",   "desc": "恢复 60 点生命",       "cost": 35,  "type": "heal",     "value": 60},
	{"name": "大生命药水", "desc": "恢复 150 点生命",      "cost": 75,  "type": "heal",     "value": 150},
	{"name": "力量晶石",   "desc": "攻击力 +10（本局）",   "cost": 80,  "type": "atk",      "value": 10},
	{"name": "防御符文",   "desc": "防御力 +6（本局）",    "cost": 65,  "type": "def",      "value": 6},
	{"name": "风之羽",     "desc": "移动速度 +15（本局）", "cost": 55,  "type": "spd",      "value": 15},
	{"name": "神秘宝箱",   "desc": "随机普通或精良装备",   "cost": 90,  "type": "item",     "value": 1},
	{"name": "稀有宝箱",   "desc": "随机稀有或史诗装备",   "cost": 160, "type": "item",     "value": 2},
	{"name": "天赋卷轴",   "desc": "随机获得一个被动天赋", "cost": 100, "type": "talent",   "value": 0},
]


func _show_floor_clear_ui() -> void:
	if _floor_clear_ui:
		return

	_floor_clear_ui = CanvasLayer.new()
	_floor_clear_ui.layer = 15
	add_child(_floor_clear_ui)

	# 整体容器（底部）
	var root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	root.offset_top = -148.0
	root.add_theme_constant_override("separation", 0)
	_floor_clear_ui.add_child(root)

	# ── 商店区 ──────────────────────────────────────
	var shop_bg = PanelContainer.new()
	shop_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var shop_sb = StyleBoxFlat.new()
	shop_sb.bg_color = Color(0.05, 0.03, 0.10, 0.92)
	shop_sb.border_color = Color(0.4, 0.3, 0.6, 0.7)
	shop_sb.set_border_width_all(1)
	shop_sb.set_content_margin_all(8)
	shop_bg.add_theme_stylebox_override("panel", shop_sb)
	root.add_child(shop_bg)

	var shop_vbox = VBoxContainer.new()
	shop_vbox.add_theme_constant_override("separation", 5)
	shop_bg.add_child(shop_vbox)

	# 商店标题 + 当前金币
	var shop_header = HBoxContainer.new()
	shop_vbox.add_child(shop_header)

	var shop_title = Label.new()
	shop_title.text = "⚔  神秘商人"
	shop_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_title.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_BODY)
	shop_title.add_theme_color_override("font_color", Color(0.75, 0.55, 1.0))
	shop_header.add_child(shop_title)

	var gold_lbl = Label.new()
	gold_lbl.name = "GoldLabel"
	gold_lbl.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_SMALL)
	gold_lbl.add_theme_color_override("font_color", UITheme.COLORS["text_gold"])
	gold_lbl.text = "持有金币：%d" % GameManager.gold
	shop_header.add_child(gold_lbl)

	# 商品列表（随机选 4 件）
	var pool = SHOP_POOL.duplicate()
	pool.shuffle()
	var items_row = HBoxContainer.new()
	items_row.add_theme_constant_override("separation", 6)
	shop_vbox.add_child(items_row)

	for i in 4:
		var item = pool[i % pool.size()]
		items_row.add_child(_create_shop_item(item, gold_lbl))

	# ── 清层提示 + 进入按钮 ──────────────────────────
	var bottom_bg = PanelContainer.new()
	bottom_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_bg.add_theme_stylebox_override("panel", _make_clear_panel())
	root.add_child(bottom_bg)

	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	bottom_bg.add_child(hbox)

	var msg = Label.new()
	msg.text = "✦  所有房间已清理  ✦"
	msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_BODY)
	msg.add_theme_color_override("font_color", UITheme.COLORS["text_gold"])
	hbox.add_child(msg)

	var hint = Label.new()
	hint.text = "捡装备、买东西，准备好再出发"
	hint.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_SMALL)
	hint.add_theme_color_override("font_color", UITheme.COLORS["text_dim"])
	hbox.add_child(hint)

	var talent_btn = Button.new()
	talent_btn.text = "  选择天赋  ✦"
	talent_btn.custom_minimum_size = Vector2(100, 32)
	UITheme.style_button(talent_btn, UITheme.FONT_SIZE_BODY)
	talent_btn.add_theme_color_override("font_color", Color(0.6, 0.9, 0.4))
	talent_btn.add_theme_stylebox_override("normal", _make_next_btn_style(false))
	talent_btn.add_theme_stylebox_override("hover",  _make_next_btn_style(true))
	talent_btn.pressed.connect(_on_floor_talent_select)
	hbox.add_child(talent_btn)

	var btn = Button.new()
	btn.text = "  进入第 %d 层  ▶" % (GameManager.current_floor + 1)
	btn.custom_minimum_size = Vector2(130, 32)
	UITheme.style_button(btn, UITheme.FONT_SIZE_BODY)
	btn.add_theme_color_override("font_color", UITheme.COLORS["text_gold"])
	btn.add_theme_stylebox_override("normal", _make_next_btn_style(false))
	btn.add_theme_stylebox_override("hover",  _make_next_btn_style(true))
	btn.pressed.connect(_on_confirm_next_floor)
	hbox.add_child(btn)

	# 入场动画
	root.modulate.a = 0.0
	root.position.y = 24.0
	var tween = create_tween()
	tween.tween_property(root, "modulate:a", 1.0, 0.4)
	tween.parallel().tween_property(root, "position:y", 0.0, 0.4).set_trans(Tween.TRANS_BACK)


func _create_shop_item(item: Dictionary, gold_lbl: Label) -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_sb = StyleBoxFlat.new()
	card_sb.bg_color = Color(0.10, 0.07, 0.18, 0.85)
	card_sb.border_color = Color(0.35, 0.25, 0.55, 0.7)
	card_sb.set_border_width_all(1)
	card_sb.set_corner_radius_all(2)
	card_sb.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel", card_sb)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	card.add_child(vbox)

	var name_lbl = Label.new()
	name_lbl.text = item["name"]
	name_lbl.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_SMALL)
	name_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 1.0))
	vbox.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = item["desc"]
	desc_lbl.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_TINY)
	desc_lbl.add_theme_color_override("font_color", UITheme.COLORS["text_dim"])
	vbox.add_child(desc_lbl)

	var buy_btn = Button.new()
	buy_btn.text = "  %d 金  " % item["cost"]
	buy_btn.custom_minimum_size = Vector2(0, 20)
	buy_btn.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_SMALL)
	buy_btn.add_theme_color_override("font_color", UITheme.COLORS["text_gold"])
	buy_btn.add_theme_stylebox_override("normal", _make_next_btn_style(false))
	buy_btn.add_theme_stylebox_override("hover",  _make_next_btn_style(true))
	buy_btn.add_theme_stylebox_override("disabled", _make_disabled_style())
	vbox.add_child(buy_btn)

	# 金币不足时禁用
	if GameManager.gold < item["cost"]:
		buy_btn.disabled = true

	buy_btn.pressed.connect(func():
		if GameManager.gold < item["cost"]:
			return
		GameManager.add_gold(-item["cost"])
		gold_lbl.text = "持有金币：%d" % GameManager.gold
		buy_btn.disabled = true
		buy_btn.text = "  已购买  "
		_apply_shop_item(item)
	)
	return card


func _apply_shop_item(item: Dictionary) -> void:
	if not player or not is_instance_valid(player):
		return
	match item["type"]:
		"heal":
			player.stats.heal(item["value"])
		"atk":
			player.stats.attack += item["value"]
		"def":
			player.stats.defense += item["value"]
		"spd":
			player.stats.speed += item["value"]
		"item":
			var rarity_min: int = item["value"]
			var rarity = rarity_min + randi() % 2
			rarity = clampi(rarity, 0, 4)
			var new_item = ItemDatabase.generate_item(rarity, GameManager.current_floor)
			if not player.stats.add_to_inventory(new_item):
				player.stats.equip_item(new_item)
			var hud_nodes = get_tree().get_nodes_in_group("hud")
			if not hud_nodes.is_empty() and hud_nodes[0].has_method("show_pickup_text"):
				hud_nodes[0].show_pickup_text(
					"获得 [%s] %s" % [new_item.get("rarity_name",""), new_item.get("name","")],
					new_item.get("color", Color.WHITE)
				)
		"talent":
			var passives = SkillDatabase.get_random_passives(1)
			if passives.size() > 0:
				var pid: String = passives[0]
				player.stats.learn_passive(pid)
				var pdata: Dictionary = SkillDatabase.PASSIVE_TALENTS[pid]
				var hud_nodes2 = get_tree().get_nodes_in_group("hud")
				if not hud_nodes2.is_empty() and hud_nodes2[0].has_method("show_pickup_text"):
					hud_nodes2[0].show_pickup_text(
						"习得天赋 [%s] %s" % [pdata["icon"], pdata["name"]],
						UITheme.COLORS["text_gold"]
					)


func _make_clear_panel() -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.04, 0.10, 0.88)
	sb.border_color = UITheme.COLORS["text_gold"]
	sb.set_border_width_all(1)
	sb.set_content_margin_all(10)
	return sb


func _make_disabled_style() -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.10, 0.14, 0.6)
	sb.border_color = Color(0.25, 0.20, 0.30, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(6)
	return sb


func _make_next_btn_style(hover: bool) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.35, 0.22, 0.05, 0.92) if hover else Color(0.22, 0.14, 0.03, 0.85)
	sb.border_color = UITheme.COLORS["text_gold"]
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(6)
	return sb


func _on_floor_talent_select() -> void:
	if _skill_select_ui or not player or not is_instance_valid(player):
		return
	var ui_script = load("res://scripts/ui/skill_select_ui.gd")
	if not ui_script:
		return
	_skill_select_ui = CanvasLayer.new()
	_skill_select_ui.set_script(ui_script)
	_skill_select_ui.layer = 18
	add_child(_skill_select_ui)
	_skill_select_ui.setup_floor_reward(player)
	_skill_select_ui.selection_made.connect(_on_skill_selected)


func _on_confirm_next_floor() -> void:
	if _floor_clear_ui:
		_floor_clear_ui.queue_free()
		_floor_clear_ui = null

	if NetworkManager.is_multiplayer_active():
		if multiplayer.is_server():
			GameManager.advance_floor()
			_rpc_advance_floor.rpc(GameManager.current_floor)
	else:
		GameManager.advance_floor()
		if ambience and ambience.has_method("flash_transition"):
			ambience.flash_transition(Color.WHITE, 0.5)
		await get_tree().create_timer(0.5).timeout
		_next_floor()


@rpc("authority", "call_local", "reliable")
func _rpc_advance_floor(new_floor: int) -> void:
	GameManager.current_floor = new_floor
	NetworkManager.revive_all()
	if ambience and ambience.has_method("flash_transition"):
		ambience.flash_transition(Color.WHITE, 0.5)
	await get_tree().create_timer(0.5).timeout
	_next_floor()


func _next_floor() -> void:
	if ambience and ambience.has_method("clear_torches"):
		ambience.clear_torches()

	# 清理敌人和战利品，但保留玩家节点
	for child in entities.get_children():
		var keep: bool = false
		if NetworkManager.is_multiplayer_active():
			keep = GameManager.player_nodes.values().has(child)
		else:
			keep = (child == player)
		if not keep:
			child.queue_free()

	# 重新生成地图
	var player_count: int = NetworkManager.get_player_count()
	var seed_val: int = NetworkManager.current_dungeon_seed
	dungeon.generate(GameManager.current_floor, player_count, seed_val)

	# 单人直接恢复，多人在 _spawn_player 里统一复活
	if not NetworkManager.is_multiplayer_active():
		if player and is_instance_valid(player):
			player.stats.heal(100)

	_spawn_player()
	_spawn_enemies()
	_spawn_torch_lights()

	# 多人：复活死亡玩家（恢复 50% 血量）
	if NetworkManager.is_multiplayer_active():
		for peer_id in GameManager.player_nodes:
			var p: Node2D = GameManager.player_nodes[peer_id]
			if p and is_instance_valid(p):
				if p.has_method("revive"):
					p.revive()
				else:
					# 如果没有专用方法，直接补血
					if p.get("stats") != null:
						p.stats.heal(p.stats.max_hp / 2)

	# 更新氛围色调
	if ambience and ambience.has_method("_update_floor_theme"):
		ambience._update_floor_theme()


# ═══════════════════════════════════════════════════════════════
# Game Over UI
# ═══════════════════════════════════════════════════════════════

func _on_game_over() -> void:
	# 死亡时关闭可能存在的升级选择弹窗
	if _skill_select_ui:
		get_tree().paused = false
		_skill_select_ui.queue_free()
		_skill_select_ui = null
	await get_tree().create_timer(1.2).timeout
	_show_game_over_ui()


func _show_game_over_ui() -> void:
	if _game_over_ui:
		return

	_game_over_ui = CanvasLayer.new()
	_game_over_ui.layer = 20
	add_child(_game_over_ui)

	# 全屏半透明遮罩
	var overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_game_over_ui.add_child(overlay)
	var fade_tw = create_tween()
	fade_tw.tween_property(overlay, "color:a", 0.55, 0.8)

	# 中心面板
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -140
	panel.offset_right = 140
	panel.offset_top = -90
	panel.offset_bottom = 90
	var panel_sb = StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.06, 0.04, 0.10, 0.95)
	panel_sb.border_color = Color(0.7, 0.2, 0.2, 0.8)
	panel_sb.set_border_width_all(2)
	panel_sb.set_corner_radius_all(4)
	panel_sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", panel_sb)
	_game_over_ui.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# 标题
	var title = Label.new()
	title.text = "你已陨落"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(title, UITheme.FONT_SIZE_TITLE, Color(0.9, 0.25, 0.2))
	vbox.add_child(title)

	# 战绩摘要
	var stats_text = "到达深渊第 %d 层  |  获得金币 %d  |  灵魂 %d" % [
		GameManager.current_floor, GameManager.gold, GameManager.souls
	]
	var stats_lbl = Label.new()
	stats_lbl.text = stats_text
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_label(stats_lbl, UITheme.FONT_SIZE_SMALL, UITheme.COLORS["text_dim"])
	vbox.add_child(stats_lbl)

	# 分隔线
	var sep = HSeparator.new()
	sep.add_theme_stylebox_override("separator", _make_separator_style())
	vbox.add_child(sep)

	var is_mp: bool = NetworkManager.is_multiplayer_active()

	if is_mp:
		_build_mp_game_over_buttons(vbox)
	else:
		_build_sp_game_over_buttons(vbox)

	# 入场动画
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.8, 0.8)
	panel.pivot_offset = panel.size / 2
	var tw = create_tween().set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.5).set_delay(0.3)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_delay(0.3)


func _build_sp_game_over_buttons(parent: VBoxContainer) -> void:
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	parent.add_child(btn_row)

	var restart_btn = Button.new()
	restart_btn.text = "  重新挑战  "
	restart_btn.custom_minimum_size = Vector2(110, 30)
	UITheme.style_button(restart_btn, UITheme.FONT_SIZE_BODY)
	restart_btn.add_theme_color_override("font_color", UITheme.COLORS["text_gold"])
	restart_btn.add_theme_stylebox_override("normal", _make_gameover_btn_style(Color(0.22, 0.16, 0.04), Color(0.8, 0.65, 0.2)))
	restart_btn.add_theme_stylebox_override("hover", _make_gameover_btn_style(Color(0.32, 0.24, 0.06), Color(1.0, 0.85, 0.3)))
	restart_btn.pressed.connect(_on_gameover_restart)
	btn_row.add_child(restart_btn)

	var menu_btn = Button.new()
	menu_btn.text = "  返回主菜单  "
	menu_btn.custom_minimum_size = Vector2(110, 30)
	UITheme.style_button(menu_btn, UITheme.FONT_SIZE_BODY)
	menu_btn.add_theme_stylebox_override("normal", _make_gameover_btn_style(Color(0.14, 0.10, 0.20), Color(0.4, 0.3, 0.6)))
	menu_btn.add_theme_stylebox_override("hover", _make_gameover_btn_style(Color(0.20, 0.16, 0.28), Color(0.5, 0.4, 0.7)))
	menu_btn.pressed.connect(_on_gameover_menu)
	btn_row.add_child(menu_btn)


func _build_mp_game_over_buttons(parent: VBoxContainer) -> void:
	var is_host: bool = multiplayer.is_server()

	if is_host:
		var hint = Label.new()
		hint.text = "你是房主，可以选择重新开始或解散房间"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UITheme.style_label(hint, UITheme.FONT_SIZE_SMALL, UITheme.COLORS["text_dim"])
		parent.add_child(hint)

		var btn_row = HBoxContainer.new()
		btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
		btn_row.add_theme_constant_override("separation", 12)
		parent.add_child(btn_row)

		var restart_btn = Button.new()
		restart_btn.text = "  重新开始  "
		restart_btn.custom_minimum_size = Vector2(110, 30)
		UITheme.style_button(restart_btn, UITheme.FONT_SIZE_BODY)
		restart_btn.add_theme_color_override("font_color", UITheme.COLORS["text_gold"])
		restart_btn.add_theme_stylebox_override("normal", _make_gameover_btn_style(Color(0.22, 0.16, 0.04), Color(0.8, 0.65, 0.2)))
		restart_btn.add_theme_stylebox_override("hover", _make_gameover_btn_style(Color(0.32, 0.24, 0.06), Color(1.0, 0.85, 0.3)))
		restart_btn.pressed.connect(_on_gameover_mp_restart)
		btn_row.add_child(restart_btn)

		var disband_btn = Button.new()
		disband_btn.text = "  解散房间  "
		disband_btn.custom_minimum_size = Vector2(110, 30)
		UITheme.style_button(disband_btn, UITheme.FONT_SIZE_BODY)
		disband_btn.add_theme_stylebox_override("normal", _make_gameover_btn_style(Color(0.20, 0.06, 0.06), Color(0.6, 0.2, 0.2)))
		disband_btn.add_theme_stylebox_override("hover", _make_gameover_btn_style(Color(0.28, 0.08, 0.08), Color(0.8, 0.3, 0.3)))
		disband_btn.pressed.connect(_on_gameover_mp_disband)
		btn_row.add_child(disband_btn)
	else:
		var wait_lbl = Label.new()
		wait_lbl.text = "等待房主决定..."
		wait_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITheme.style_label(wait_lbl, UITheme.FONT_SIZE_BODY, Color(0.8, 0.7, 0.5))
		wait_lbl.name = "WaitLabel"
		parent.add_child(wait_lbl)

		var leave_btn = Button.new()
		leave_btn.text = "  退出房间  "
		leave_btn.custom_minimum_size = Vector2(110, 30)
		UITheme.style_button(leave_btn, UITheme.FONT_SIZE_BODY)
		leave_btn.add_theme_stylebox_override("normal", _make_gameover_btn_style(Color(0.14, 0.10, 0.20), Color(0.4, 0.3, 0.6)))
		leave_btn.add_theme_stylebox_override("hover", _make_gameover_btn_style(Color(0.20, 0.16, 0.28), Color(0.5, 0.4, 0.7)))
		leave_btn.pressed.connect(_on_gameover_mp_leave)
		parent.add_child(leave_btn)
		leave_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _make_gameover_btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(6)
	return sb


func _make_separator_style() -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.4, 0.2, 0.2, 0.5)
	sb.set_content_margin_all(0)
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	return sb


func _dismiss_game_over_ui() -> void:
	if _game_over_ui:
		_game_over_ui.queue_free()
		_game_over_ui = null


func _on_host_disconnected() -> void:
	_dismiss_game_over_ui()
	_dismiss_floor_clear_ui()
	NetworkManager.disconnect_all()
	var main_node = get_tree().current_scene
	if main_node and main_node.has_method("return_to_title"):
		main_node.return_to_title()


func _dismiss_floor_clear_ui() -> void:
	if _floor_clear_ui:
		_floor_clear_ui.queue_free()
		_floor_clear_ui = null


# ── 单人模式按钮回调 ──────────────────────────────────────────

func _on_gameover_restart() -> void:
	_dismiss_game_over_ui()
	var main_node = get_tree().current_scene
	if main_node and main_node.has_method("start_game"):
		main_node.start_game()


func _on_gameover_menu() -> void:
	_dismiss_game_over_ui()
	var main_node = get_tree().current_scene
	if main_node and main_node.has_method("return_to_title"):
		main_node.return_to_title()


# ── 多人模式按钮回调 ──────────────────────────────────────────

func _on_gameover_mp_restart() -> void:
	NetworkManager.revive_all()
	NetworkManager.current_dungeon_seed = randi()
	_rpc_mp_restart.rpc(NetworkManager.current_dungeon_seed)


func _on_gameover_mp_disband() -> void:
	_dismiss_game_over_ui()
	NetworkManager.disconnect_all()
	var main_node = get_tree().current_scene
	if main_node and main_node.has_method("return_to_title"):
		main_node.return_to_title()


func _on_gameover_mp_leave() -> void:
	_dismiss_game_over_ui()
	NetworkManager.disconnect_all()
	var main_node = get_tree().current_scene
	if main_node and main_node.has_method("return_to_title"):
		main_node.return_to_title()


@rpc("authority", "call_local", "reliable")
func _rpc_mp_restart(new_seed: int) -> void:
	_dismiss_game_over_ui()
	NetworkManager.current_dungeon_seed = new_seed
	NetworkManager.revive_all()
	GameManager.player_nodes.clear()
	var main_node = get_tree().current_scene
	if main_node and main_node.has_method("start_game"):
		main_node.start_game()
