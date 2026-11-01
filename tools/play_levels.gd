extends Node
## Joue tous les niveaux de bout en bout par de vrais événements écran, solution du solveur.
## Usage : Godot --path . res://tools/play_levels.tscn -- <dossier_captures> [on|off]
## Vérifie aussi : tap bloqué, défaite, « Recommencer », zoom, glissé, écran caché, danger ;
## avec boosters : tutoriels, pop-up, abandon, secours, vol, ×2 pub, pièces après relance.
## Code retour non nul en cas d'échec.

const TIME_SCALE: float = 6.0
const SETTLE_FRAMES: int = 4
const MAX_WAIT_FRAMES: int = 6000
const CAPTURED_LEVEL: int = 1
const FLIGHT_FRAMES: int = 10
const DIOULE_WAVE_FRAMES: int = 15
const WARNING_OCCUPIED: int = 3
const DANGER_LEVEL: int = 10
const FLIGHT_SECONDS: float = 0.7
const SAVE_PATH: String = "user://play_levels_check.json"
const RESCUE_LEVEL: int = 7
const BONUS_LEVEL: int = 1

var _main: GameMain
var _directory: String
var _failures: PackedStringArray = PackedStringArray()
var _max_draw_calls: float = 0.0
var _boosters: bool = true
var _expected_coins: int = 0
var _max_advice_ms: int = 0


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_directory = args[0]
	_boosters = args.size() < 2 or args[1] != "off"
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	Services.save = FileSaveService.new(SAVE_PATH)
	Services.wallet = SavedWalletService.new(Services.save)
	Services.analytics = AnalyticsService.new()
	Features.force_boosters(Services.save, _boosters)
	var scene: PackedScene = load("res://game/main.tscn")
	_main = scene.instantiate()
	add_child(_main)
	await _run()
	for failure: String in _failures:
		printerr(failure)
	print("Boosters %s, échecs : %d, draw calls max : %d, pièces : %d, conseil max : %d ms" % [_boosters, _failures.size(), int(_max_draw_calls), Services.wallet.balance(), _max_advice_ms])
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
		if _boosters:
			await _run_tutorials(number)
		await _check_defeat_then_retry(number)
		if _boosters and number == RESCUE_LEVEL:
			await _check_rescue(number)
			await _check_garage(number)
		await _play_solution(number)
		_expect(_main.hud.result_title.text != tr("LOST_TITLE"), "Niveau %d perdu avec la solution" % number)
		_capture("level_%02d_end" % number)
		await _check_coins_after_win(number)
		await _click_button()
	_expect(LevelProgress.current_level(Services.save, count) == 1, "Progression non revenue au niveau 1")
	_check_coins_after_relaunch()


## Le solde gagné, et rien d'autre : les boosters de ce parcours viennent tous du stock offert.
func _check_coins_after_win(number: int) -> void:
	if not _boosters:
		_expect(Services.wallet.balance() == 0, "Sans boosters : des pièces gagnées")
		return
	_expected_coins += 20
	_expect(Services.wallet.balance() == _expected_coins, "Niveau %d : %d pièces au lieu de %d" % [number, Services.wallet.balance(), _expected_coins])
	if number != BONUS_LEVEL:
		return
	await _click(_main.hud.bonus_button.get_global_rect().get_center())
	_expect(_main.hud.is_ad_curtain_visible(), "×2 : pub non affichée")
	for _frame: int in MAX_WAIT_FRAMES:
		if not _main.hud.is_ad_curtain_visible():
			break
		await get_tree().process_frame
	_expected_coins += 20
	_expect(Services.wallet.balance() == _expected_coins, "×2 : %d pièces au lieu de %d" % [Services.wallet.balance(), _expected_coins])


func _check_coins_after_relaunch() -> void:
	var reopened: FileSaveService = FileSaveService.new(SAVE_PATH)
	var wallet: SavedWalletService = SavedWalletService.new(reopened)
	_expect(wallet.balance() == _expected_coins, "Relance : %d pièces au lieu de %d" % [wallet.balance(), _expected_coins])
	if not _boosters:
		return
	var config: BoosterConfig = BoosterConfig.load_default()
	var inventory: BoosterInventory = BoosterInventory.new(config, reopened, wallet, AdsService.new())
	inventory.enter_level(LevelCatalog.level_paths().size())
	print("Après relance : %d pièces, stock Coxeur %d, stock Apprenti %d" % [wallet.balance(), inventory.stock(BoosterAccess.Kind.COXEUR), inventory.stock(BoosterAccess.Kind.APPRENTI)])
	_expect(inventory.stock(BoosterAccess.Kind.APPRENTI) == config.gift(BoosterAccess.Kind.APPRENTI) - 1, "Stock Apprenti incohérent après relance")


