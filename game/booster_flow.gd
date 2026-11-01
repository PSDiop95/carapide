class_name BoosterFlow
extends Node
## Enchaînement des boosters côté présentation : barre, visée, paiement, pop-up, tutoriel.
## N'écrit jamais l'état : passe par LevelView, qui rejoue les événements du core.

signal booster_used(kind: BoosterAccess.Kind)
signal level_blocked

const VEHICLE_TARGET_SIZE: Vector2 = Vector2(150.0, 150.0)
const MEASURE_EFFECT_PERIOD: int = 6

var bar: BoosterBar = BoosterBar.new()
var popup: BlockedPopup = BlockedPopup.new()
var tutorial: TutorialOverlay = TutorialOverlay.new()

var _inventory: BoosterInventory
var _hud: Hud
var _view: LevelView = null
var _busy: bool = false
var _targeting: bool = false
var _advice: BoosterAdvice = null
var _tutorial_kind: BoosterAccess.Kind = BoosterAccess.Kind.COXEUR
var _tutorial_vehicle: int = BoardLogic.NO_VEHICLE
var _pending_mix: PackedStringArray = PackedStringArray()
var _measure_steps: int = 0


func setup(inventory: BoosterInventory, hud: Hud) -> void:
	_inventory = inventory
	_hud = hud
	bar.setup(inventory)
	hud.booster_layer.add_child(bar)
	hud.booster_layer.add_child(popup)
	hud.booster_layer.add_child(tutorial)
	bar.booster_pressed.connect(_on_bar_pressed)
	popup.advice_pressed.connect(_on_advice_pressed)
	popup.abandon_pressed.connect(_on_abandon_pressed)
	tutorial.target_pressed.connect(_on_tutorial_target_pressed)


func _exit_tree() -> void:
	bar.queue_free()
	popup.queue_free()
	tutorial.queue_free()


func attach(view: LevelView) -> void:
	_view = view
	_busy = false
	_advice = null
	_set_targeting(false)
	popup.hide()
	tutorial.close()
	bar.refresh()
	bar.clear_hint()
	view.tap_guard = _hud.covers_point
	view.rescue_needed.connect(_on_rescue_needed)
	view.vehicle_targeted.connect(_on_vehicle_targeted)
	view.replay_finished.connect(_try_start_tutorial)
	_start_tutorial_after_layout.call_deferred(view)


func _on_bar_pressed(kind: BoosterAccess.Kind) -> void:
	if _busy or _view == null:
		return
	match kind:
		BoosterAccess.Kind.APPRENTI:
			_set_targeting(false)
			if _view.can_use_apprenti():
				_use(kind, BoardLogic.NO_VEHICLE)
			else:
				bar.show_hint(tr("APPRENTI_USELESS_HINT"))
		BoosterAccess.Kind.DIOULE:
			_set_targeting(false)
			_try_dioule()
		_:
			_set_targeting(not _targeting)


## Le mélange est cherché avant le paiement : sans mélange soluble, rien n'est consommé.
func _try_dioule() -> void:
	_pending_mix = _view.compute_dioule(_inventory.config.dioule_max_nodes)
	if _pending_mix.is_empty():
		bar.show_hint(tr("DIOULE_CALM_HINT"))
	else:
		_use(BoosterAccess.Kind.DIOULE, BoardLogic.NO_VEHICLE)


func _set_targeting(active: bool) -> void:
	_targeting = active
	bar.set_active(BoosterAccess.Kind.COXEUR, active)
	if _view != null:
		_view.targeting = active
	if active:
		bar.show_hint(tr("COXEUR_TARGET_HINT"), true)
	else:
		bar.clear_hint()


func _on_vehicle_targeted(vehicle_id: int) -> void:
	_set_targeting(false)
	if _view.can_use_coxeur(vehicle_id):
		_use(BoosterAccess.Kind.COXEUR, vehicle_id)
	else:
		bar.show_hint(tr("COXEUR_BUSY_HINT"))


