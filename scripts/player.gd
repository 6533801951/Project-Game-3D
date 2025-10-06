extends CharacterBody3D

@onready var camera_stand = $camera_stand
@onready var animation_player = $visuals/Character/AnimationPlayer
@onready var visuals = $visuals
@onready var weapon = $visuals/Character/RootNode/CharacterArmature/Skeleton3D/Middle4_R/Weapon
@onready var hud = get_tree().root.get_node("world/UI")
@onready var stamina_regen_timer_node = $StaminaRegenTimer

var max_health: int = 100
var health: int = 100
var max_stamina: float = 100
var stamina: float = 100
var stamina_regen_rate: float = 15.0
var stamina_regen_delay: float = 1.0
var sword_damage = 25

var SPEED = 2.5
const JUMP_VELOCITY = 4.5
var walk_speed = 2.5
var run_speed = 5
var roll_speed = 8.0

var running = false
var is_locked = false
var is_rolling = false
var can_regen_stamina: bool = true
var roll_direction = Vector3.ZERO
var is_invincible: bool = false

@export var sens_horizontal = 0.25
@export var sens_vertical = 0.25

var combo_step: int = 0                # ลำดับคอมโบ (1-3)
var combo_timer: float = 0.0           # ตัวจับเวลารีเซ็ตคอมโบ
var combo_window: float = 1.0          # เวลาที่อนุญาตให้ต่อคอมโบได้
var combo_queued: bool = false         # กดโจมตีระหว่างอนิเมชัน
var attack_stamina_cost: float = 15.0  # ค่าการใช้สตามินาแต่ละครั้ง

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	stamina_regen_timer_node.wait_time = stamina_regen_delay
	stamina_regen_timer_node.one_shot = true
	stamina_regen_timer_node.timeout.connect(_on_stamina_regen_timeout)
	
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * sens_horizontal))
		visuals.rotate_y(deg_to_rad(event.relative.x * sens_horizontal))
		camera_stand.rotate_x(deg_to_rad(-event.relative.y * sens_vertical))
		
func _physics_process(delta: float) -> void:
		
	if stamina < max_stamina and can_regen_stamina:
		apply_stamina_regen(delta)
		
	if combo_timer > 0:
		combo_timer -= delta
	else:
		combo_step = 0
		
	if !animation_player.is_playing():
		is_locked = false
		is_rolling = false
		
	if is_rolling:
		velocity = roll_direction.normalized() * roll_speed
		move_and_slide()
		return
		
	#Standard Movement WASD
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		if !is_locked:
			if running:
				if animation_player.current_animation != "Run":
					animation_player.play("Run")
					$WalkEffect.pitch_scale = 1.4
					$WalkEffect.play()
			else:
				if animation_player.current_animation != "Walk":
					animation_player.play("Walk")
					$WalkEffect.play()
			visuals.look_at(position + direction)
			
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		if !is_locked:
			if animation_player.current_animation != "Idle_Sword":
				animation_player.play("Idle_Sword")
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		
	if !is_locked:
		move_and_slide()
		
	#Attack with sword
	if Input.is_action_just_pressed("attack") and !is_rolling:
		handle_attack_input()
			
	#Running
	if Input.is_action_pressed("run") and !is_rolling:
		if stamina > 0:
			SPEED = run_speed
			running = true
			apply_stamina(10 * delta)
		else:
			SPEED = walk_speed
			running = false
	else:
		SPEED = walk_speed
		running = false
		
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	#Rolling
	if Input.is_action_just_pressed("roll") and !is_locked and direction != Vector3.ZERO:
		if stamina >= 25:
			if animation_player.current_animation != "Roll":
				animation_player.play("Roll")
				animation_player.speed_scale = 2
			roll_direction = direction
			velocity = roll_direction * roll_speed
			apply_stamina(25)
			is_locked = true
			is_rolling = true
			is_invincible = true
			
	if Input.is_action_just_pressed("heal"):
		use_heal_item()
	
func handle_attack_input():
	if stamina < attack_stamina_cost:
		return
	
	# ถ้ากำลังเล่นอนิเมชันโจมตีอยู่ → รอจบก่อน (queue)
	if is_locked:
		combo_queued = true
		return
	
	# เริ่มการโจมตี
	combo_step += 1
	if combo_step > 3:
		combo_step = 1

	match combo_step:
		1:
			play_attack_animation("Sword_Slash")
			$SwordSwingEffect.play()
		2:
			play_attack_animation("Sword_Slash")
			$SwordSwingEffect.play()
		3:
			play_attack_animation("Sword_Slash")
			$SwordSwingEffect.play()

	combo_timer = combo_window  # รีเซ็ตเวลา
	apply_stamina(attack_stamina_cost)
	is_locked = true
	combo_queued = false

func play_attack_animation(anim_name: String):
	if animation_player.current_animation != anim_name:
		animation_player.play(anim_name)
			
func apply_damage(amount: int):
	if is_invincible:
		return  # ❌ ไม่รับดาเมจตอนกำลัง Roll
	health = max(health - amount, 0)
	$HurtEffect.play()
	if hud and hud.has_method("set_health"):
		hud.set_health(health)
		
	if health <= 0:
		get_tree().root.get_node_or_null("world/Boss/BossFightSong").stop() 
		is_locked = true
		animation_player.play("Death")
		is_invincible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		set_physics_process(false)
		set_process_input(false)
		await animation_player.animation_finished
		_show_game_over()

func _show_game_over():
	get_tree().change_scene_to_file("res://scenes/game_over.tscn")

func apply_stamina(amount: float):
	stamina = clamp(stamina - amount, 0, max_stamina)
	if hud and hud.has_method("set_stamina"):
		hud.set_stamina(stamina)
	can_regen_stamina = false
	stamina_regen_timer_node.start()

func apply_stamina_regen(delta: float):
	stamina = clamp(stamina + stamina_regen_rate * delta, 0, max_stamina)
	if hud and hud.has_method("set_stamina"):
		hud.set_stamina(stamina)
		
func _on_stamina_regen_timeout():
	can_regen_stamina = true

func use_heal_item():
	if hud and hud.has_method("use_item"):
		if hud.use_item():
			$HealEffect.play()
			heal(50) # ฟื้นฟู 30 HP ต่อขวด
		else:
			print("No items left!")

func heal(amount: int):
	health = clamp(health + amount, 0, max_health)
	if hud and hud.has_method("set_health"):
		hud.set_health(health)

func _on_hurt_box_area_entered(area: Area3D) -> void:
	if area.is_in_group("enemy_attack"):
		if area.has_meta("damage"):
			var damage = area.get_meta("damage")
			apply_damage(damage)

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemy"):
		if body.has_method("apply_damage"):
			body.apply_damage(sword_damage)

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "Roll":
		is_invincible = false
