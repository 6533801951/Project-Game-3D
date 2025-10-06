extends Control

func _on_startgame_pressed() -> void:
	if not is_inside_tree():
		return
	$Click.play()
	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_tutorial_pressed() -> void:
	if not is_inside_tree():
		return
	$Click.play()
	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file("res://scenes/tutorial.tscn")
	
func _on_exitgame_pressed() -> void:
	if not is_inside_tree():
		return
	$Click.play()
	await get_tree().create_timer(0.1).timeout  # รอให้เสียงเล่นก่อน
	get_tree().quit()
