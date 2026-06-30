extends Node2D

@onready var tile_map: TileMap = $TileMap
@onready var camera_2d: Camera2D = $Player/Camera2D
@onready var player: Player = $Player


func _ready() -> void:
	# 設定camera的limit，確保玩家不會看到地圖外的東西
	# 先得到我們在tile_map上使用到的範圍
	var used := tile_map.get_used_rect().grow(-1)
	# 再取得每個方塊的size
	var tile_size := tile_map.tile_set.tile_size
	#print($"used: ", used)
	#print($"tile_size: ", tile_size)
	# used.position.y * tile_size.y 代表y軸向上我們用了幾個方塊乘上每個方塊的高度
	camera_2d.limit_top = used.position.y * tile_size.y
	camera_2d.limit_right = used.end.x * tile_size.x
	camera_2d.limit_bottom = used.end.y * tile_size.y
	camera_2d.limit_left = used.position.x * tile_size.x
	camera_2d.reset_smoothing()

func update_player(pos: Vector2, direction: Player.Direction) -> void:
	player.global_position = pos
	player.direction = direction
	camera_2d.reset_smoothing()
