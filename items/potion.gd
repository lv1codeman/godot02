extends Area2D

# 設定補血量
@export var heal_amount: int = 3
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	animation_player.play("exist")

func _on_body_entered(body: Node2D) -> void:
	print("藥水碰撞成功!")
	# 檢查進來的物體（body）是不是 Player，且身上有沒有 Stats 節點
	if body is Player and body.has_node("Stats"):
		var player_stats = body.get_node("Stats")
		
		# 執行補血
		player_stats.health += heal_amount
		print("補血成功！目前血量：", player_stats.health)
		
		if body.has_method("play_heal_effect"):
			body.play_heal_effect(heal_amount)
			
		# 可以播放一個撿取音效或消失動畫，這裡先直接讓藥水消失
		queue_free()
