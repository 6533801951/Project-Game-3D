extends CharacterBody3D

# -----------------------
# Nodes
# -----------------------
@onready var animation_player: AnimationPlayer = $enemy/AnimationPlayer
@onready var detection_area: Area3D = $DetectionArea
@onready var attack_area: Area3D = $AttackArea
@onready var gun_muzzle: Marker3D = $GunMuzzle
@onready var health_bar: ProgressBar = get_tree().root.get_node("world/UI/BossHealthBar")
@onready var kick_hitbox = $KickHitbox
@onready var punch_hitbox = $PunchHitbox
@onready var effect_shockwave = $ShockwaveExplosion
@onready var effect_melee_hit = $MeleeHitEffect

@onready var bgm_main = get_tree().root.get_node_or_null("world/map_song")
@onready var bgm_boss = $BossFightSong
# -----------------------
# Stats
# -----------------------
@export var max_health: int = 1000
var health: int = max_health
var attack_damage: int = 30
var gun_damage: int = 20
var kick_damage: int = 40
var punch_damage: int = 35

# -----------------------
# Movement & Combat
# -----------------------
var walk_speed: float = 3.0
var run_speed: float = 6.0
var rotation_speed: float = 3.0

var can_be_stunned: bool = true
var is_stunned: bool = false
var stun_duration: float = 0.5  # ความยาวเวลาสตัน (ปรับได้)

# -----------------------
# Gun System
# -----------------------
@export var bullet_scene: PackedScene
var bullet_speed: float = 15.0

# เพิ่มตัวแปรด้านบน (global)
var enraged_mode: bool = false
var burst_shots: int = 5
var burst_interval: float = 0.12
var post_burst_stun: float = 2.0
var shots_remaining_in_burst: int = 0

# -----------------------
# State Management
# -----------------------
enum BossState {
	IDLE,
	GUN_POINTING,
	GUN_SHOOTING,
	WALKING,
	RUNNING,
	KICK_LEFT,
	KICK_RIGHT,
	PUNCH_LEFT,
	DEAD
}

var current_state: BossState = BossState.IDLE
var player: CharacterBody3D = null
var distance_to_player: float = 0.0
var gun_shoot_count: int = 0
var can_attack: bool = true
var attack_cooldown: float = 1.5
var is_in_cooldown: bool = false

# -----------------------
# Timers
# -----------------------
var attack_timer: float = 0.0
var state_timer: float = 0.0
var cooldown_timer: float = 0.0

# -----------------------
# Setup
# -----------------------
func _ready():
	detection_area.body_entered.connect(_on_detection_area_entered)
	detection_area.body_exited.connect(_on_detection_area_exited)
	attack_area.body_entered.connect(_on_attack_area_entered)
	
	if animation_player:
		animation_player.animation_finished.connect(_on_animation_finished)
	
	if health_bar:
		health_bar.value = health
		
	kick_hitbox.monitoring = false
	punch_hitbox.monitoring = false

# -----------------------
# Main Loop
# -----------------------
func _physics_process(delta):
	if current_state == BossState.DEAD:
		velocity = Vector3.ZERO
		return
		
	if is_stunned:
		return
	
	update_distance_to_player()
	handle_timers(delta)
	
	if player and current_state not in [BossState.GUN_POINTING, BossState.GUN_SHOOTING]:
		look_at_player(delta)
	
	handle_state_machine(delta)
	
	if current_state in [BossState.WALKING, BossState.RUNNING]:
		handle_movement()

# -----------------------
# Core Systems
# -----------------------
func update_distance_to_player():
	if player:
		distance_to_player = global_position.distance_to(player.global_position)

func look_at_player(delta):
	var direction = (player.global_position - global_position).normalized()
	var target_rotation = atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)

func handle_timers(delta):
	if attack_timer > 0:
		attack_timer -= delta
	else:
		can_attack = true
	
	if state_timer > 0:
		state_timer -= delta
	
	if cooldown_timer > 0:
		cooldown_timer -= delta
	else:
		is_in_cooldown = false

