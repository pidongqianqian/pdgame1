extends Node2D

const PlayerScene   = preload("res://scenes/player/player.tscn")
const LootDropScene = preload("res://scenes/items/loot_drop.tscn")
const HUDScene      = preload("res://scenes/ui/hud.tscn")
const InventoryScene = preload("res://scenes/ui/inventory_screen.tscn")

enum DungeonTheme { CRYPT, FOREST, INFERNO, NECROPOLIS }

# 主题装饰物贴图池
const DECO_TEXTURES = {
	DungeonTheme.FOREST: [
		preload("res://assets/sprites/decorations/tree_pine.png"),
		preload("res://assets/sprites/decorations/pine_tall.png"),
		preload("res://assets/sprites/decorations/big_green_tree.png"),
		preload("res://assets/sprites/decorations/tree_small_green.png"),
		preload("res://assets/sprites/decorations/pl_bush_1.png"),
		preload("res://assets/sprites/decorations/pl_bush_2.png"),
		preload("res://assets/sprites/decorations/pl_bush_3.png"),
		preload("res://assets/sprites/decorations/pl_rock_1.png"),
		preload("res://assets/sprites/decorations/pl_rock_2.png"),
		preload("res://assets/sprites/decorations/pl_fern.png"),
		preload("res://assets/sprites/decorations/pl_flower_red.png"),
		preload("res://assets/sprites/decorations/pl_flower_blue.png"),
		preload("res://assets/sprites/decorations/pl_flower_yellow.png"),
		preload("res://assets/sprites/decorations/pl_flower_pink.png"),
		preload("res://assets/sprites/decorations/pl_log.png"),
		preload("res://assets/sprites/decorations/pl_stump.png"),
		preload("res://assets/sprites/decorations/mushroom_red.png"),
	],
	DungeonTheme.CRYPT: [
		preload("res://assets/sprites/decorations/barrel.png"),
		preload("res://assets/sprites/decorations/bucket.png"),
		preload("res://assets/sprites/decorations/bucket_water.png"),
		preload("res://assets/sprites/decorations/axe.png"),
	],
	DungeonTheme.INFERNO: [
		preload("res://assets/sprites/decorations/lava_rock_1.png"),
		preload("res://assets/sprites/decorations/lava_rock_2.png"),
		preload("res://assets/sprites/decorations/lava_glow_rock.png"),
		preload("res://assets/sprites/decorations/lava_torch.png"),
		preload("res://assets/sprites/decorations/lava_chest.png"),
		preload("res://assets/sprites/decorations/lava_chain.png"),
		preload("res://assets/sprites/decorations/barrel.png"),
	],
	DungeonTheme.NECROPOLIS: [
		preload("res://assets/sprites/decorations/barrel.png"),
		preload("res://assets/sprites/decorations/bucket.png"),
		preload("res://assets/sprites/decorations/axe.png"),
		preload("res://assets/sprites/decorations/bucket_water.png"),
	],
}

const THEME_CONFIG = {
	DungeonTheme.CRYPT: {
		"name": "石窟深渊",
		"enemies": [
			preload("res://scenes/enemies/enemy_slime.tscn"),
			preload("res://scenes/enemies/enemy_skeleton.tscn"),
		],
		"mini_bosses": [
			preload("res://scenes/enemies/boss_giant_slime.tscn"),
			preload("res://scenes/enemies/boss_skeleton_captain.tscn"),
		],
		"big_bosses": [
			preload("res://scenes/enemies/boss_dark_knight.tscn"),
		],
		"ambience": Color(0.12, 0.08, 0.18),
		"banner_color": Color(0.35, 0.25, 0.55),
	},
	DungeonTheme.FOREST: {
		"name": "地下森林",
		"enemies": [
			preload("res://scenes/enemies/enemy_goblin.tscn"),
			preload("res://scenes/enemies/enemy_mushroom.tscn"),
			preload("res://scenes/enemies/enemy_plant.tscn"),
		],
		"mini_bosses": [
			preload("res://scenes/enemies/boss_deer.tscn"),
		],
		"big_bosses": [
			preload("res://scenes/enemies/boss_necromancer.tscn"),
		],
		"ambience": Color(0.03, 0.10, 0.04),
		"banner_color": Color(0.2, 0.5, 0.15),
	},
	DungeonTheme.INFERNO: {
		"name": "熔岩炼狱",
		"enemies": [
			preload("res://scenes/enemies/enemy_eye_monster.tscn"),
			preload("res://scenes/enemies/enemy_skeleton.tscn"),
			preload("res://scenes/enemies/enemy_goblin.tscn"),
		],
		"mini_bosses": [
			preload("res://scenes/enemies/boss_giant_slime.tscn"),
			preload("res://scenes/enemies/boss_skeleton_captain.tscn"),
		],
		"big_bosses": [
			preload("res://scenes/enemies/boss_fire_elemental.tscn"),
		],
		"ambience": Color(0.18, 0.05, 0.02),
		"banner_color": Color(0.65, 0.2, 0.05),
	},
	DungeonTheme.NECROPOLIS: {
		"name": "亡灵殿堂",
		"enemies": [
			preload("res://scenes/enemies/enemy_skeleton.tscn"),
			preload("res://scenes/enemies/enemy_eye_monster.tscn"),
			preload("res://scenes/enemies/enemy_slime.tscn"),
		],
		"mini_bosses": [
			preload("res://scenes/enemies/boss_skeleton_captain.tscn"),
		],
		"big_bosses": [
			preload("res://scenes/enemies/boss_necromancer.tscn"),
			preload("res://scenes/enemies/boss_dark_knight.tscn"),
		],
		"ambience": Color(0.10, 0.06, 0.16),
		"banner_color": Color(0.4, 0.15, 0.55),
	},
}

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
var _skill_pts_btn: Button = null

