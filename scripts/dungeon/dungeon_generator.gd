extends Node2D
class_name DungeonGenerator

signal dungeon_ready
signal room_cleared(room_index: int)
signal all_rooms_cleared

const TILE_SIZE = 16
const MIN_ROOM_SIZE = 5
const MAX_ROOM_SIZE = 12
const MIN_SPLIT_SIZE = 12

# Dynamic map size - scaled by player count
var MAP_WIDTH: int = 60
var MAP_HEIGHT: int = 40

enum TileType { EMPTY = -1, FLOOR = 0, WALL = 1, DOOR = 2 }

var rooms: Array[Rect2i] = []
var corridors: Array[Array] = []
var grid: Array = []
var room_enemy_counts: Array[int] = []
var room_doors: Dictionary = {}
var boss_room_index: int = -1
var current_room_index: int = -1
var floor_variant_count: int = 1

@onready var tilemap: TileMapLayer = $TileMapLayer


func generate(floor_level: int = 1, player_count: int = 1, seed_val: int = 0) -> void:
	# Scale map size by player count: 1p=60x40, 2p=68x46, 3p=76x52, 4p=84x58
	MAP_WIDTH  = 60 + (player_count - 1) * 8
	MAP_HEIGHT = 40 + (player_count - 1) * 6

	# Use seed for deterministic generation across all clients
	# 混入 floor_level 保证每层地牢不同
	if seed_val != 0:
		seed(seed_val + floor_level * 7919)

	rooms.clear()
	corridors.clear()
	room_enemy_counts.clear()
	room_doors.clear()
	_init_grid()

	var num_rooms = clampi(5 + floor_level + player_count - 1, 5, 12)
	_bsp_split(Rect2i(1, 1, MAP_WIDTH - 2, MAP_HEIGHT - 2), num_rooms)

	for i in rooms.size():
		_carve_room(rooms[i])

	for i in rooms.size() - 1:
		var corridor = _create_corridor(rooms[i], rooms[i + 1])
		corridors.append(corridor)

	boss_room_index = rooms.size() - 1
	_place_doors()
	_apply_to_tilemap()
	dungeon_ready.emit()


func _init_grid() -> void:
	grid = []
	for y in MAP_HEIGHT:
		var row = []
		for x in MAP_WIDTH:
			row.append(TileType.WALL)
		grid.append(row)


func _bsp_split(area: Rect2i, target_count: int) -> void:
	if rooms.size() >= target_count:
		return

	if area.size.x < MIN_SPLIT_SIZE * 2 and area.size.y < MIN_SPLIT_SIZE * 2:
		_create_room_in_area(area)
		return

	var split_h = randf() > 0.5
	if area.size.x > area.size.y * 1.5:
		split_h = false
	elif area.size.y > area.size.x * 1.5:
		split_h = true

	if split_h and area.size.y >= MIN_SPLIT_SIZE * 2:
		var split_y = area.position.y + randi_range(MIN_SPLIT_SIZE, area.size.y - MIN_SPLIT_SIZE)
		var top = Rect2i(area.position.x, area.position.y, area.size.x, split_y - area.position.y)
		var bottom = Rect2i(area.position.x, split_y, area.size.x, area.end.y - split_y)
		_bsp_split(top, target_count)
		_bsp_split(bottom, target_count)
	elif area.size.x >= MIN_SPLIT_SIZE * 2:
		var split_x = area.position.x + randi_range(MIN_SPLIT_SIZE, area.size.x - MIN_SPLIT_SIZE)
		var left = Rect2i(area.position.x, area.position.y, split_x - area.position.x, area.size.y)
		var right = Rect2i(split_x, area.position.y, area.end.x - split_x, area.size.y)
		_bsp_split(left, target_count)
		_bsp_split(right, target_count)
	else:
		_create_room_in_area(area)


func _create_room_in_area(area: Rect2i) -> void:
	var w = randi_range(MIN_ROOM_SIZE, mini(MAX_ROOM_SIZE, area.size.x - 2))
	var h = randi_range(MIN_ROOM_SIZE, mini(MAX_ROOM_SIZE, area.size.y - 2))
	var x = area.position.x + randi_range(1, maxi(1, area.size.x - w - 1))
	var y = area.position.y + randi_range(1, maxi(1, area.size.y - h - 1))
	rooms.append(Rect2i(x, y, w, h))


func _carve_room(room: Rect2i) -> void:
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			if _in_bounds(x, y):
				grid[y][x] = TileType.FLOOR


func _create_corridor(room_a: Rect2i, room_b: Rect2i) -> Array:
	var points: Array = []
	var start = room_a.get_center()
	var finish = room_b.get_center()

	var cx = start.x
	var cy = start.y
	var step_x = 1 if finish.x > cx else -1
	while cx != finish.x:
		if _in_bounds(cx, cy):
			grid[cy][cx] = TileType.FLOOR
			if _in_bounds(cx, cy - 1):
				grid[cy - 1][cx] = TileType.FLOOR
		points.append(Vector2i(cx, cy))
		cx += step_x

	var step_y = 1 if finish.y > cy else -1
	while cy != finish.y:
		if _in_bounds(cx, cy):
			grid[cy][cx] = TileType.FLOOR
			if _in_bounds(cx + 1, cy):
				grid[cy][cx + 1] = TileType.FLOOR
		points.append(Vector2i(cx, cy))
		cy += step_y

	return points