# -----------------------
# State Machine
# -----------------------
func handle_state_machine(delta):
	if is_in_cooldown:
		return
		
	match current_state:
		BossState.IDLE:
			handle_idle_state()
		BossState.GUN_POINTING:
			handle_gun_pointing_state()
		BossState.GUN_SHOOTING:
			handle_gun_shooting_state()
		BossState.WALKING:
			handle_walking_state()
		BossState.RUNNING:
			handle_running_state()
		BossState.KICK_LEFT, BossState.KICK_RIGHT, BossState.PUNCH_LEFT:
			handle_melee_attack_state()

func handle_movement():
	if not player:
		return
	var direction = (player.global_position - global_position).normalized()
	if current_state == BossState.WALKING:
		velocity = direction * walk_speed
	elif current_state == BossState.RUNNING:
		velocity = direction * run_speed
	move_and_slide()

# -----------------------
# State Change
# -----------------------
func change_state(new_state: BossState):
	if current_state == new_state:
		return
	current_state = new_state
	state_timer = 0.0
	
	if animation_player:
		match new_state:
			BossState.IDLE:
				animation_player.play("Idle_Gun")
			BossState.GUN_POINTING:
				animation_player.play("Idle_Gun_Pointing")
				$GunPointing.play()
				state_timer = 1.5
			BossState.GUN_SHOOTING:
				animation_player.play("Idle_Gun_Shoot")
				shoot_gun()
				gun_shoot_count += 1
				state_timer = 0.8
			BossState.WALKING:
				animation_player.play("Walk")
			BossState.RUNNING:
				animation_player.play("Run")
			BossState.KICK_LEFT:
				animation_player.play("Kick_Left")
				state_timer = 0.92
				_spawn_melee_effect_delayed(0.2)
			BossState.KICK_RIGHT:
				animation_player.play("Kick_Right")
				state_timer = 0.92
				_spawn_melee_effect_delayed(0.2)
			BossState.PUNCH_LEFT:
				animation_player.play("Punch_Left")
				state_timer = 0.84
				_spawn_melee_effect_delayed(0.2)
			BossState.DEAD:
				animation_player.play("Death")
				set_physics_process(false)

# -----------------------
# State Logic
# -----------------------
func handle_idle_state():
	if not player:
		return
	if distance_to_player >= 6.0:
		change_state(BossState.GUN_POINTING)
	elif distance_to_player <= 3.0:
		start_melee_attack()
	elif distance_to_player <= 5.0:
		change_state(BossState.WALKING)

func handle_gun_pointing_state():
	if state_timer <= 0:
		change_state(BossState.GUN_SHOOTING)

func handle_gun_shooting_state():
	if distance_to_player <= 1.5:
		print("⚠️ Player too close — interrupt gun shooting!")
		gun_shoot_count = 0
		change_state(BossState.KICK_LEFT)  # หรือ start_melee_attack()
		return
	if state_timer <= 0:
		if gun_shoot_count >= 3:
			gun_shoot_count = 0
			start_cooldown(0.5)
			if distance_to_player >= 10.0:
				change_state(BossState.RUNNING)
			elif distance_to_player > 5.0:
				change_state(BossState.WALKING)
			else:
				start_melee_attack()
		else:
			change_state(BossState.GUN_POINTING)

func handle_walking_state():
	if not player:
		change_state(BossState.IDLE)
		return
	if distance_to_player <= 3.0:
		start_melee_attack()
	elif distance_to_player >= 10.0:
		change_state(BossState.GUN_POINTING)

func handle_running_state():
	if not player:
		change_state(BossState.IDLE)
		return
	if distance_to_player <= 10.0:
		change_state(BossState.GUN_POINTING)

func handle_melee_attack_state():
	if state_timer <= 0:
		can_attack = false
		attack_timer = attack_cooldown
		start_cooldown(1.0)
		if distance_to_player <= 1.5:
			start_melee_attack()
		else:
			change_state(BossState.IDLE)

# -----------------------
# Combat
# -----------------------
func start_melee_attack():
	if not can_attack or not player:
		return
	var attacks = [BossState.KICK_LEFT, BossState.KICK_RIGHT, BossState.PUNCH_LEFT]
	var random_attack = attacks[randi() % attacks.size()]
	change_state(random_attack)