var _disconnect_ui: CanvasLayer = null
var _pause_ui: CanvasLayer = null
var _run_restored: bool = false  # 防止换层时重复恢复存档

# Debug
var _debug_panel: CanvasLayer = null
var _debug_info_label: Label = null
const DEBUG_ENABLED: bool = true


func _ready() -> void:
	GameManager.player_died.connect(_on_game_over)
	if NetworkManager.is_multiplayer_active():
		NetworkManager.host_disconnected.connect(_on_host_disconnected)
		NetworkManager.player_disconnected.connect(_on_peer_disconnected)
	entities = $Entities
	_setup_dungeon()
	_setup_canvas_modulate()
	_spawn_player()
	_spawn_enemies()
	_setup_hud()
	_setup_inventory()
	_setup_ambience()
	_spawn_torch_lights()
	_setup_touch_controls()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if inventory_ui and inventory_ui.visible:
			inventory_ui._on_close()
			get_viewport().set_input_as_handled()
		elif _pause_ui == null:
			_show_pause_menu()
			get_viewport().set_input_as_handled()
		else:
			_hide_pause_menu()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("inventory"):
		if inventory_ui and not inventory_ui.visible:
			inventory_ui.open()

	if DEBUG_ENABLED and event is InputEventKey and event.pressed and not event.echo:
		_handle_debug_input(event as InputEventKey)


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
	_apply_theme_tilemap_tint()
	_spawn_room_decorations()


func _create_runtime_tileset(tilemap_layer: TileMapLayer) -> void:
	var ts = TileSet.new()
	ts.tile_size = Vector2i(16, 16)

	var theme: DungeonTheme = _get_current_theme()
	var floor_path: String = "res://assets/sprites/tiles/floor.png"
	var wall_path: String = "res://assets/sprites/tiles/wall.png"
	match theme:
		DungeonTheme.FOREST:
			floor_path = "res://assets/sprites/tiles/floor_forest.png"
			wall_path = "res://assets/sprites/tiles/wall_forest.png"
		DungeonTheme.INFERNO:
			floor_path = "res://assets/sprites/tiles/floor_inferno.png"
			wall_path = "res://assets/sprites/tiles/wall_inferno.png"
		DungeonTheme.NECROPOLIS:
			floor_path = "res://assets/sprites/tiles/floor_necropolis.png"
			wall_path = "res://assets/sprites/tiles/wall_necropolis.png"

	var floor_tex = load(floor_path)
	var wall_tex  = load(wall_path)
	var void_tex  = load("res://assets/sprites/tiles/void.png")

	var floor_variant_count: int = 1
	if floor_tex:
		var floor_src = TileSetAtlasSource.new()
		floor_src.texture = floor_tex
		floor_src.texture_region_size = Vector2i(16, 16)
		floor_variant_count = floor_tex.get_width() / 16
		for i in floor_variant_count:
			floor_src.create_tile(Vector2i(i, 0))
		ts.add_source(floor_src, 0)

	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 6)
	var solid_polygon = PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)
	])

	if wall_tex:
		var wall_src = TileSetAtlasSource.new()
		wall_src.texture = wall_tex
		wall_src.texture_region_size = Vector2i(16, 16)
		wall_src.create_tile(Vector2i(0, 0))
		ts.add_source(wall_src, 1)

		var tile_data = wall_src.get_tile_data(Vector2i(0, 0), 0)
		tile_data.add_collision_polygon(0)
		tile_data.set_collision_polygon_points(0, 0, solid_polygon)

	if void_tex:
		var void_src = TileSetAtlasSource.new()
		void_src.texture = void_tex
		void_src.texture_region_size = Vector2i(16, 16)
		void_src.create_tile(Vector2i(0, 0))
		ts.add_source(void_src, 2)

		var void_tile_data = void_src.get_tile_data(Vector2i(0, 0), 0)
		void_tile_data.add_collision_polygon(0)
		void_tile_data.set_collision_polygon_points(0, 0, solid_polygon)

	tilemap_layer.tile_set = ts
	tilemap_layer.collision_enabled = true
	dungeon.floor_variant_count = floor_variant_count


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
		player.z_index = 1
		return
	player = PlayerScene.instantiate()
	player.position = dungeon.get_spawn_position()
	player.z_index = 1
	entities.add_child(player)
	GameManager.player_node = player
	# 恢复存档中的玩家状态（只在首次加载且有存档时执行）
	if SaveManager.has_active_run() and not _run_restored:
		_run_restored = true
		SaveManager.restore_run_to_player(player)


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
			existing.z_index = 1
			continue

		var p: Player = PlayerScene.instantiate()
		p.name = "Player_%d" % peer_id
		p.position = spos
		p.z_index = 1
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

	var is_big_boss_floor: bool = (GameManager.current_floor % 3 == 0)
	var theme: DungeonTheme = _get_current_theme()
	var config: Dictionary = THEME_CONFIG[theme]
	var enemy_pool: Array = config["enemies"]
	var floor_scale: float = 1.0 + (GameManager.current_floor - 1) * 0.12

	for i in range(1, dungeon.rooms.size()):
		var is_boss_room: bool = (i == dungeon.boss_room_index)
		var base_count: int = randi_range(2 + player_count - 1, 3 + GameManager.current_floor + player_count - 1)
		var enemy_count: int = 1 if is_boss_room else base_count
		dungeon.room_enemy_counts[i] = enemy_count

		if is_boss_room:
			var boss: Node2D = _pick_boss_scene(is_big_boss_floor, config).instantiate()
			boss.name = "Boss_Room_%d" % i
			boss.position = dungeon.get_room_center(i)
			boss.room_index = i
			if hp_mult > 1.0:
				(boss as EnemyBase).max_hp = int((boss as EnemyBase).max_hp * hp_mult)
			(boss as EnemyBase).max_hp = int((boss as EnemyBase).max_hp * floor_scale)
			boss.died_in_room.connect(_on_enemy_died_in_room)
			if is_host:
				boss.set_multiplayer_authority(1)
			entities.add_child(boss)
			enemies_alive += 1
		else:
			for j in enemy_count:
				var scene: PackedScene = enemy_pool[randi() % enemy_pool.size()]
				var enemy: Node2D = scene.instantiate()
				enemy.name = "Enemy_%d_%d" % [i, j]
				var epos: Vector2 = dungeon.get_random_position_in_room(i)
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


