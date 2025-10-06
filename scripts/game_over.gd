extends CanvasLayer

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_btn_home_pressed() -> void:
	$Click.play()
	get_tree().change_scene_to_file("res://scenes/Home.tscn")

func _on_btn_exit_pressed() -> void:
	$Click.play()
	get_tree().quit()