func _flow() -> BoosterFlow:
	return _main.get_flow()


## Tutoriels forcés au premier déblocage, joués par de vrais clics, puis le niveau repart.
func _run_tutorials(number: int) -> void:
	await _frames(SETTLE_FRAMES)
	if _main.get_inventory().needs_tutorial(BoosterAccess.Kind.COXEUR):
		await _frames(SETTLE_FRAMES)
		_expect(_flow().tutorial.visible, "Niveau %d : tutoriel Coxeur absent" % number)
		Engine.time_scale = 1.0
		await _frames(2)
		_capture("tutorial_coxeur_bar")
		await _click(_flow().tutorial.target_rect.get_center())
		await _frames(2)
		_capture("tutorial_coxeur_vehicle")
		_expect(_flow().tutorial.visible, "Tutoriel Coxeur : seconde étape absente")
		await _click(_flow().tutorial.target_rect.get_center())
		await _frames(FLIGHT_FRAMES)
		_capture("coxeur_flight")
		Engine.time_scale = TIME_SCALE
		await _settle_replay()
		_expect(_main.view.occupied_slots() <= 1, "Tutoriel Coxeur : véhicule non garé ou gare encombrée")
		_expect(not _main.get_inventory().needs_tutorial(BoosterAccess.Kind.COXEUR), "Tutoriel Coxeur non marqué")
		await _reload_level()
	if _main.get_inventory().needs_tutorial(BoosterAccess.Kind.APPRENTI):
		var vehicle_id: int = _vehicle_of_another_destination()
		_tap(_main.view.vehicle_screen_position(_main.current_level.vehicles[vehicle_id]))
		for _frame: int in MAX_WAIT_FRAMES:
			if _flow().tutorial.visible:
				break
			await get_tree().process_frame
		_expect(_flow().tutorial.visible, "Niveau %d : tutoriel Apprenti absent" % number)
		if _flow().tutorial.visible:
			Engine.time_scale = 1.0
			await _frames(2)
			_capture("tutorial_apprenti")
			await _click(_flow().tutorial.target_rect.get_center())
			await _frames(2)
			Engine.time_scale = TIME_SCALE
			await _settle_replay()
			_capture("after_apprenti")
			_expect(_main.view.occupied_slots() == 0, "Apprenti : gare non vidée")
		await _reload_level()
	if _main.get_inventory().needs_tutorial(BoosterAccess.Kind.DIOULE):
		await _check_dioule_tutorial(number)


## Tutoriel forcé, vague de saut, stock débité d'un seul Dioulé, partie relancée.
func _check_dioule_tutorial(number: int) -> void:
	await _frames(SETTLE_FRAMES)
	_expect(_flow().tutorial.visible, "Niveau %d : tutoriel Dioulé absent" % number)
	var stock: int = _main.get_inventory().stock(BoosterAccess.Kind.DIOULE)
	Engine.time_scale = 1.0
	await _frames(2)
	_capture("tutorial_dioule")
	await _click(_flow().tutorial.target_rect.get_center())
	await _frames(DIOULE_WAVE_FRAMES)
	_capture("dioule_wave")
	Engine.time_scale = TIME_SCALE
	await _settle_replay()
	_capture("after_dioule")
	_expect(_main.get_inventory().stock(BoosterAccess.Kind.DIOULE) == stock - 1, "Dioulé : stock non débité")
	_expect(not _main.get_inventory().needs_tutorial(BoosterAccess.Kind.DIOULE), "Tutoriel Dioulé non marqué")
	await _reload_level()


## Véhicule libre qui ne chargera pas tout de suite : l'Apprenti aura quelque chose à ranger.
func _vehicle_of_another_destination() -> int:
	var rules: GameRules = GameRules.new(_main.current_level)
	for id: int in rules.free_vehicles():
		if _main.current_level.vehicles[id].dest != rules.head_dest():
			return id
	_expect(false, "Aucun véhicule libre d'une autre destination")
	return rules.free_vehicles()[0]


## Un véhicule à l'écran qu'aucun bouton de la pop-up ne recouvre.
func _vehicle_point_outside_popup_buttons() -> Vector2:
	var popup: BlockedPopup = _flow().popup
	for vehicle: LevelVehicle in _main.current_level.vehicles:
		var point: Vector2 = _main.view.vehicle_screen_position(vehicle)
		var on_button: bool = false
		for button: Button in [popup.advice_button, popup.garage_button, popup.restart_button]:
			on_button = on_button or button.get_global_rect().has_point(point)
		if not on_button:
			return point
	_expect(false, "Tous les véhicules sont sous un bouton de la pop-up")
	return Vector2.ZERO