func _get_current_theme() -> DungeonTheme:
	var f: int = GameManager.current_floor
	var block: int = ((f - 1) / 3) % 4
	return block as DungeonTheme


func _pick_boss_scene(is_big: bool, config: Dictionary) -> PackedScene:
	if is_big:
		var pool: Array = config["big_bosses"]
		var idx: int = (GameManager.current_floor / 3 - 1) % pool.size()
		return pool[idx]
	else:
		var pool: Array = config["mini_bosses"]
		var idx: int = (GameManager.current_floor - 1) % pool.size()
		return pool[idx]


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
	# 把自身传给 HUD，供桌面暂停按钮回调使用
	if hud.has_method("set_game_world"):
		hud.set_game_world(self)


func _setup_inventory() -> void:
	inventory_ui = InventoryScene.instantiate()
	add_child(inventory_ui)


func _setup_touch_controls() -> void:
	if not (OS.has_feature("android") or OS.has_feature("mobile")):
		return
	var touch_scene = load("res://scenes/ui/touch_controls.tscn")
	if not touch_scene:
		return
	var touch: CanvasLayer = touch_scene.instantiate()
	add_child(touch)
	# 连接背包按钮
	var inv_btn: Button = touch.get_node_or_null("InventoryBtn")
	if inv_btn:
		inv_btn.pressed.connect(func():
			if inventory_ui:
				if inventory_ui.visible:
					inventory_ui._on_close()
				else:
					inventory_ui.open()
		)
	# 连接暂停按钮
	var pause_btn: Button = touch.get_node_or_null("PauseBtn")
	if pause_btn:
		pause_btn.pressed.connect(func():
			if _pause_ui:
				_hide_pause_menu()
			else:
				_show_pause_menu()
		)
	# 移除 attack 动作的鼠标左键绑定，防止触摸模拟点击误触发攻击
	_remove_mouse_from_action("attack")


func _remove_mouse_from_action(action: String) -> void:
	var events := InputMap.action_get_events(action)
	for event in events:
		if event is InputEventMouseButton:
			InputMap.action_erase_event(action, event)


func _setup_ambience() -> void:
	var ambience_script = load("res://scripts/dungeon/dungeon_ambience.gd")
	ambience = CanvasLayer.new()
	ambience.set_script(ambience_script)
	add_child(ambience)
	_apply_theme_ambience()


func _apply_theme_ambience() -> void:
	var theme: DungeonTheme = _get_current_theme()
	var config: Dictionary = THEME_CONFIG[theme]
	if ambience and ambience.has_method("set_theme"):
		ambience.set_theme(config["ambience"], theme as int)


func _on_enemy_died_in_room(room_index: int, enemy_pos: Vector2, is_boss: bool, gold: int, xp: int = 12, killer_peer: int = 0) -> void:
	enemies_alive -= 1
	dungeon.on_enemy_killed_in_room(room_index)
	_try_spawn_loot(enemy_pos, is_boss)
	_spawn_gold_coins(enemy_pos, gold, is_boss)
	_grant_xp(xp, killer_peer)


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


func _grant_xp(amount: int, killer_peer: int = 0) -> void:
	if NetworkManager.is_multiplayer_active():
		if multiplayer.is_server():
			if killer_peer > 0 and GameManager.player_nodes.has(killer_peer):
				var p: Node2D = GameManager.player_nodes[killer_peer]
				if p and is_instance_valid(p) and (p as Player).current_state != Player.State.DEAD:
					_rpc_grant_xp.rpc_id(killer_peer, amount)
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
		player.stats.skill_points += 1
		var hud_nodes = get_tree().get_nodes_in_group("hud")
		if not hud_nodes.is_empty() and hud_nodes[0].has_method("show_pickup_text"):
			hud_nodes[0].show_pickup_text(
				"升级! Lv.%d  获得技能点×1" % player.stats.level,
				UITheme.COLORS["text_gold"]
			)


