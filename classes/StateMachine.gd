class_name StateMachine
extends Node

var current_state: int = -1:
	set(v):
		owner.transition_state(current_state, v)
		current_state = v


func _ready() -> void:
	# 這邊會調用到player節點的ready，所以要先確保player節點ready後才調用
	await owner.ready
	current_state = 0

func _physics_process(delta: float) -> void:
	while true:
		var next := owner.get_next_state(current_state) as int
		if current_state == next:
			break
		current_state = next
		
	owner.tick_physics(current_state, delta)