func shoot_gun():
	if not player or not bullet_scene:
		return

	if enraged_mode:
		if shots_remaining_in_burst <= 0:
			shots_remaining_in_burst = burst_shots
			_start_burst_fire()
		return

	# ปกติยิงทีละนัด
	_spawn_bullet()

func _start_burst_fire() -> void:
	# ยิงชุดแบบ asynchronous (ใช้ timer/await)
	# ปิด movement/AI ชั่วคราวเพื่อให้เป็นการยิงต่อเนื่อง
	is_in_cooldown = true
	current_state = BossState.GUN_SHOOTING
	# ยิง shots_remaining_in_burst นัด
	while shots_remaining_in_burst > 0:
		_spawn_bullet()
		shots_remaining_in_burst -= 1
		await get_tree().create_timer(burst_interval).timeout
	# หลังยิงจบ → สตั้น boss 2 วินาที (ไม่ขยับ)
	is_stunned = true
	await get_tree().create_timer(post_burst_stun).timeout
	is_stunned = false
	is_in_cooldown = false
	# ให้ boss เลือก state ใหม่โดย force call handle logic
	change_state(BossState.IDLE)

func _spawn_bullet():
	var bullet = bullet_scene.instantiate()
	# ใส่ลงใน current scene root เพื่อไม่ให้ถูก parent กับ boss (avoid immediate collision)
	get_tree().current_scene.add_child(bullet)
	$GunShooting.play()
	var spawn_offset = -gun_muzzle.global_transform.basis.z * 0.6 # -z is forward sometimes depending on model
	bullet.global_transform.origin = gun_muzzle.global_transform.origin + spawn_offset
	# aim a bit at player's chest
	var target_position = player.global_transform.origin + Vector3(0, 1.2, 0)
	var dir = (target_position - bullet.global_transform.origin).normalized()
	if bullet.has_method("set_direction"):
		bullet.set_direction(dir, bullet_speed)
	# optional: set bullet collision layer/mask if needed:
	# bullet.collision_layer = <enemy_bullet_layer>
	# bullet.collision_mask = <player_layer>

func _trigger_shockwave():
	if not is_instance_valid(player):
		return

	print("⚡ Boss enraged shockwave triggered!")
	if effect_shockwave:
		effect_shockwave.global_position = global_position
		effect_shockwave.emitting = true
		$Explosion1.play()

	# ✅ ผลัก Player ออกไปจาก Boss 30 เมตร
	var direction = (player.global_position - global_position).normalized()
	var target_position = global_position + (direction * 20.0)

	var tween = create_tween()
	tween.tween_property(player, "global_position", target_position, 0.8)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

	# ✅ ตัด stamina ให้หมดจริง (ไม่ผ่าน apply_stamina)
	player.stamina = 0
	if player.hud and player.hud.has_method("set_stamina"):
		player.hud.set_stamina(0)

	# ✅ หยุดระบบ regen ทันที
	if player.has_node("StaminaRegenTimer"):
		player.get_node("StaminaRegenTimer").stop()
	player.can_regen_stamina = false

	# ✅ ปิด regen 2 วิ
	await get_tree().create_timer(2.0).timeout

	if is_instance_valid(player):
		player.can_regen_stamina = true

# -----------------------
# Utility
# -----------------------
func start_cooldown(time: float):
	is_in_cooldown = true
	cooldown_timer = time