func _on_skill_selected() -> void:
	if _skill_select_ui:
		_skill_select_ui.queue_free()
		_skill_select_ui = null
	_update_skill_pts_btn()


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
	if NetworkManager.is_multiplayer_active():
		if multiplayer.is_server():
			_rpc_show_floor_clear.rpc()
	else:
		_show_floor_clear_ui()


@rpc("authority", "call_local", "reliable")
func _rpc_show_floor_clear() -> void:
	_show_floor_clear_ui()


const SHOP_POOL = [
	{"name": "生命药水",   "desc": "恢复 60 点生命",       "cost": 35,  "type": "heal",     "value": 60,  "icon": "res://assets/sprites/items/potion_hp.png"},
	{"name": "大生命药水", "desc": "恢复 150 点生命",      "cost": 75,  "type": "heal",     "value": 150, "icon": "res://assets/sprites/items/potion_hp_large.png"},
	{"name": "力量晶石",   "desc": "攻击力 +10（本局）",   "cost": 80,  "type": "atk",      "value": 10,  "icon": "res://assets/sprites/items/item_sword_flame.png"},
	{"name": "防御符文",   "desc": "防御力 +6（本局）",    "cost": 65,  "type": "def",      "value": 6,   "icon": "res://assets/sprites/items/item_shield.png"},
	{"name": "风之羽",     "desc": "移动速度 +15（本局）", "cost": 55,  "type": "spd",      "value": 15,  "icon": "res://assets/sprites/items/item_boots_wind.png"},
	{"name": "神秘宝箱",   "desc": "随机普通或精良装备",   "cost": 90,  "type": "item",     "value": 1,   "icon": "res://assets/sprites/items/item_tome.png"},
	{"name": "稀有宝箱",   "desc": "随机稀有或史诗装备",   "cost": 160, "type": "item",     "value": 2,   "icon": "res://assets/sprites/items/item_tome.png"},
	{"name": "天赋卷轴",   "desc": "随机获得一个被动天赋", "cost": 100, "type": "talent",   "value": 0,   "icon": "res://assets/sprites/items/scroll.png"},
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
	root.offset_top = -155.0
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
	var cur_theme_cfg: Dictionary = THEME_CONFIG[_get_current_theme()]
	var next_floor: int = GameManager.current_floor + 1
	var next_theme_block: int = ((next_floor - 1) / 3) % 4
	var next_theme_cfg: Dictionary = THEME_CONFIG[next_theme_block as DungeonTheme]
	var theme_changed: bool = (next_theme_block != ((GameManager.current_floor - 1) / 3) % 4)
	if theme_changed:
		hint.text = "即将进入「%s」" % next_theme_cfg["name"]
	else:
		hint.text = "「%s」— 捡装备、买东西，准备好再出发" % cur_theme_cfg["name"]
	hint.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_SMALL)
	hint.add_theme_color_override("font_color", UITheme.COLORS["text_dim"])
	hbox.add_child(hint)

	# 技能点升级按钮
	var sp: int = 0
	if player and is_instance_valid(player):
		sp = player.stats.skill_points
	_skill_pts_btn = Button.new()
	_skill_pts_btn.custom_minimum_size = Vector2(110, 32)
	UITheme.style_button(_skill_pts_btn, UITheme.FONT_SIZE_BODY)
	_skill_pts_btn.add_theme_stylebox_override("normal", _make_next_btn_style(false))
	_skill_pts_btn.add_theme_stylebox_override("hover",  _make_next_btn_style(true))
	_skill_pts_btn.add_theme_stylebox_override("disabled", _make_disabled_style())
	_skill_pts_btn.pressed.connect(_on_spend_skill_point)
	hbox.add_child(_skill_pts_btn)
	_update_skill_pts_btn()

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

	var name_row = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 3)
	vbox.add_child(name_row)

	var shop_icon_path: String = item.get("icon", "")
	if shop_icon_path != "":
		var shop_tex = load(shop_icon_path)
		if shop_tex:
			var shop_icon = TextureRect.new()
			shop_icon.texture = shop_tex
			shop_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			shop_icon.custom_minimum_size = Vector2(16, 16)
			shop_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			name_row.add_child(shop_icon)

	var name_lbl = Label.new()
	name_lbl.text = item["name"]
	name_lbl.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_SMALL)
	name_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 1.0))
	name_row.add_child(name_lbl)

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


func _update_skill_pts_btn() -> void:
	if not _skill_pts_btn or not is_instance_valid(_skill_pts_btn):
		return
	var sp: int = 0
	if player and is_instance_valid(player):
		sp = player.stats.skill_points
	if sp > 0:
		_skill_pts_btn.text = "  升级天赋 (%d点)  ✦" % sp
		_skill_pts_btn.disabled = false
		_skill_pts_btn.add_theme_color_override("font_color", Color(0.6, 0.9, 0.4))
	else:
		_skill_pts_btn.text = "  无技能点  "
		_skill_pts_btn.disabled = true
		_skill_pts_btn.add_theme_color_override("font_color", UITheme.COLORS["text_dim"])


