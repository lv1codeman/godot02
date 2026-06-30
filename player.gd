class_name Player
extends CharacterBody2D

enum State{
	IDLE,
	RUNNING,
	JUMP,
	FALL,
	LANDING,
	WALL_SLIDING,
	WALL_JUMP,
	ATTACK_1,
	ATTACK_2,
	HURT,
	DYING,
}

const GROUND_STATES := [
	State.IDLE, State.RUNNING, State.LANDING, 
	State.ATTACK_1, State.ATTACK_2
]
const RUN_SPEED := 160.0
const FLOOR_ACCELERATION := RUN_SPEED / 0.2
const AIR_ACCELERATION := RUN_SPEED / 0.1
const JUMP_VELOCITY := -300.0
const WALL_JUMP_VELOCITY := Vector2(300, -320)
const KNOCKBACK_AMOUNT := 512.0

@export var can_combo := false
@export var max_jumps := 2  # 最大跳躍次數（2 代表可以二段跳）

var default_gravity := ProjectSettings.get("physics/2d/default_gravity") as float
var is_first_tick := false
var is_combo_requested := false
var pending_damage: Damage
var jump_count := 0         # 目前已經跳了幾次
var interacting_with: Array[Interactable]

@onready var graphics: Node2D = $Graphics
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var jump_request_timer: Timer = $JumpRequestTimer
@onready var hand_checker: RayCast2D = $Graphics/HandChecker
@onready var foot_checker: RayCast2D = $Graphics/FootChecker
@onready var state_machine: StateMachine = $StateMachine
@onready var stats: Stats = $Stats
@onready var invincible_timer: Timer = $InvincibleTimer
@onready var damage_number_label: Label = $EffectLayer/DamageNumber
@onready var effect_animation_player: AnimationPlayer = $EffectLayer/DamageNumber/EffectAnimationPlayer
@onready var interaction_icon: AnimatedSprite2D = $InteractionIcon


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		jump_request_timer.start()
		
	if event.is_action_released("jump"):
		jump_request_timer.stop()
		if velocity.y < JUMP_VELOCITY / 2:
			velocity.y = JUMP_VELOCITY / 2
	
	if event.is_action_pressed("attack") and can_combo:
		is_combo_requested = true
	
	if event.is_action_pressed("interact") and interacting_with:
		interacting_with.back().interact()

func tick_physics(state: State, delta: float) -> void:
	interaction_icon.visible = not interacting_with.is_empty()
	
	if invincible_timer.time_left > 0:
		# 無敵時間閃爍效果 Time.get_ticks_msec() / 40 分母越大閃越慢
		graphics.modulate.a = sin(Time.get_ticks_msec() / 25 ) * 0.5 + 0.5
	else:
		graphics.modulate.a = 1
	
	match state:
		State.IDLE:
			move(default_gravity, delta)
		State.RUNNING:
			move(default_gravity, delta)
		State.JUMP:
			move(0.0 if is_first_tick else default_gravity, delta)
		State.FALL:
			move(default_gravity, delta)
		State.LANDING:
			stand(default_gravity, delta)
		State.WALL_SLIDING:
			move(default_gravity, delta)
			graphics.scale.x = get_wall_normal().x
			# 固定下滑速度最大值（防止撞擊天花板後速度失控暴增）
			velocity.y = min(velocity.y, 120.0)
		State.WALL_JUMP:
			if state_machine.state_time < 0.1:
				velocity.y += (0.0 if is_first_tick else default_gravity) * delta
				move_and_slide()
				graphics.scale.x = get_wall_normal().x
			else:
				move(default_gravity, delta)
		State.ATTACK_1, State.ATTACK_2:
			stand(default_gravity, delta)
			
		State.HURT, State.DYING:
			stand(default_gravity, delta)
		
	is_first_tick = false
			
			
func move(gravity: float, delta: float) -> void:
	var direction := Input.get_axis("move_left","move_right")
	#velocity.x = move_toward(velocity.x, direction * RUN_SPEED, acceleration * delta)
	velocity.x = direction * RUN_SPEED
	
	velocity.y += gravity * delta
		
	if not is_zero_approx(direction):
		graphics.scale.x = -1 if direction < 0 else +1
		
	move_and_slide()
	

