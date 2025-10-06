extends Area3D

@export var speed: float = 15.0
@export var lifetime: float = 3.0
@export var damage: int = 20

var direction: Vector3 = Vector3.ZERO

func _ready():
	# เพิ่ม visual สำหรับกระสุน
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.1, 0.1, 0.5)
	
	# ตั้งค่า collision shape
	var collision_shape = CollisionShape3D.new()
	collision_shape.shape = BoxShape3D.new()
	collision_shape.shape.size = Vector3(0.1, 0.1, 0.5)
	add_child(collision_shape)
	
	# ตั้งค่าสี
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.YELLOW
	mesh_instance.mesh = box_mesh
	mesh_instance.set_surface_override_material(0, material)
	add_child(mesh_instance)
	
	var timer = Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(_on_timeout)
	add_child(timer)
	timer.start()
	
	# เชื่อมต่อสัญญาณ
	body_entered.connect(_on_body_entered)
	
func _physics_process(delta):
	if direction != Vector3.ZERO:
		global_position += direction * speed * delta

func set_direction(new_direction: Vector3, new_speed: float):
	direction = new_direction
	speed = new_speed

func _on_body_entered(body):
	if body.is_in_group("player"):
		if body.has_method("apply_damage"):
			body.apply_damage(damage)
	queue_free()

func _on_timeout():
	queue_free()