func apply_damage(damage: int):
	if is_stunned or current_state == BossState.DEAD:
		return  # ถ้ากำลังสตันหรือบอสตายแล้ว ไม่ต้องซ้ำอีก

	health -= damage
	health = max(0, health)
	
	if health_bar:
		health_bar.value = health

	if can_be_stunned:
		is_stunned = true
		can_be_stunned = false
		animation_player.play("HitRecieve")
		$BossHurt.play()
		change_state(BossState.IDLE) # บังคับหยุดทุก action
		await get_tree().create_timer(stun_duration).timeout
		is_stunned = false
		print("Boss recovered from stun.")
	else:
		# ถ้าสตันไม่ได้ เล่นอนิเมชันเจ็บธรรมดาแทน
		animation_player.play("HitRecieve_2")
	if not enraged_mode and float(health) <= float(max_health) * 0.3:
		enraged_mode = true
		_trigger_shockwave()
		
	if health <= 0:
		if bgm_boss and bgm_boss.playing:
			bgm_boss.stop()
		
	# ✅ เปลี่ยนสถานะก่อน แต่ยังไม่เปลี่ยน scene ทันที
		change_state(BossState.DEAD)
	
	# ✅ หยุด hitbox ทั้งหมด
		kick_hitbox.monitoring = false
		punch_hitbox.monitoring = false
		attack_area.monitoring = false
		
		# ✅ ปิดการทำงานอื่น ๆ ของบอส
		is_stunned = true
		is_in_cooldown = true
		can_attack = false
		
		# ✅ เล่น animation death แล้วรอให้จบก่อน
		if animation_player:
			animation_player.play("Death")
			await animation_player.animation_finished
			print("☠️ Boss animation finished.")
		
		# ✅ ไปหน้า win scene หลังจากอนิเมชันจบ
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_file("res://scenes/win.tscn")
		

# -----------------------
# Signal Handlers
# -----------------------
func _on_detection_area_entered(body):
	if body.is_in_group("player"):
		player = body
		if bgm_main and bgm_main.playing:
			bgm_main.stop()
		if bgm_boss and not bgm_boss.playing:
			bgm_boss.play()

func _on_detection_area_exited(body):
	if body == player:
		player = null
		change_state(BossState.IDLE)
		print("Boss: Player lost")

func _on_attack_area_entered(body):
	if current_state == BossState.DEAD:
		return
	if body.is_in_group("player"):
		match current_state:
			BossState.KICK_LEFT, BossState.KICK_RIGHT:
				body.apply_damage(kick_damage)
			BossState.PUNCH_LEFT:
				body.apply_damage(punch_damage)


# -----------------------
# Animation Finished (Delay System)
# -----------------------
func _on_animation_finished(anim_name):
	match anim_name:
		"Idle_Gun_Pointing":
			if current_state == BossState.GUN_POINTING:
				await get_tree().create_timer(0.3).timeout
				change_state(BossState.GUN_SHOOTING)
				
		"Idle_Gun_Shoot":
			if current_state == BossState.GUN_SHOOTING:
				await get_tree().create_timer(0.4).timeout
				if gun_shoot_count >= 3:
					gun_shoot_count = 0
					start_cooldown(0.5)
					if distance_to_player >= 10.0:
						change_state(BossState.RUNNING)
					elif distance_to_player > 5.0:
						change_state(BossState.WALKING)
					else:
						start_melee_attack()
				else:
					change_state(BossState.GUN_POINTING)

		"Kick_Left", "Kick_Right", "Punch_Left":
			await get_tree().create_timer(0.6).timeout
			if current_state != BossState.DEAD:
				change_state(BossState.IDLE)

		"Walk", "Run":
			if current_state == BossState.WALKING:
				animation_player.play("Walk")
			elif current_state == BossState.RUNNING:
				animation_player.play("Run")

		"Idle_Gun":
			if current_state == BossState.IDLE:
				animation_player.play("Idle_Gun")

func _on_kick_hitbox_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.has_method("apply_damage"):
			body.apply_damage(kick_damage)

func _on_punch_hitbox_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.has_method("apply_damage"):
			body.apply_damage(punch_damage)
			
func _spawn_melee_effect_delayed(delay: float = 0.2):
	await get_tree().create_timer(delay).timeout
	# ถ้าบอสตายก่อน effect จะไม่ต้องเล่น
	if current_state == BossState.DEAD:
		return
	if not effect_melee_hit:
		return
	var effect = effect_melee_hit.duplicate()
	get_parent().add_child(effect)
	# ตั้งตำแหน่ง effect ให้อยู่หน้าบอส (หรือปลายหมัด/เท้า)
	effect.global_position = global_position + (global_transform.basis.z * 0.5)
	effect.emitting = true
	$Explosion2.play()
	# ลบ node หลังจบ effect (ป้องกัน clutter)
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(effect):
		effect.queue_free()
