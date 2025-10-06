extends Control


func _on_button_pressed() -> void:
	if not is_inside_tree():
		return
	$Click.play()
	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file("res://scenes/Home.tscn")
