extends Node

const FRAME_SIZE: int = 64

var _cache: Dictionary = {}


func play(effect_path: String, pos: Vector2, effect_scale: float = 0.5,
		speed: float = 30.0, z: int = 10) -> void:
	var tex: Texture2D = _get_texture(effect_path)
	if not tex:
		return

	var spr := Sprite2D.new()
	spr.texture = tex
	spr.hframes = tex.get_width() / FRAME_SIZE
	spr.vframes = 1
	spr.frame = 0
	spr.position = pos
	spr.scale = Vector2(effect_scale, effect_scale)
	spr.z_index = z
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	var scene_root: Node = get_tree().current_scene
	if not scene_root:
		return
	scene_root.add_child(spr)

	var frame_count: int = spr.hframes
	var duration: float = frame_count / speed
	var tween: Tween = spr.create_tween()
	tween.tween_property(spr, "frame", frame_count - 1, duration)
	tween.tween_callback(spr.queue_free)


func play_at(effect_name: String, pos: Vector2, color: String = "orange",
		effect_scale: float = 0.5, speed: float = 30.0) -> void:
	var path: String = "res://assets/sprites/effects/%s_%s.png" % [effect_name, color]
	play(path, pos, effect_scale, speed)


func _get_texture(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = load(path)
	if tex:
		_cache[path] = tex
	return tex
