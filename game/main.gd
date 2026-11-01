class_name GameMain
extends Node
## Boucle de niveau : charge le niveau courant, affiche la fin, enchaîne.

const TESTER_KEY: String = "playtest_tester"
const FIRST_TESTER: int = 1

var view: LevelView = null
var hud: Hud = Hud.new()
var current_level: LevelData = null

var _catalog: VehicleCatalog
var _config: PresentationConfig
var _paths: PackedStringArray
var _level_number: int = LevelProgress.FIRST_LEVEL
var _next_level_number: int = LevelProgress.FIRST_LEVEL
var _was_lost: bool = false
var _telemetry: LevelTelemetry


func _ready() -> void:
	UiStrings.register()
	_catalog = VehicleCatalog.load_default()
	_config = PresentationConfig.load_default()
	_paths = LevelCatalog.level_paths()
	Services.analytics.tester = Services.save.get_int(TESTER_KEY, FIRST_TESTER)
	_telemetry = LevelTelemetry.new(Services.analytics)
	hud.configure(_config)
	add_child(hud)
	hud.primary_pressed.connect(_on_primary_pressed)
	hud.new_tester_requested.connect(_on_new_tester_requested)
	_start_level(LevelProgress.current_level(Services.save, _paths.size()))


func _start_level(level_number: int) -> void:
	var loaded: LevelLoadResult = LevelLoader.load_file(_paths[level_number - 1], _catalog)
	if not loaded.is_ok():
		push_error("Niveau invalide : %s" % "; ".join(loaded.errors))
		return
	if view != null:
		view.queue_free()
	_level_number = level_number
	_next_level_number = level_number
	current_level = loaded.level
	view = LevelView.new()
	add_child(view)
	view.passengers_counted.connect(hud.set_passengers)
	view.level_ended.connect(_on_level_ended)
	view.queue_blocks_changed.connect(hud.set_queue_blocks)
	view.vehicle_moved.connect(_telemetry.vehicle_moved)
	view.tap_blocked.connect(_telemetry.tap_blocked)
	view.setup(loaded.level, _config)
	hud.hide_result()
	hud.set_level(level_number)
	_telemetry.level_started(loaded.level.id, Time.get_ticks_msec())
	Events.level_started.emit(loaded.level.id)


func _on_level_ended(won: bool) -> void:
	if won:
		_show_victory()
	else:
		_was_lost = true
		_telemetry.level_failed(view.occupied_slots(), view.head_dest(), Time.get_ticks_msec())
		Events.level_lost.emit(current_level.id)
		hud.show_result("LOST_TITLE", "RETRY_BUTTON")


func _show_victory() -> void:
	var was_last: bool = LevelProgress.is_last(_level_number, _paths.size())
	_next_level_number = LevelProgress.record_win(Services.save, _level_number, _paths.size())
	_telemetry.level_won(Time.get_ticks_msec())
	Events.level_won.emit(current_level.id)
	if was_last:
		hud.show_result("ALL_DONE_TITLE", "REPLAY_BUTTON")
	else:
		hud.show_result("WON_TITLE", "NEXT_BUTTON")


func _on_primary_pressed() -> void:
	if _was_lost:
		_telemetry.level_restarted()
	_was_lost = false
	_start_level(_next_level_number)


## Rejoue le niveau courant, sans passer par l'écran de fin (outils de vérification).
func reload_current_level() -> void:
	_start_level(_level_number)


## Un même téléphone passe de main en main : nouveau numéro, retour au premier niveau.
func _on_new_tester_requested() -> void:
	var tester: int = Services.analytics.tester + 1
	Services.save.set_int(TESTER_KEY, tester)
	Services.analytics.tester = tester
	_next_level_number = LevelProgress.reset(Services.save)
	_was_lost = false
	_start_level(_next_level_number)