## Paie d'abord : le core réévalue BLOCKED/LOST avec ce qu'il reste au joueur.
func _use(kind: BoosterAccess.Kind, vehicle_id: int) -> void:
	_busy = true
	var view: LevelView = _view
	view.input_enabled = false
	var is_ad: bool = _inventory.offer(kind) == BoosterInventory.Offer.AD
	if is_ad:
		_hud.show_ad_curtain()
	var paid: bool = await _inventory.pay(kind)
	_hud.hide_ad_curtain()
	_busy = false
	bar.refresh()
	if not is_instance_valid(view):
		return
	view.input_enabled = true
	if not paid:
		if view.is_blocked():
			_open_popup()
		return
	_inventory.mark_tutorial_done(kind)
	booster_used.emit(kind)
	match kind:
		BoosterAccess.Kind.APPRENTI:
			view.play_apprenti()
		BoosterAccess.Kind.DIOULE:
			view.play_dioule(_pending_mix)
		_:
			view.play_coxeur(vehicle_id)


func _on_rescue_needed() -> void:
	level_blocked.emit()
	_open_popup()


func _open_popup() -> void:
	_set_targeting(false)
	_view.input_enabled = false
	_advice = _view.advise(_inventory)
	var text: String = ""
	if _advice != null:
		var offer: String = BoosterBar.offer_text(_inventory, _advice.kind)
		text = tr("BOOSTER_OFFER") % [tr(BoosterBar.NAME_KEYS[_advice.kind]), offer]
	popup.open(text)


func _on_advice_pressed() -> void:
	popup.hide()
	_view.input_enabled = true
	_use(_advice.kind, _advice.vehicle_id)


## Mesure : joue l'effet périodiquement, sans paiement. Faux si ce pas reste un tap normal.
func measure_effect(effect: String) -> bool:
	_measure_steps += 1
	if effect != "dioule" or _measure_steps % MEASURE_EFFECT_PERIOD != 0 or not _view.can_use_dioule():
		return false
	var start: int = Time.get_ticks_usec()
	var mix: PackedStringArray = _view.compute_dioule(_inventory.config.dioule_max_nodes)
	PerfProbe.record_effect_ms(float(Time.get_ticks_usec() - start) * 0.001)
	if mix.is_empty():
		return false
	_view.play_dioule(mix)
	return true


## Mesure : sort de la pop-up sans passer par le toucher.
func measure_resolve_popup(_effect: String) -> void:
	_on_abandon_pressed()


func _on_abandon_pressed() -> void:
	popup.hide()
	_view.input_enabled = true
	_view.play_abandon()


func _start_tutorial_after_layout(view: LevelView) -> void:
	await get_tree().process_frame
	if view == _view:
		_try_start_tutorial()


## Une fois par booster, au premier moment où il sert vraiment.
func _try_start_tutorial() -> void:
	if _busy or tutorial.visible or popup.visible or _view == null or not _view.is_playing():
		return
	if _inventory.needs_tutorial(BoosterAccess.Kind.COXEUR):
		_tutorial_vehicle = _view.tutorial_vehicle()
		if _view.can_use_coxeur(_tutorial_vehicle):
			_open_tutorial(BoosterAccess.Kind.COXEUR, "TUTORIAL_COXEUR_BAR")
	elif _inventory.needs_tutorial(BoosterAccess.Kind.APPRENTI) and _view.can_use_apprenti():
		_open_tutorial(BoosterAccess.Kind.APPRENTI, "TUTORIAL_APPRENTI_BAR")
	elif _inventory.needs_tutorial(BoosterAccess.Kind.DIOULE) and _view.can_use_dioule():
		_open_tutorial(BoosterAccess.Kind.DIOULE, "TUTORIAL_DIOULE_BAR")


func _open_tutorial(kind: BoosterAccess.Kind, hint_key: String) -> void:
	_tutorial_kind = kind
	_set_targeting(false)
	_view.input_enabled = false
	tutorial.point_at(bar.button_rect(kind), tr(hint_key))


func _on_tutorial_target_pressed() -> void:
	if _tutorial_kind == BoosterAccess.Kind.COXEUR and tutorial.target_rect == bar.button_rect(_tutorial_kind):
		tutorial.point_at(_vehicle_rect(_tutorial_vehicle), tr("TUTORIAL_COXEUR_VEHICLE"))
		return
	tutorial.close()
	_view.input_enabled = true
	if _tutorial_kind == BoosterAccess.Kind.DIOULE:
		_try_dioule()
	else:
		_use(_tutorial_kind, _tutorial_vehicle)


func _vehicle_rect(vehicle_id: int) -> Rect2:
	var center: Vector2 = _view.vehicle_screen_position(_view.level_vehicle(vehicle_id))
	return Rect2(center - VEHICLE_TARGET_SIZE * 0.5, VEHICLE_TARGET_SIZE)
