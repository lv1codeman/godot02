extends HBoxContainer

@export var stats: Stats

@onready var health_bar: TextureProgressBar = $HealthBar
@onready var eased_healthe_bar: TextureProgressBar = $HealthBar/EasedHealtheBar

func _ready() -> void:
	if not stats:
		stats = Game.player_stats
	
	stats.health_changed.connect(update_health)
	update_health(true)

func update_health(skip_anim := false) -> void:
	var percentage := stats.health / float(stats.max_health)
	health_bar.value = percentage
	
	if skip_anim:
		eased_healthe_bar.value = percentage
	else:
		create_tween().tween_property(eased_healthe_bar, "value", percentage, 0.3)
