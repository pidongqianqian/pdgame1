extends Node

var bgm_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
const MAX_SFX_PLAYERS = 8

var bgm_volume: float = 0.8
var sfx_volume: float = 1.0


func _ready() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Master"
	add_child(bgm_player)
	for i in MAX_SFX_PLAYERS:
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		sfx_players.append(p)


func play_bgm(stream: AudioStream, volume_db: float = 0.0) -> void:
	if bgm_player.stream == stream and bgm_player.playing:
		return
	bgm_player.stream = stream
	bgm_player.volume_db = volume_db + linear_to_db(bgm_volume)
	bgm_player.play()


func stop_bgm() -> void:
	bgm_player.stop()


func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	for p in sfx_players:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db + linear_to_db(sfx_volume)
			p.play()
			return
