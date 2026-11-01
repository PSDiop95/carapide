extends Node
## Joue tous les niveaux de bout en bout par de vrais événements écran, solution du solveur.
## Usage : Godot --path . res://tools/play_levels.tscn -- <dossier_captures>
## Vérifie aussi : tap bloqué, défaite, « Recommencer », zoom, glissé, écran caché, danger.
## Code retour non nul en cas d'échec.

const TIME_SCALE: float = 6.0
const SETTLE_FRAMES: int = 4
const MAX_WAIT_FRAMES: int = 6000
const CAPTURED_LEVEL: int = 1
const FLIGHT_FRAMES: int = 10
const WARNING_OCCUPIED: int = 3
const DANGER_LEVEL: int = 10
const FLIGHT_SECONDS: float = 0.7

var _main: GameMain
var _directory: String
var _failures: PackedStringArray = PackedStringArray()
var _max_draw_calls: float = 0.0


func _ready() -> void:
	_directory = OS.get_cmdline_user_args()[0]
	Services.save = SaveService.new()
	Services.analytics = AnalyticsService.new()
	var scene: PackedScene = load("res://game/main.tscn")
	_main = scene.instantiate()
	add_child(_main)
	await _run()
	for failure: String in _failures:
		printerr(failure)
	print("Échecs : %d, draw calls max : %d" % [_failures.size(), int(_max_draw_calls)])
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _run() -> void:
	var count: int = LevelCatalog.level_paths().size()
	await _frames(SETTLE_FRAMES)
	await _check_gestures()
	await _check_hidden_panel()
	await _check_danger_and_flight()
	Engine.time_scale = TIME_SCALE
	for number: int in range(1, count + 1):
		await _frames(SETTLE_FRAMES)
		Engine.time_scale = 1.0
		_capture("level_%02d_start" % number)
		Engine.time_scale = TIME_SCALE
		await _check_defeat_then_retry(number)
		await _play_solution(number)
		_expect(_main.hud.result_title.text != tr("LOST_TITLE"), "Niveau %d perdu avec la solution" % number)
		_capture("level_%02d_end" % number)
		await _click_button()
	_expect(LevelProgress.current_level(Services.save, count) == 1, "Progression non revenue au niveau 1")


## Vrais événements tactiles : pincement, glissé, molette ; aucun ne doit sortir de véhicule.
func _check_gestures() -> void:
	var view: LevelView = _main.view
	var base_size: float = view.camera.size
	var remaining: int = view.occupied_slots()
	var center: Vector2 = get_viewport().get_visible_rect().size * 0.5
	_touch(0, center - Vector2(50, 0), true)
	_touch(1, center + Vector2(50, 0), true)
	_drag(1, center + Vector2(400, 0))
	await _frames(2)
	_expect(is_equal_approx(view.camera.size, base_size / PresentationConfig.load_default().zoom_max), "Pincement : zoom non borné à ×1,8")
	_touch(1, center + Vector2(400, 0), false)
	_touch(0, center - Vector2(50, 0), false)
	await _frames(2)
	var before: Vector3 = view.camera.position
	_touch(0, center, true)
	_drag(0, center + Vector2(120, 80))
	_touch(0, center + Vector2(120, 80), false)
	await _frames(2)
	_expect(not view.camera.position.is_equal_approx(before), "Glissé : caméra immobile")
	_expect(view.occupied_slots() == remaining, "Glissé : un véhicule est sorti")
	for _step: int in 12:
		_wheel(center, MOUSE_BUTTON_WHEEL_DOWN)
	await _frames(2)
	_expect(is_equal_approx(view.camera.size, base_size), "Molette : retour à ×1 manqué")


func _check_hidden_panel() -> void:
	var hud: Hud = _main.hud
	var at: Vector2 = hud.level_button.get_global_rect().get_center()
	for _step: int in Hud.HIDDEN_TAPS:
		_expect(not hud.playtest_panel.visible, "Écran caché ouvert trop tôt")
		await _click(at)
	_expect(hud.playtest_panel.visible, "Écran caché fermé après 5 taps")
	await _frames(1)
	_capture("playtest_panel")
	var tester: int = Services.analytics.tester
	hud.new_tester_requested.emit()
	hud.playtest_panel.hide()
	await _frames(SETTLE_FRAMES)
	_expect(Services.analytics.tester == tester + 1, "Nouveau testeur non compté")
	_expect(_main.current_level.id == 1, "Nouveau testeur : pas revenu au niveau 1")