func _on_spend_skill_point() -> void:
	if _skill_select_ui or not player or not is_instance_valid(player):
		return
	if player.stats.skill_points <= 0:
		return
	var ui_script = load("res://scripts/ui/skill_select_ui.gd")
	if not ui_script:
		return
	player.stats.skill_points -= 1
	_skill_select_ui = CanvasLayer.new()
	_skill_select_ui.set_script(ui_script)
	_skill_select_ui.layer = 18
	add_child(_skill_select_ui)
	_skill_select_ui.setup_passive_select(player)
	_skill_select_ui.selection_made.connect(_on_skill_selected)


func _on_confirm_next_floor() -> void:
	if _floor_clear_ui:
		_floor_clear_ui.queue_free()
		_floor_clear_ui = null

	# 进入下一层前先存档
	if not NetworkManager.is_multiplayer_active():
		SaveManager.save_run()

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
	_skill_pts_btn = null
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

	# 重新生成地图（主题变化时需要重建瓦片集）
	_create_runtime_tileset(dungeon.tilemap)
	var player_count: int = NetworkManager.get_player_count()
	var seed_val: int = NetworkManager.current_dungeon_seed
	dungeon.generate(GameManager.current_floor, player_count, seed_val)
	_apply_theme_tilemap_tint()
	_spawn_room_decorations()

	# 单人直接恢复，多人在 _spawn_player 里统一复活
	if not NetworkManager.is_multiplayer_active():
		if player and is_instance_valid(player):
			player.stats.heal(100)

	_spawn_player()
	_spawn_enemies()
	_spawn_torch_lights()
	_show_theme_banner()

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

	_apply_theme_ambience()


# ═══════════════════════════════════════════════════════════════
# Game Over UI
# ═══════════════════════════════════════════════════════════════

func _on_game_over() -> void:
	if _skill_select_ui and is_instance_valid(_skill_select_ui):
		_skill_select_ui.queue_free()
		_skill_select_ui = null
	get_tree().paused = false
	# 死亡时清除当局存档（防止主菜单显示"继续"）
	if not NetworkManager.is_multiplayer_active():
		SaveManager.clear_run()
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
	if _skill_select_ui and is_instance_valid(_skill_select_ui):
		_skill_select_ui.queue_free()
		_skill_select_ui = null
	get_tree().paused = false
	NetworkManager.disconnect_all()
	_show_disconnect_notice("房主已离开游戏", "连接已断开，即将返回主菜单…")


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
		main_node.return_to_title()# ═══════════════════════════════════════════════════════════════
# 暂停菜单
# ═══════════════════════════════════════════════════════════════

