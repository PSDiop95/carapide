class_name GameMain
extends Node
## Boucle de niveau : charge le niveau courant, affiche la fin, enchaîne.

var view: LevelView = null
var hud: Hud = Hud.new()
var current_level: LevelData = null

var _catalog: VehicleCatalog
var _config: PresentationConfig
var _paths: PackedStringArray
var _level_number: int = LevelProgress.FIRST_LEVEL
var _next_level_number: int = LevelProgress.FIRST_LEVEL


func _ready() -> void:
	UiStrings.register()
	_catalog = VehicleCatalog.load_default()
	_config = PresentationConfig.load_default()
	_paths = LevelCatalog.level_paths()
	add_child(hud)
	hud.primary_pressed.connect(_on_primary_pressed)
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
	view.setup(loaded.level, _config)
	hud.hide_result()
	hud.set_level(level_number)
	Services.analytics.log_event("level_start")
	Events.level_started.emit(loaded.level.id)


func _on_level_ended(won: bool) -> void:
	if won:
		_show_victory()
	else:
		Services.analytics.log_event("level_fail")
		Events.level_lost.emit(current_level.id)
		hud.show_result("LOST_TITLE", "RETRY_BUTTON")


func _show_victory() -> void:
	var was_last: bool = LevelProgress.is_last(_level_number, _paths.size())
	_next_level_number = LevelProgress.record_win(Services.save, _level_number, _paths.size())
	Services.analytics.log_event("level_win")
	Events.level_won.emit(current_level.id)
	if was_last:
		hud.show_result("ALL_DONE_TITLE", "REPLAY_BUTTON")
	else:
		hud.show_result("WON_TITLE", "NEXT_BUTTON")


func _on_primary_pressed() -> void:
	_start_level(_next_level_number)
