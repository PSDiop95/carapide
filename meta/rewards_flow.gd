class_name RewardsFlow
extends Node
## Station et Roue côté présentation : ouvre les écrans, passe la pub, rejoue le résultat.
## Les règles vivent dans StationRewards et WheelRewards.

const REFRESH_SECONDS: float = 1.0
const MEASURE_SPINS_WINS: int = 1000

var station: StationRewards
var wheel: WheelRewards
var station_panel: StationPanel = StationPanel.new()
var wheel_panel: WheelPanel = WheelPanel.new()
## Heure système, remplaçable par les tests.
var now_provider: Callable = _system_now

var _hub: HubScreen
var _ads: AdsService
var _save: SaveService
var _clock: SafeClock
var _refresh_left: float = 0.0
var _measure_phase: int = 0


func setup(hub: HubScreen, config: PresentationConfig, inventory: BoosterInventory, ads: AdsService, save: SaveService, wallet: WalletService, analytics: AnalyticsService) -> void:
	_hub = hub
	_ads = ads
	_save = save
	_clock = SafeClock.new(save)
	var economy: EconomyConfig = inventory.config.economy
	station = StationRewards.new(economy, save, wallet, _clock)
	wheel = WheelRewards.new(economy, save, wallet, inventory, analytics, _clock)
	wheel_panel.setup(config, _cell_texts())
	hub.add_child(station_panel)
	hub.add_child(wheel_panel)
	station_panel.build_tiers(economy.station_tiers)
	station_panel.hide()
	wheel_panel.hide()
	hub.station_pressed.connect(_on_station_pressed)
	hub.wheel_pressed.connect(_on_wheel_pressed)
	station_panel.claim_pressed.connect(_on_claim_pressed)
	wheel_panel.spin_pressed.connect(_on_spin_pressed)
	wheel_panel.spin_finished.connect(refresh)
	refresh()


## Le hub survit au flux quand on bascule les boosters ; sinon les écrans partent avec lui.
func _exit_tree() -> void:
	if not is_instance_valid(_hub) or _hub.is_queued_for_deletion():
		return
	station_panel.queue_free()
	wheel_panel.queue_free()
	_hub.station_pressed.disconnect(_on_station_pressed)
	_hub.wheel_pressed.disconnect(_on_wheel_pressed)


## La recharge avance même écran ouvert : relu une fois par seconde, jamais à chaque image.
func _process(delta: float) -> void:
	if not _hub.visible:
		return
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = REFRESH_SECONDS
		refresh()


## Point rouge du hub et contenu des écrans ouverts.
func refresh() -> void:
	var now: int = _now()
	_hub.set_station_ready(station.has_available(now, _ads.is_rewarded_available()))
	if station_panel.visible and not station_panel.close_button.disabled:
		_refresh_station(now)
	if wheel_panel.visible and not wheel_panel.is_spinning():
		_refresh_wheel(now)


func reset() -> void:
	station.reset()
	wheel.reset()


func _refresh_station(now: int) -> void:
	var tier: int = station.next_tier(now)
	var text: String = tr("STATION_DONE")
	if tier < station.tier_count():
		text = tr("STATION_CLAIM_AD" if station.needs_ad(tier) else "STATION_CLAIM") % station.coins(tier)
	var enabled: bool = station.has_available(now, _ads.is_rewarded_available())
	station_panel.show_state(tier, text, enabled, station.seconds_until_recharge(now))


func _refresh_wheel(now: int) -> void:
	wheel_panel.show_progress(wheel.progress(), wheel.progress_goal())
	var ad_left: int = wheel.ad_spins_left(now)
	if wheel.free_spins() > 0:
		wheel_panel.show_spin_action(tr("WHEEL_SPIN_FREE"), true)
	elif ad_left > 0 and _ads.is_rewarded_available():
		wheel_panel.show_spin_action(tr("WHEEL_SPIN_AD") % ad_left, true)
	else:
		wheel_panel.show_spin_action(tr("WHEEL_NO_SPIN"), false)


func _on_station_pressed() -> void:
	station_panel.show()
	refresh()


func _on_wheel_pressed() -> void:
	wheel_panel.result_label.text = ""
	wheel_panel.show()
	refresh()


func _on_claim_pressed() -> void:
	var tier: int = station.next_tier(_now())
	if station.needs_ad(tier):
		station_panel.set_waiting(true)
		var watched: bool = await _ads.show_rewarded()
		station_panel.set_waiting(false)
		if not watched:
			refresh()
			return
	station.claim(_now())
	refresh()


func _on_spin_pressed() -> void:
	var by_ad: bool = wheel.free_spins() <= 0
	if by_ad:
		wheel_panel.set_waiting(true)
		var watched: bool = await _ads.show_rewarded()
		wheel_panel.set_waiting(false)
		if not watched:
			refresh()
			return
	var index: int = wheel.spin(_now(), by_ad)
	if index != WheelRewards.NO_SPIN:
		wheel_panel.play_spin(index, _cell_text(wheel.cells()[index]))


func _cell_texts() -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for cell: WheelCell in wheel.cells():
		texts.append(_cell_text(cell))
	return texts


func _cell_text(cell: WheelCell) -> String:
	if cell.is_coins():
		return tr("VICTORY_COINS") % cell.amount
	return tr("WHEEL_BOOSTER") % [tr("BOOSTER_%s" % cell.reward.to_upper()), cell.amount]


func prepare_for_measure() -> void:
	_save.set_int(WheelRewards.WINS_KEY, MEASURE_SPINS_WINS)


## Mesure : ramasse à la Station, puis fait tourner la Roue. Vrai tant que les écrans sont occupés.
func measure_step() -> bool:
	_measure_phase += 1
	match _measure_phase:
		1:
			_on_station_pressed()
			station.reset()
			_on_claim_pressed()
		2:
			station_panel.hide()
			_on_wheel_pressed()
			_on_spin_pressed()
		3, 4, 5:
			pass
		_:
			wheel_panel.hide()
			_measure_phase = 0
			return false
	return true


func _now() -> int:
	var now: int = now_provider.call()
	return now


func _system_now() -> int:
	return int(Time.get_unix_time_from_system())