func _place_doors() -> void:
	for i in rooms.size():
		room_enemy_counts.append(0)


func _apply_to_tilemap() -> void:
	if not tilemap:
		return
	tilemap.clear()

	var pad: int = 6
	for y in range(-pad, MAP_HEIGHT + pad):
		for x in range(-pad, MAP_WIDTH + pad):
			if _in_bounds(x, y):
				var tile_type = grid[y][x]
				if tile_type == TileType.FLOOR:
					var variant: int = randi() % floor_variant_count
					tilemap.set_cell(Vector2i(x, y), 0, Vector2i(variant, 0))
				elif tile_type == TileType.WALL:
					if _is_visible_wall(x, y):
						tilemap.set_cell(Vector2i(x, y), 1, Vector2i(0, 0))
					else:
						tilemap.set_cell(Vector2i(x, y), 2, Vector2i(0, 0))
			else:
				tilemap.set_cell(Vector2i(x, y), 2, Vector2i(0, 0))


func _is_visible_wall(x: int, y: int) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var nx = x + dx
			var ny = y + dy
			if _in_bounds(nx, ny) and grid[ny][nx] == TileType.FLOOR:
				return true
	return false


func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < MAP_WIDTH and y >= 0 and y < MAP_HEIGHT


func get_room_center(room_index: int) -> Vector2:
	if room_index < 0 or room_index >= rooms.size():
		return Vector2.ZERO
	var center = rooms[room_index].get_center()
	# 加半格偏移，让中心点落在格子中央而不是格子边缘
	return Vector2(center.x * TILE_SIZE + TILE_SIZE / 2,
				   center.y * TILE_SIZE + TILE_SIZE / 2)


func get_spawn_position() -> Vector2:
	if rooms.is_empty():
		return Vector2.ZERO
	return get_room_center(0)


func get_random_position_in_room(room_index: int) -> Vector2:
	if room_index < 0 or room_index >= rooms.size():
		return Vector2.ZERO
	var room = rooms[room_index]

	# 内缩 2 格，远离墙壁边缘，避免碰撞形状初始化时推出地图
	var margin: int = 2
	var x_min: int = room.position.x + margin
	var x_max: int = room.end.x - 1 - margin
	var y_min: int = room.position.y + margin
	var y_max: int = room.end.y - 1 - margin

	# 若房间太小，直接返回中心
	if x_min > x_max or y_min > y_max:
		return get_room_center(room_index)

	# 最多尝试 12 次，确保落点是真实地板格
	for _attempt in 12:
		var x: int = randi_range(x_min, x_max)
		var y: int = randi_range(y_min, y_max)
		if _in_bounds(x, y) and grid[y][x] == TileType.FLOOR:
			return Vector2(x * TILE_SIZE + TILE_SIZE / 2, y * TILE_SIZE + TILE_SIZE / 2)

	# 12 次都不中则回退到房间中心
	return get_room_center(room_index)


func get_room_at_position(pos: Vector2) -> int:
	var tile_pos = Vector2i(int(pos.x / TILE_SIZE), int(pos.y / TILE_SIZE))
	for i in rooms.size():
		if rooms[i].has_point(tile_pos):
			return i
	return -1


func is_floor_at(pos: Vector2) -> bool:
	var tx: int = int(pos.x) / TILE_SIZE
	var ty: int = int(pos.y) / TILE_SIZE
	return _in_bounds(tx, ty) and grid[ty][tx] == TileType.FLOOR


func clamp_to_floor(pos: Vector2, origin: Vector2) -> Vector2:
	if is_floor_at(pos):
		return pos
	# 搜索 origin 附近 5x5 格子范围，找到离 pos 最近的地板格
	var ox: int = int(origin.x) / TILE_SIZE
	var oy: int = int(origin.y) / TILE_SIZE
	var best_pos: Vector2 = origin
	var best_dist: float = INF
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var tx: int = ox + dx
			var ty: int = oy + dy
			if _in_bounds(tx, ty) and grid[ty][tx] == TileType.FLOOR:
				var candidate = Vector2(tx * TILE_SIZE + TILE_SIZE / 2, ty * TILE_SIZE + TILE_SIZE / 2)
				var d: float = candidate.distance_to(pos)
				if d < best_dist:
					best_dist = d
					best_pos = candidate
	return best_pos


func on_enemy_killed_in_room(room_index: int) -> void:
	if room_index < 0 or room_index >= room_enemy_counts.size():
		return
	room_enemy_counts[room_index] -= 1
	if room_enemy_counts[room_index] <= 0:
		room_cleared.emit(room_index)
		var all_done = true
		for c in room_enemy_counts:
			if c > 0:
				all_done = false
				break
		if all_done:
			all_rooms_cleared.emit()
