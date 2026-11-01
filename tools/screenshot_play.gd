extends Node
## Lance le jeu, tape par de vrais événements écran et enregistre une capture.
## Usage : Godot --path . res://tools/screenshot_play.tscn -- <dossier>


func _ready() -> void:
	var directory: String = OS.get_cmdline_user_args()[0]
	var scene: PackedScene = load("res://game/main.tscn")
	var main: Node = scene.instantiate()
	add_child(main)
	await get_tree().create_timer(0.5).timeout
	_capture(directory + "/level_start.png")
	var view: LevelView = main.get("view")
	var catalog: VehicleCatalog = VehicleCatalog.load_default()
	var level: LevelData = LevelLoader.load_file(LevelCatalog.level_paths()[0], catalog).level
	_tap(view.vehicle_screen_position(level.vehicles[1]))
	await get_tree().create_timer(0.1).timeout
	_capture(directory + "/level_blocked.png")
	_tap(view.vehicle_screen_position(level.vehicles[0]))
	await get_tree().create_timer(1.5).timeout
	_capture(directory + "/level_parked.png")
	print("Draw calls : %d" % Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	get_tree().quit()


func _tap(position: Vector2) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.pressed = true
	event.position = get_viewport().get_final_transform() * position
	Input.parse_input_event(event)


func _capture(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)