func _reload_level() -> void:
	_main.reload_current_level()
	await _frames(SETTLE_FRAMES)


func _settle_replay() -> void:
	await _main.get_tree().create_timer(2.0).timeout


## Gare bloquée, bouton conseillé, stock débité d'un seul booster, partie relancée.
func _check_rescue(number: int) -> void:
	var order: PackedInt32Array = _naive_order()
	for vehicle_id: int in order:
		_tap(_main.view.vehicle_screen_position(_main.current_level.vehicles[vehicle_id]))
		await _frames(1)
	await _wait_for_outcome()
	_expect(_flow().popup.visible, "Niveau %d : pop-up absente" % number)
	var inventory: BoosterInventory = _main.get_inventory()
	var total_stock: int = inventory.stock(BoosterAccess.Kind.COXEUR) + inventory.stock(BoosterAccess.Kind.APPRENTI)
	_tap(_vehicle_point_outside_popup_buttons())
	await _frames(2)
	_expect(_main.view.is_blocked(), "Un tap sous la pop-up a agi sur le plateau")
	await _click(_flow().popup.advice_button.get_global_rect().get_center())
	await _frames(SETTLE_FRAMES)
	_expect(not _flow().popup.visible, "Pop-up restée ouverte après le conseil")
	_expect(inventory.stock(BoosterAccess.Kind.COXEUR) + inventory.stock(BoosterAccess.Kind.APPRENTI) == total_stock - 1, "Stock : exactement un booster attendu")
	_expect(not _main.view.is_blocked(), "Niveau %d toujours bloqué après le booster" % number)
	_capture("rescue_after_advice")
	await _settle_replay()
	await _reload_level()


## Gare bloquée, Garage par pub : la gare se vide, gagne une place, le jeu reprend.
func _check_garage(number: int) -> void:
	for vehicle_id: int in _naive_order():
		_tap(_main.view.vehicle_screen_position(_main.current_level.vehicles[vehicle_id]))
		await _frames(1)
	await _wait_for_outcome()
	_expect(_flow().popup.garage_button.visible, "Niveau %d : Garage non proposé" % number)
	Engine.time_scale = 1.0
	_capture("garage_popup")
	await _click(_flow().popup.garage_button.get_global_rect().get_center())
	_expect(_main.hud.is_ad_curtain_visible(), "Garage : pub non affichée")
	for _frame: int in MAX_WAIT_FRAMES:
		if not _main.hud.is_ad_curtain_visible():
			break
		await get_tree().process_frame
	await _frames(SETTLE_FRAMES * 8)
	_capture("garage_after")
	Engine.time_scale = TIME_SCALE
	_expect(not _main.view.is_blocked(), "Niveau %d : bloqué après le Garage" % number)
	await _settle_replay()
	await _reload_level()


func _naive_order() -> PackedInt32Array:
	var rules: GameRules = GameRules.new(_main.current_level)
	var order: PackedInt32Array = PackedInt32Array()
	for _round_index: int in _main.current_level.vehicles.size():
		for vehicle: LevelVehicle in _main.current_level.vehicles:
			var events: Array[GameEvent] = rules.tap(vehicle.id)
			if not events.is_empty() and events[0].type == GameEvent.Type.MOVED:
				order.append(vehicle.id)
	return order


func _wait_for_outcome() -> void:
	for _frame: int in MAX_WAIT_FRAMES:
		if _main.hud.is_result_visible() or (_boosters and _flow().popup.visible):
			return
		await get_tree().process_frame
	_expect(false, "Ni pop-up ni écran de fin, niveau %d" % _main.current_level.id)


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
	var order: PackedInt32Array = _naive_order()
	var rules: GameRules = GameRules.new(_main.current_level)
	for vehicle_id: int in order:
		rules.tap(vehicle_id)
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
	await _wait_for_outcome()
	if _boosters and _flow().popup.visible:
		_capture("level_%02d_blocked" % number)
		var start: int = Time.get_ticks_msec()
		_main.view.advise(_main.get_inventory())
		_max_advice_ms = maxi(_max_advice_ms, Time.get_ticks_msec() - start)
		await _click(_flow().popup.restart_button.get_global_rect().get_center())
		await _frames(SETTLE_FRAMES * 2)
		_expect(Services.haptics.vibrations_ms.size() > vibrations, "Niveau %d : gare pleine sans vibration" % number)
		_expect(not _main.hud.is_result_visible() and _main.view.is_playing(), "Niveau %d : Recommencer n'a pas relancé" % number)
		return
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
