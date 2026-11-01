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
var _inventory: BoosterInventory = null
var _flow: BoosterFlow = null
var _victory_coins: int = 0
var _restart_after_loss: bool = false


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
	hud.boosters_toggled.connect(_on_boosters_toggled)
	hud.bonus_pressed.connect(_on_bonus_pressed)
	Services.wallet.balance_changed.connect(_on_balance_changed)
	_apply_boosters_flag()
	_start_level(LevelProgress.current_level(Services.save, _paths.size()))
	_start_measure_if_requested()
	PerfProbe.log_interactive.call_deferred()


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
	if _inventory != null:
		_inventory.enter_level(level_number)
	view.passengers_counted.connect(hud.set_passengers)
	view.level_ended.connect(_on_level_ended)
	view.queue_blocks_changed.connect(hud.set_queue_blocks)
	view.vehicle_moved.connect(_telemetry.vehicle_moved)
	view.tap_blocked.connect(_telemetry.tap_blocked)
	if _inventory != null:
		var coxeur_visible: bool = _inventory.is_unlocked(BoosterAccess.Kind.COXEUR)
		view.setup(loaded.level, _config, _inventory, coxeur_visible)
		_flow.attach(view)
	else:
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
		if _restart_after_loss:
			_restart_after_loss = false
			_on_primary_pressed()
		else:
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
	if _inventory != null:
		_award_victory()


func _award_victory() -> void:
	var config: BoosterConfig = _inventory.config
	Services.wallet.add(config.victory_coins)
	_victory_coins = config.victory_coins
	hud.show_coins_earned(tr("VICTORY_COINS") % _victory_coins)
	if Services.ads.is_rewarded_available():
		hud.show_bonus(tr("VICTORY_DOUBLE") % config.victory_ad_multiplier)


## Pub vue jusqu'au bout : le gain de la victoire est multiplié, une seule fois.
func _on_bonus_pressed() -> void:
	hud.hide_bonus()
	hud.show_ad_curtain()
	var watched: bool = await Services.ads.show_rewarded()
	hud.hide_ad_curtain()
	if not watched:
		return
	var multiplier: int = _inventory.config.victory_ad_multiplier
	Services.wallet.add(_victory_coins * (multiplier - 1))
	_victory_coins *= multiplier
	hud.show_coins_earned(tr("VICTORY_COINS") % _victory_coins)


func _on_primary_pressed() -> void:
	if _was_lost:
		_telemetry.level_restarted()
	_was_lost = false
	_start_level(_next_level_number)


func _start_measure_if_requested() -> void:
	var effect: String = PerfProbe.requested_effect()
	if effect.is_empty():
		return
	var probe: PerfProbe = PerfProbe.new()
	probe.setup(self, effect)
	add_child(probe)


## Mesure : tutoriels déjà vus, aucun écran ne bloque le jeu automatique.
func prepare_for_measure() -> void:
	if _inventory != null:
		for kind: BoosterAccess.Kind in BoosterConfig.KIND_KEYS:
			_inventory.mark_tutorial_done(kind)


func jump_to_level(level_number: int) -> void:
	_was_lost = false
	_start_level(level_number)


## Mesure : un pas de jeu automatique. Recommence dès que la partie se termine ou se bloque.
func measure_step(effect: String) -> void:
	if hud.is_result_visible():
		_was_lost = false
		_start_level(_level_number)
	elif _flow != null and _flow.popup.visible:
		_flow.measure_resolve_popup(effect)
	elif _flow == null or not _flow.measure_effect(effect):
		view.measure_tap()


## Lecture seule, pour les outils de vérification.
func get_flow() -> BoosterFlow:
	return _flow


func get_inventory() -> BoosterInventory:
	return _inventory


## Rejoue le niveau courant, sans passer par l'écran de fin (outils de vérification).
func reload_current_level() -> void:
	_start_level(_level_number)


## Un même téléphone passe de main en main : nouveau numéro, retour au premier niveau.
func _on_new_tester_requested() -> void:
	var tester: int = Services.analytics.tester + 1
	Services.save.set_int(TESTER_KEY, tester)
	Services.analytics.tester = tester
	_next_level_number = LevelProgress.reset(Services.save)
	if _inventory != null:
		_inventory.reset()
	_was_lost = false
	_start_level(_next_level_number)


## L'écran caché fait jouer le même téléphone avec ou sans boosters : le niveau repart.
func _on_boosters_toggled() -> void:
	Features.force_boosters(Services.save, not Features.boosters_enabled(Services.save))
	_apply_boosters_flag()
	_was_lost = false
	_start_level(_level_number)


func _apply_boosters_flag() -> void:
	if _flow != null:
		_flow.queue_free()
		_flow = null
	_inventory = null
	if Features.boosters_enabled(Services.save):
		_inventory = BoosterInventory.new(BoosterConfig.load_default(), Services.save, Services.wallet, Services.ads)
		_flow = BoosterFlow.new()
		add_child(_flow)
		_flow.setup(_inventory, hud)
		_flow.booster_used.connect(_on_booster_used)
		_flow.level_blocked.connect(_on_level_blocked)
		_flow.restart_requested.connect(_on_restart_requested)
	_on_balance_changed(Services.wallet.balance())


func _on_balance_changed(balance: int) -> void:
	hud.set_coins(balance if _inventory != null else -1)


func _on_booster_used(kind: BoosterAccess.Kind) -> void:
	_telemetry.booster_used(BoosterConfig.KIND_KEYS[kind])


## « Recommencer » depuis la pop-up : pas d'écran de défaite en plus.
func _on_restart_requested() -> void:
	_restart_after_loss = true


func _on_level_blocked() -> void:
	_telemetry.level_blocked(view.occupied_slots(), view.head_dest())
