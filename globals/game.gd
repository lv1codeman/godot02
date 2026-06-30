extends Node

@onready var player_stats: Stats = $PlayerStats
@onready var color_rect: ColorRect = $ColorRect


func _ready() -> void:
	color_rect.color.a = 0

func change_scene(path: String, entry_point: String) -> void:
	var tree := get_tree()
	tree.paused = true
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(color_rect, "color:a", 1, 0.2)
	await tween.finished
	
	tree.change_scene_to_file(path)
	#await tree.process_frame
	await tree.tree_changed
	
	for node in tree.get_nodes_in_group("entry_points"):
		if node.name == entry_point:
			tree.current_scene.update_player(node.global_position, node.direction)
			break
			
	tree.paused = false
	tween = create_tween()
	tween.tween_property(color_rect, "color:a", 0, 0.2)
	
func reload_scene() -> void:
	var tree := get_tree()
	# 1. 暫停遊戲，防止在轉場時玩家或怪物還在移動
	tree.paused = true
	
	# 2. 建立 Tween 讓黑幕淡入 (0.2 秒變黑)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) # 確保暫停時 Tween 也能跑
	tween.tween_property(color_rect, "color:a", 1, 0.2)
	await tween.finished
	
	# 3. 執行重載當前場景
	tree.reload_current_scene()
	
	# 4. 等待新場景完全載入並初始化完畢
	await tree.tree_changed
	
	# 5. 解除暫停
	tree.paused = false
	
	# 6. 建立 Tween 讓黑幕淡出 (0.2 秒變回透明)
	tween = create_tween()
	tween.tween_property(color_rect, "color:a", 0, 1.5)
