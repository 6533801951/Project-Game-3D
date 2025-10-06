extends Node3D

@onready var health_bar: ProgressBar = $SubViewport/UI/BossHealthBar

func _ready():
	# ทำให้ health bar มองหน้า camera ตลอดเวลา
	set_as_top_level(true)

func _process(_delta):
	# ทำให้ health bar หันหน้าไปทาง camera ตลอดเวลา
	var camera = get_viewport().get_camera_3d()
	if camera:
		look_at(camera.global_position, Vector3.UP)