func _show_pause_menu() -> void:
	if _pause_ui or get_tree().paused:
		return
	# 先自动保存
	SaveManager.save_run()

	_pause_ui = CanvasLayer.new()
	_pause_ui.layer = 22
	_pause_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_ui)  # 必须先加入场景树，再暂停，否则节点也被暂停

	get_tree().paused = true

	# 半透明背景
	var overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.65)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_ui.add_child(overlay)

	# 中心面板
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left  = -130
	panel.offset_right = 130
	panel.offset_top   = -110
	panel.offset_bottom = 110
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.04, 0.12, 0.97)
	sb.border_color = Color(0.5, 0.4, 0.7, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(5)
	sb.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", sb)
	_pause_ui.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# 标题
	var title_lbl = Label.new()
	title_lbl.text = "游戏暂停"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(title_lbl, UITheme.FONT_SIZE_TITLE, Color(0.8, 0.7, 1.0))
	vbox.add_child(title_lbl)

	# 层数/存档提示
	var hint_lbl = Label.new()
	hint_lbl.text = "第 %d 层  —  进度已自动保存" % GameManager.current_floor
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(hint_lbl, UITheme.FONT_SIZE_SMALL, UITheme.COLORS["text_dim"])
	vbox.add_child(hint_lbl)

	var sep1 = HSeparator.new()
	sep1.add_theme_stylebox_override("separator", _make_separator_style())
	vbox.add_child(sep1)

	# 继续按钮
	var resume_btn = Button.new()
	resume_btn.text = "  继续游戏  "
	resume_btn.custom_minimum_size = Vector2(200, 34)
	UITheme.style_button(resume_btn, UITheme.FONT_SIZE_BODY)
	resume_btn.add_theme_color_override("font_color", UITheme.COLORS["text_gold"])
	resume_btn.add_theme_stylebox_override("normal",
		_make_gameover_btn_style(Color(0.18, 0.14, 0.04), Color(0.8, 0.65, 0.2)))
	resume_btn.add_theme_stylebox_override("hover",
		_make_gameover_btn_style(Color(0.28, 0.22, 0.06), Color(1.0, 0.85, 0.3)))
	resume_btn.pressed.connect(_hide_pause_menu)
	vbox.add_child(resume_btn)

	# 返回主菜单按钮
	var menu_btn = Button.new()
	menu_btn.text = "  返回主菜单  "
	menu_btn.custom_minimum_size = Vector2(200, 34)
	UITheme.style_button(menu_btn, UITheme.FONT_SIZE_BODY)
	menu_btn.add_theme_stylebox_override("normal",
		_make_gameover_btn_style(Color(0.12, 0.10, 0.20), Color(0.4, 0.3, 0.6)))
	menu_btn.add_theme_stylebox_override("hover",
		_make_gameover_btn_style(Color(0.18, 0.16, 0.28), Color(0.5, 0.4, 0.7)))
	menu_btn.pressed.connect(func():
		_hide_pause_menu()
		var main_node = get_tree().current_scene
		if main_node and main_node.has_method("return_to_title"):
			main_node.return_to_title()
	)
	vbox.add_child(menu_btn)

	# 退出游戏按钮（手机端隐藏）
	if not OS.has_feature("android"):
		var quit_btn = Button.new()
		quit_btn.text = "  退出游戏  "
		quit_btn.custom_minimum_size = Vector2(200, 34)
		UITheme.style_button(quit_btn, UITheme.FONT_SIZE_BODY)
		quit_btn.add_theme_stylebox_override("normal",
			_make_gameover_btn_style(Color(0.20, 0.08, 0.08), Color(0.7, 0.25, 0.25)))
		quit_btn.add_theme_stylebox_override("hover",
			_make_gameover_btn_style(Color(0.28, 0.12, 0.12), Color(0.9, 0.3, 0.3)))
		quit_btn.pressed.connect(func(): get_tree().quit())
		vbox.add_child(quit_btn)

	# 隐藏按钮：捕获 Escape 键关闭暂停菜单（game_world._input 在暂停时不执行）
	var esc_btn = Button.new()
	esc_btn.flat = true
	esc_btn.modulate.a = 0.0
	esc_btn.focus_mode = Control.FOCUS_NONE
	esc_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var esc_shortcut = Shortcut.new()
	var esc_event = InputEventKey.new()
	esc_event.keycode = KEY_ESCAPE
	esc_shortcut.events = [esc_event]
	esc_btn.shortcut = esc_shortcut
	esc_btn.pressed.connect(_hide_pause_menu)
	_pause_ui.add_child(esc_btn)


func _hide_pause_menu() -> void:
	if not _pause_ui:
		return
	get_tree().paused = false
	_pause_ui.queue_free()
	_pause_ui = null


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


# ═══════════════════════════════════════════════════════════════
# Disconnect Notice
# ═══════════════════════════════════════════════════════════════

func _on_peer_disconnected(peer_id: int) -> void:
	var peer_player: Node2D = GameManager.player_nodes.get(peer_id)
	if peer_player and is_instance_valid(peer_player):
		peer_player.queue_free()
	GameManager.player_nodes.erase(peer_id)
	_show_toast("一位玩家离开了游戏")


func _show_disconnect_notice(title_text: String, body_text: String) -> void:
	if _disconnect_ui:
		return

	_disconnect_ui = CanvasLayer.new()
	_disconnect_ui.layer = 25
	_disconnect_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_disconnect_ui)

	var overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_disconnect_ui.add_child(overlay)
	var fade_tw = create_tween()
	fade_tw.tween_property(overlay, "color:a", 0.6, 0.5)

	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -150
	panel.offset_right = 150
	panel.offset_top = -70
	panel.offset_bottom = 70
	var panel_sb = StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.08, 0.05, 0.14, 0.95)
	panel_sb.border_color = Color(1.0, 0.5, 0.2, 0.8)
	panel_sb.set_border_width_all(2)
	panel_sb.set_corner_radius_all(4)
	panel_sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", panel_sb)
	_disconnect_ui.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var icon_lbl = Label.new()
	icon_lbl.text = "⚠"
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 24)
	icon_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	vbox.add_child(icon_lbl)

	var title_lbl = Label.new()
	title_lbl.text = title_text
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(title_lbl, UITheme.FONT_SIZE_HEADER, Color(1.0, 0.7, 0.3))
	vbox.add_child(title_lbl)

	var body_lbl = Label.new()
	body_lbl.text = body_text
	body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_label(body_lbl, UITheme.FONT_SIZE_SMALL, UITheme.COLORS["text_dim"])
	vbox.add_child(body_lbl)

	var countdown_lbl = Label.new()
	countdown_lbl.name = "Countdown"
	countdown_lbl.text = "3 秒后自动返回…"
	countdown_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(countdown_lbl, UITheme.FONT_SIZE_TINY, UITheme.COLORS["text_dim"])
	vbox.add_child(countdown_lbl)

	var btn = Button.new()
	btn.text = "  立即返回  "
	btn.custom_minimum_size = Vector2(120, 28)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UITheme.style_button(btn, UITheme.FONT_SIZE_BODY)
	btn.add_theme_color_override("font_color", UITheme.COLORS["text_gold"])
	btn.pressed.connect(_on_disconnect_return)
	vbox.add_child(btn)

	panel.modulate.a = 0.0
	panel.scale = Vector2(0.85, 0.85)
	panel.pivot_offset = panel.size / 2
	var tw = create_tween().set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.4)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)

	_run_disconnect_countdown(countdown_lbl, 3)


func _run_disconnect_countdown(lbl: Label, seconds: int) -> void:
	for i in range(seconds, 0, -1):
		if not is_instance_valid(lbl):
			return
		lbl.text = "%d 秒后自动返回…" % i
		await get_tree().create_timer(1.0).timeout
	_on_disconnect_return()