func stand(gravity: float, delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	var acceleration := FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	if state_machine.current_state != State.DYING:
		if not is_zero_approx(direction):
			graphics.scale.x = -1 if direction < 0 else +1
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	velocity.y += gravity * delta
	move_and_slide()
	

func die() -> void:
	get_tree().reload_current_scene()
	
func register_interactable(v: Interactable) -> void:
	if state_machine.current_state == State.DYING:
		return
	if v in interacting_with:
		return
	interacting_with.append(v)

func unregister_interactable(v: Interactable) -> void:
	interacting_with.erase(v)

func can_wall_slide() -> bool:
	return is_on_wall() and hand_checker.is_colliding() and foot_checker.is_colliding()
	

func is_wall_slide_related_state(state: State) -> bool:
	return state == State.WALL_SLIDING or state == State.WALL_JUMP


func get_next_state(state: State) -> int:
	# 1. 死亡狀態
	if stats.health == 0:
		return StateMachine.KEEP_CURRENT if state == State.DYING else State.DYING
		
	# 2. 受傷狀態
	if pending_damage:
		return State.HURT
		
	# 3. 判斷一段跳（在地板或土狼時間內）
	var can_jump := is_on_floor() or coyote_timer.time_left > 0
	var should_jump := can_jump and jump_request_timer.time_left > 0
	if should_jump:
		return State.JUMP
	
	# 4. 判斷二段跳（在空中且按下了跳躍鍵）
	if (state == State.JUMP or state == State.FALL) and jump_request_timer.time_left > 0:
		if jump_count < max_jumps:
			return State.JUMP

	# 5. 強制的 FALL / 空中判斷
	if state in GROUND_STATES:
		if not is_on_floor() and not is_wall_slide_related_state(state):
			return State.FALL
	
	var direction := Input.get_axis("move_left","move_right")
	var is_still := is_zero_approx(direction) and is_zero_approx(velocity.x)
		
	# 6. 詳細狀態機轉換
	match state:
		State.IDLE:
			if Input.is_action_just_pressed("attack"):
				return State.ATTACK_1
			if not is_still:
				return State.RUNNING
		State.RUNNING:
			if Input.is_action_just_pressed("attack"):
				return State.ATTACK_1
			if is_still:
				return State.IDLE
		State.JUMP:
			if velocity.y >= 0:
				return State.FALL
		State.FALL:
			if is_on_floor():
				return State.LANDING if is_still else State.RUNNING
			if can_wall_slide():
				return State.WALL_SLIDING
		State.LANDING:
			if not is_still:
				return State.RUNNING
			if not animation_player.is_playing():
				return State.IDLE
		State.WALL_SLIDING:
			if jump_request_timer.time_left > 0:
				return State.WALL_JUMP
			if is_on_floor():
				return State.IDLE
			if not is_on_wall():
				return State.FALL
		State.WALL_JUMP:
			if can_wall_slide() and not is_first_tick:
				return State.WALL_SLIDING
			if velocity.y >= 0:
				return State.FALL
		State.ATTACK_1:
			if not animation_player.is_playing():
				return State.ATTACK_2 if is_combo_requested else State.IDLE
		State.ATTACK_2:
			if not animation_player.is_playing():
				return State.IDLE
		State.HURT:
			if not animation_player.is_playing():
				return State.IDLE
				
	return StateMachine.KEEP_CURRENT


func transition_state(from: State, to: State) -> void:
	if from not in GROUND_STATES and to in GROUND_STATES:
		coyote_timer.stop()
	
	animation_player.speed_scale = 1.0
	
	match to:
		State.IDLE:
			if animation_player.current_animation != "idle":
				animation_player.play("idle")
		State.RUNNING:
			if animation_player.current_animation != "running":
				animation_player.play("running")
		State.JUMP:
			animation_player.play("jump")
			velocity.y = JUMP_VELOCITY
			coyote_timer.stop()
			jump_request_timer.stop()
			# 每次成功進入跳躍狀態，跳躍計數 +1
			jump_count += 1
		State.FALL:
			if animation_player.current_animation != "fall":
				animation_player.play("fall")
			if from in GROUND_STATES:
				coyote_timer.start()
			# 如果是直接從平台邊緣走下去（而非跳躍後下落），強制把次數設為 1，確保空中只能再二段跳一次
			if from != State.JUMP and jump_count == 0:
				jump_count = 1
		State.LANDING:
			animation_player.play("landing")
		State.WALL_SLIDING:
			if animation_player.current_animation != "wall_sliding":
				animation_player.play("wall_sliding")
			# 進入貼牆瞬間重置跳躍計數
			jump_count = 0
		State.WALL_JUMP:
			animation_player.play("jump")
			velocity = WALL_JUMP_VELOCITY
			velocity.x *= get_wall_normal().x
			jump_request_timer.stop()
		State.ATTACK_1:
			animation_player.play("attack_1")
			is_combo_requested = false
		State.ATTACK_2:
			animation_player.play("attack_2")
			is_combo_requested = false
			
		State.HURT:
			animation_player.play("hurt")
			stats.health -= pending_damage.amount
			print("Player health: %s" % stats.health)
			
			var dir := pending_damage.source.global_position.direction_to(global_position)
			dir.y = 0
			velocity = dir.normalized() * KNOCKBACK_AMOUNT
			pending_damage = null
			invincible_timer.start()
		State.DYING:
			animation_player.play("die")
			animation_player.speed_scale = 0.5
			invincible_timer.stop()
			interacting_with.clear()
			
	# 當玩家重新進入任何地面狀態時，將跳躍計數安全重置
	if to in GROUND_STATES:
		jump_count = 0
			
	is_first_tick = true


func _on_hurtbox_hurt(hitbox: Hitbox) -> void:
	if invincible_timer.time_left > 0:
		return
	
	pending_damage = Damage.new()
	pending_damage.amount = 1
	pending_damage.source = hitbox.owner
	

# 處理吃藥水時顯示的補血特效
func play_heal_effect(amount: int) -> void:
	if damage_number_label and effect_animation_player:
		damage_number_label.text = "hp +" + str(amount)
		damage_number_label.visible = true
		effect_animation_player.play("heal_popup")