## Niveau 1 à vitesse réelle : capture d'un véhicule en vol, puis garé.
func _check_danger_and_flight() -> void:
	var level: LevelData = _main.current_level
	var free: PackedInt32Array = GameRules.new(level).free_vehicles()
	_tap(_main.view.vehicle_screen_position(level.vehicles[free[0]]))
	await _frames(FLIGHT_FRAMES)
	_capture("flight_mid")
	await _main.get_tree().create_timer(FLIGHT_SECONDS).timeout
	_capture("flight_parked")
	_main.reload_current_level()
	await _frames(SETTLE_FRAMES)


## Sort les véhicules dans l'ordre le plus naïf ; si cela perd, vérifie « Recommencer ».
func _check_defeat_then_retry(number: int) -> void:
	var rules: GameRules = GameRules.new(_main.current_level)
	var order: PackedInt32Array = PackedInt32Array()
	for round_index: int in _main.current_level.vehicles.size():
		for vehicle: LevelVehicle in _main.current_level.vehicles:
			var events: Array[GameEvent] = rules.tap(vehicle.id)
			if not events.is_empty() and events[0].type == GameEvent.Type.MOVED:
				order.append(vehicle.id)
	if rules.status != GameRules.Status.LOST:
		return
	var vibrations: int = Services.haptics.vibrations_ms.size()
	var warned: bool = false
	for vehicle_id: int in order:
		_tap(_main.view.vehicle_screen_position(_main.current_level.vehicles[vehicle_id]))
		await _frames(1)
		if _main.view.occupied_slots() == WARNING_OCCUPIED and not warned and number == DANGER_LEVEL:
			warned = true
			await _frames(FLIGHT_FRAMES * 2)
			_capture("danger_warning")
	await _wait_for_result()
	_expect(Services.haptics.vibrations_ms.size() > vibrations, "Niveau %d : gare pleine sans vibration" % number)
	_expect(_main.hud.result_title.text == tr("LOST_TITLE"), "Niveau %d : écran de défaite absent" % number)
	if number == CAPTURED_LEVEL or _main.hud.result_title.text == tr("LOST_TITLE"):
		_capture("level_%02d_lost" % number)
	await _click_button()
	await _frames(SETTLE_FRAMES)


func _play_solution(number: int) -> void:
	var result: SolverResult = Solver.solve(_main.current_level, _main.current_level.slots)
	_expect(result.solvable, "Niveau %d insoluble" % number)
	for vehicle_id: int in result.solution:
		_tap(_main.view.vehicle_screen_position(_main.current_level.vehicles[vehicle_id]))
		await _frames(1)
		_max_draw_calls = maxf(_max_draw_calls, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	await _wait_for_result()


func _wait_for_result() -> void:
	for _frame: int in MAX_WAIT_FRAMES:
		if _main.hud.is_result_visible():
			Engine.time_scale = 1.0
			await _frames(SETTLE_FRAMES)
			Engine.time_scale = TIME_SCALE
			return
		await get_tree().process_frame
	_expect(false, "Écran de fin jamais affiché, niveau %d" % _main.current_level.id)


func _click(at: Vector2) -> void:
	var final: Vector2 = get_viewport().get_final_transform() * at
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = final
		event.global_position = final
		Input.parse_input_event(event)
		await _frames(2)


func _touch(index: int, at: Vector2, pressed: bool) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = get_viewport().get_final_transform() * at
	Input.parse_input_event(event)


func _drag(index: int, at: Vector2) -> void:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.index = index
	event.position = get_viewport().get_final_transform() * at
	Input.parse_input_event(event)


func _wheel(at: Vector2, button: MouseButton) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = get_viewport().get_final_transform() * at
	event.global_position = event.position
	Input.parse_input_event(event)


func _click_button() -> void:
	var button: Button = _main.hud.primary_button
	var at: Vector2 = get_viewport().get_final_transform() * button.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		Input.parse_input_event(event)
		await _frames(2)
	_expect(not _main.hud.is_result_visible(), "Le bouton n'a pas fermé l'écran de fin")


func _tap(viewport_position: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventScreenTouch = InputEventScreenTouch.new()
		event.pressed = pressed
		event.position = get_viewport().get_final_transform() * viewport_position
		Input.parse_input_event(event)


func _frames(count: int) -> void:
	for _frame: int in count:
		await get_tree().process_frame


func _capture(file_name: String) -> void:
	if DisplayServer.get_name() != "headless":
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_directory, file_name])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