func _on_disconnect_return() -> void:
	if _disconnect_ui:
		_disconnect_ui.queue_free()
		_disconnect_ui = null
	var main_node = get_tree().current_scene
	if main_node and main_node.has_method("return_to_title"):
		main_node.return_to_title()


func _show_toast(msg: String) -> void:
	var toast_layer = CanvasLayer.new()
	toast_layer.layer = 22
	add_child(toast_layer)

	var lbl = Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	lbl.offset_top = 30
	lbl.offset_bottom = 54
	lbl.offset_left = -120
	lbl.offset_right = 120
	UITheme.style_label(lbl, UITheme.FONT_SIZE_SMALL, Color(1.0, 0.75, 0.3))

	var bg = PanelContainer.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	bg.offset_top = 26
	bg.offset_bottom = 56
	bg.offset_left = -130
	bg.offset_right = 130
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.06, 0.16, 0.9)
	sb.border_color = Color(1.0, 0.6, 0.2, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(6)
	bg.add_theme_stylebox_override("panel", sb)
	toast_layer.add_child(bg)
	toast_layer.add_child(lbl)

	lbl.modulate.a = 0.0
	bg.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(lbl, "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(bg, "modulate:a", 1.0, 0.3)
	tw.tween_interval(2.5)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw.parallel().tween_property(bg, "modulate:a", 0.0, 0.5)
	tw.tween_callback(toast_layer.queue_free)


var _last_theme_block: int = -1

func _show_theme_banner() -> void:
	var block: int = ((GameManager.current_floor - 1) / 3) % 4
	if block == _last_theme_block and GameManager.current_floor > 1:
		return
	_last_theme_block = block

	var config: Dictionary = THEME_CONFIG[_get_current_theme()]
	var theme_name: String = config["name"]
	var floor_from: int = GameManager.current_floor
	var floor_to: int = floor_from + (3 - ((floor_from - 1) % 3)) - 1

	var layer = CanvasLayer.new()
	layer.layer = 20
	add_child(layer)

	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_top = 30
	var sb = StyleBoxFlat.new()
	var bc: Color = config.get("banner_color", config["ambience"])
	sb.bg_color = Color(bc.r, bc.g, bc.b, 0.92)
	sb.border_color = Color(bc.r * 1.5 + 0.3, bc.g * 1.5 + 0.3, bc.b * 1.5 + 0.3, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	layer.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var title_lbl = Label.new()
	title_lbl.text = "— %s —" % theme_name
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	vbox.add_child(title_lbl)

	var range_lbl = Label.new()
	range_lbl.text = "第 %d ~ %d 层" % [floor_from, floor_to]
	range_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	range_lbl.add_theme_font_size_override("font_size", 10)
	range_lbl.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	vbox.add_child(range_lbl)

	panel.modulate.a = 0.0
	panel.scale = Vector2(0.8, 0.8)
	var tw = create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.4)
	tw.parallel().tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(2.5)
	tw.tween_property(panel, "modulate:a", 0.0, 0.6)
	tw.tween_callback(layer.queue_free)


# ═══════════════════════════════════════════════════════════════
# Theme Visual System
# ═══════════════════════════════════════════════════════════════

func _apply_theme_tilemap_tint() -> void:
	if dungeon and dungeon.tilemap:
		dungeon.tilemap.modulate = Color.WHITE


const DECO_PER_ROOM_MIN: int = 2
const DECO_PER_ROOM_MAX: int = 7

func _spawn_room_decorations() -> void:
	var theme: DungeonTheme = _get_current_theme()
	var tex_pool: Array = DECO_TEXTURES.get(theme, [])
	if tex_pool.is_empty():
		return

	for i in dungeon.rooms.size():
		var room: Rect2i = dungeon.rooms[i]
		var area: int = room.size.x * room.size.y
		var count: int = clampi(int(area / 12), DECO_PER_ROOM_MIN, DECO_PER_ROOM_MAX)
		for j in count:
			var margin: int = 1
			var tx: int = randi_range(room.position.x + margin, room.end.x - 1 - margin)
			var ty: int = randi_range(room.position.y + margin, room.end.y - 1 - margin)
			if not dungeon.is_floor_at(Vector2(tx * 16 + 8, ty * 16 + 8)):
				continue
			var world_pos = Vector2(tx * 16 + 8, ty * 16 + 8)
			_place_deco_sprite(world_pos, tex_pool, theme)


func _place_deco_sprite(pos: Vector2, tex_pool: Array, theme: DungeonTheme) -> void:
	var tex: Texture2D = tex_pool[randi() % tex_pool.size()]
	var spr = Sprite2D.new()
	spr.texture = tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.position = pos
	spr.z_index = 0

	spr.modulate.a = randf_range(0.88, 1.0)
	if randi() % 3 == 0:
		spr.flip_h = true

	entities.add_child(spr)


# ═══════════════════════════════════════════════════════════════
# Debug System (F5 面板, F1-F4 跳主题, PageUp/Down 跳层)
# ═══════════════════════════════════════════════════════════════

func _handle_debug_input(event: InputEventKey) -> void:
	match event.keycode:
		KEY_F5:
			_toggle_debug_panel()
		KEY_F1:
			_debug_jump_to_floor(1)
		KEY_F2:
			_debug_jump_to_floor(4)
		KEY_F3:
			_debug_jump_to_floor(7)
		KEY_F4:
			_debug_jump_to_floor(10)
		KEY_F6:
			_debug_jump_to_floor(GameManager.current_floor + 1)
		KEY_F7:
			_debug_jump_to_floor(maxi(GameManager.current_floor - 1, 1))
		KEY_F9:
			# 满血 + 加金币
			if player and is_instance_valid(player):
				player.stats.heal(player.stats.max_hp)
				GameManager.gold += 200
				_debug_toast("回满血 & +200金币")
		KEY_F10:
			# 获得 3 点技能点
			if player and is_instance_valid(player):
				player.stats.skill_points += 3
				_debug_toast("+3 技能点")
		KEY_F11:
			# 直接清除当前层所有敌人
			_debug_kill_all_enemies()


func _debug_jump_to_floor(target_floor: int) -> void:
	if _floor_clear_ui and is_instance_valid(_floor_clear_ui):
		_floor_clear_ui.queue_free()
		_floor_clear_ui = null

	GameManager.current_floor = target_floor
	_last_theme_block = -1

	if ambience and ambience.has_method("clear_torches"):
		ambience.clear_torches()

	for child in entities.get_children():
		var keep: bool = false
		if NetworkManager.is_multiplayer_active():
			keep = GameManager.player_nodes.values().has(child)
		else:
			keep = (child == player)
		if not keep:
			child.queue_free()

	_create_runtime_tileset(dungeon.tilemap)
	var player_count: int = NetworkManager.get_player_count()
	var seed_val: int = randi()
	dungeon.generate(GameManager.current_floor, player_count, seed_val)
	_apply_theme_tilemap_tint()
	_spawn_room_decorations()

	_spawn_player()
	_spawn_enemies()
	_spawn_torch_lights()
	_apply_theme_ambience()
	_show_theme_banner()

	if player and is_instance_valid(player):
		player.stats.heal(player.stats.max_hp)

	_update_debug_info()
	var config: Dictionary = THEME_CONFIG[_get_current_theme()]
	_debug_toast("跳转到第 %d 层 —「%s」" % [target_floor, config["name"]])


func _debug_kill_all_enemies() -> void:
	var killed: int = 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy is EnemyBase:
			if (enemy as EnemyBase).ai_state != EnemyBase.AIState.DEAD:
				(enemy as EnemyBase).take_damage(99999, Vector2.ZERO)
				killed += 1
	_debug_toast("击杀 %d 只敌人" % killed)


func _toggle_debug_panel() -> void:
	if _debug_panel and is_instance_valid(_debug_panel):
		_debug_panel.queue_free()
		_debug_panel = null
		return

	_debug_panel = CanvasLayer.new()
	_debug_panel.layer = 50
	add_child(_debug_panel)

	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 8
	panel.offset_top = 8
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.75)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	_debug_panel.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "[ DEBUG 调试面板 ]"
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	vbox.add_child(title)

	_debug_info_label = Label.new()
	_debug_info_label.add_theme_font_size_override("font_size", 9)
	_debug_info_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vbox.add_child(_debug_info_label)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var hotkey_label = Label.new()
	hotkey_label.text = (
		"F1  石窟(1层)  F2  森林(4层)\n"
		+ "F3  炼狱(7层)  F4  亡灵(10层)\n"
		+ "F6  下一层  F7  上一层\n"
		+ "F9  满血+200金  F10  +3技能点\n"
		+ "F11  击杀全部敌人  F5  关闭面板"
	)
	hotkey_label.add_theme_font_size_override("font_size", 8)
	hotkey_label.add_theme_color_override("font_color", Color(0.65, 0.75, 0.65))
	vbox.add_child(hotkey_label)

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 4)
	vbox.add_child(btn_row)
	for data in [["石窟", 1], ["森林", 4], ["炼狱", 7], ["亡灵", 10]]:
		var btn = Button.new()
		btn.text = data[0]
		btn.add_theme_font_size_override("font_size", 9)
		var floor_num: int = data[1]
		btn.pressed.connect(func(): _debug_jump_to_floor(floor_num))
		btn_row.add_child(btn)

	_update_debug_info()


func _update_debug_info() -> void:
	if not _debug_info_label or not is_instance_valid(_debug_info_label):
		return
	var config: Dictionary = THEME_CONFIG[_get_current_theme()]
	var theme_names = ["CRYPT", "FOREST", "INFERNO", "NECROPOLIS"]
	var theme_idx: int = _get_current_theme() as int
	_debug_info_label.text = (
		"当前层: %d  主题: %s「%s」\n" % [GameManager.current_floor, theme_names[theme_idx], config["name"]]
		+ "敌人存活: %d  金币: %d\n" % [enemies_alive, GameManager.gold]
		+ "玩家等级: %d  技能点: %d" % [
			player.stats.level if player and is_instance_valid(player) else 0,
			player.stats.skill_points if player and is_instance_valid(player) else 0,
		]
	)


func _debug_toast(msg: String) -> void:
	var layer = CanvasLayer.new()
	layer.layer = 51
	add_child(layer)

	var lbl = Label.new()
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	lbl.offset_top = 50
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(lbl)

	var tw = create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(layer.queue_free)

	_update_debug_info()
