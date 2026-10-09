extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var packed_scene := load("res://scenes/main.tscn") as PackedScene
	var scene := packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.call("_on_card_pressed", 1)
	scene.call("_on_operator_pressed", "+")
	scene.call("_on_card_pressed", 2)
	await process_frame
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	var result := image.save_png("res://build/numforge-merged-native.png")
	if result != OK:
		push_error("Unable to save merged-state capture")
		quit(1)
	print("NUMFORGE_MERGED_CAPTURE_OK")
	quit()
