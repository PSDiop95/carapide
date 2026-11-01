extends GutTest
## Station (paliers, recharge, retour d'horloge), Roue (tours, tirage, plafonds), plafond de pubs.

const T0: int = 1_000_000_000
const FOUR_HOURS: int = 4 * 3600
const ONE_DAY: int = 86400
const DRAW_RUNS: int = 6000
const WEIGHT_MARGIN: float = 0.025

var _economy: EconomyConfig = EconomyConfig.load_default()
var _save: SaveService
var _wallet: WalletService
var _analytics: AnalyticsService


func before_all() -> void:
	UiStrings.register()


func before_each() -> void:
	_save = SaveService.new()
	_wallet = WalletService.new()
	_analytics = AnalyticsService.new()
	_wallet.analytics = _analytics


func _station() -> StationRewards:
	return StationRewards.new(_economy, _save, _wallet, SafeClock.new(_save))


func _inventory() -> BoosterInventory:
	return BoosterInventory.new(BoosterConfig.load_default(), _save, _wallet, AdsService.new())


func _wheel() -> WheelRewards:
	return WheelRewards.new(_economy, _save, _wallet, _inventory(), _analytics, SafeClock.new(_save))


func _ads(cap: int, now: int) -> CappedAdsService:
	var ads: CappedAdsService = CappedAdsService.new(_save, cap)
	ads.delay_seconds = 0.0
	ads.now_provider = func() -> int: return now
	return ads


func test_station_gives_tiers_one_after_the_other() -> void:
	var station: StationRewards = _station()
	assert_false(station.needs_ad(station.next_tier(T0)), "Le premier palier est gratuit")
	var gains: Array[int] = []
	for _index: int in 4:
		gains.append(station.claim(T0))
	assert_eq(gains, [15, 20, 50, 100] as Array[int])
	assert_eq(_wallet.balance(), 185)
	assert_true(station.is_exhausted(T0))
	assert_eq(station.claim(T0), 0, "Rien de plus avant la recharge")
	assert_eq(_wallet.balance(), 185)


func test_station_tiers_after_the_first_need_an_ad() -> void:
	var station: StationRewards = _station()
	station.claim(T0)
	assert_true(station.needs_ad(station.next_tier(T0)))
	assert_false(station.has_available(T0, false), "Sans pub, plus rien à ramasser")
	assert_true(station.has_available(T0, true))


func test_station_recharges_after_four_hours() -> void:
	var station: StationRewards = _station()
	station.claim(T0)
	assert_eq(station.seconds_until_recharge(T0 + 3600), FOUR_HOURS - 3600)
	assert_eq(station.next_tier(T0 + FOUR_HOURS - 1), 1)
	assert_eq(station.next_tier(T0 + FOUR_HOURS), 0)
	assert_eq(station.claim(T0 + FOUR_HOURS), 15)


func test_turning_the_clock_back_never_shortens_the_recharge() -> void:
	var station: StationRewards = _station()
	station.claim(T0)
	assert_eq(station.seconds_until_recharge(T0 - ONE_DAY), FOUR_HOURS)
	assert_eq(station.next_tier(T0 - ONE_DAY), 1)


func test_clock_moved_forward_then_back_keeps_the_highest_time() -> void:
	var station: StationRewards = _station()
	station.claim(T0)
	station.claim(T0 + FOUR_HOURS)
	assert_eq(station.seconds_until_recharge(T0), FOUR_HOURS, "La recharge repart de l'heure la plus haute")
	var clock: SafeClock = SafeClock.new(_save)
	assert_eq(clock.read(T0), T0 + FOUR_HOURS)


func test_station_state_survives_a_relaunch() -> void:
	_station().claim(T0)
	assert_eq(_station().next_tier(T0 + 10), 1)


func test_station_gain_is_logged() -> void:
	_station().claim(T0)
	assert_eq(_analytics.logged_params[-1], {"source": "station", "amount": 15, "balance": 15})


func test_a_free_spin_every_ten_wins_with_visible_progress() -> void:
	var wheel: WheelRewards = _wheel()
	for _win: int in 9:
		wheel.record_win()
	assert_eq(wheel.progress(), 9)
	assert_eq(wheel.free_spins(), 0)
	assert_eq(wheel.spin(T0, false), WheelRewards.NO_SPIN)
	wheel.record_win()
	assert_eq(wheel.free_spins(), 1)
	assert_eq(wheel.progress(), 10)
	assert_ne(wheel.spin(T0, false), WheelRewards.NO_SPIN)
	assert_eq(wheel.free_spins(), 0)
	assert_eq(wheel.progress(), 0)


func test_ad_spins_stop_at_three_per_day_and_come_back() -> void:
	var wheel: WheelRewards = _wheel()
	for _spin: int in 3:
		assert_ne(wheel.spin(T0, true), WheelRewards.NO_SPIN)
	assert_eq(wheel.ad_spins_left(T0), 0)
	assert_eq(wheel.spin(T0, true), WheelRewards.NO_SPIN)
	assert_eq(wheel.ad_spins_left(T0 + ONE_DAY), 3)
	assert_ne(wheel.spin(T0 + ONE_DAY, true), WheelRewards.NO_SPIN)
	assert_eq(wheel.ad_spins_left(T0 + ONE_DAY), 2)


func test_turning_the_clock_back_gives_no_extra_ad_spin() -> void:
	var wheel: WheelRewards = _wheel()
	for _spin: int in 3:
		wheel.spin(T0, true)
	assert_eq(wheel.ad_spins_left(T0 - ONE_DAY), 0)


func test_draw_is_deterministic_for_a_seed() -> void:
	for seed_value: int in 50:
		assert_eq(WheelLogic.draw(_economy.wheel_cells, seed_value), WheelLogic.draw(_economy.wheel_cells, seed_value))


func test_same_save_gives_the_same_spins() -> void:
	var first: Array[int] = _spins_from_fresh_save()
	var second: Array[int] = _spins_from_fresh_save()
	assert_eq(first, second)


func _spins_from_fresh_save() -> Array[int]:
	before_each()
	var wheel: WheelRewards = _wheel()
	var spins: Array[int] = []
	for _spin: int in 3:
		spins.append(wheel.spin(T0, true))
	return spins


func test_draws_follow_the_configured_weights() -> void:
	var counts: Array[int] = []
	counts.resize(_economy.wheel_cells.size())
	var total: int = 0
	for cell: WheelCell in _economy.wheel_cells:
		total += cell.weight
	for seed_value: int in DRAW_RUNS:
		counts[WheelLogic.draw(_economy.wheel_cells, hash([7, seed_value]))] += 1
	for index: int in counts.size():
		var expected: float = float(_economy.wheel_cells[index].weight) / float(total)
		assert_almost_eq(float(counts[index]) / float(DRAW_RUNS), expected, WEIGHT_MARGIN)


func test_coin_cell_credits_the_wallet_booster_cell_the_stock() -> void:
	var wheel: WheelRewards = _wheel()
	var inventory: BoosterInventory = _inventory()
	var coins: WheelCell = _economy.wheel_cells[0]
	var booster: WheelCell = _economy.wheel_cells[3]
	wheel._apply(coins)
	assert_eq(_wallet.balance(), coins.amount)
	wheel._apply(booster)
	assert_eq(inventory.stock(BoosterAccess.Kind.COXEUR), booster.amount)


func test_every_spin_is_logged_with_its_result() -> void:
	var wheel: WheelRewards = _wheel()
	var index: int = wheel.spin(T0, true)
	var spin_index: int = _analytics.logged_events.find("wheel_spin")
	assert_gt(spin_index, -1)
	var params: Dictionary = _analytics.logged_params[spin_index]
	var reward: String = params["reward"]
	var source: String = params["source"]
	assert_eq(reward, _economy.wheel_cells[index].reward)
	assert_eq(source, WheelRewards.SOURCE_AD)


func test_ads_stop_at_the_daily_cap_and_come_back() -> void:
	var ads: CappedAdsService = _ads(2, T0)
	assert_true(await ads.show_rewarded())
	assert_true(await ads.show_rewarded())
	assert_false(ads.is_rewarded_available())
	assert_false(await ads.show_rewarded())
	assert_eq(ads.shown, 2)
	var next_day: CappedAdsService = _ads(2, T0 + ONE_DAY)
	assert_true(next_day.is_rewarded_available())


func test_game_ads_use_the_configured_cap() -> void:
	assert_true(Services.ads is CappedAdsService)


func test_dial_lands_on_the_drawn_cell_after_full_turns() -> void:
	var dial: WheelDial = WheelDial.new()
	dial.setup(PackedStringArray(["a", "b", "c", "d", "e", "f"]))
	add_child_autofree(dial)
	for index: int in 6:
		var target: float = dial.target_rotation(index, 1.3, 5)
		assert_eq(dial.index_at_pointer(target), index)
		assert_gt(target, 1.3 + TAU * 4.5)


func _flow(now: Array[int]) -> RewardsFlow:
	var hub: HubScreen = HubScreen.new()
	hub.configure(PresentationConfig.load_default(), _save)
	add_child_autofree(hub)
	var flow: RewardsFlow = RewardsFlow.new()
	flow.now_provider = func() -> int: return now[0]
	add_child_autofree(flow)
	var ads: AdsService = AdsService.new()
	ads.delay_seconds = 0.0
	flow.setup(hub, PresentationConfig.load_default(), _inventory(), ads, _save, _wallet, _analytics)
	return flow


func test_hub_dot_follows_the_station() -> void:
	var now: Array[int] = [T0]
	var flow: RewardsFlow = _flow(now)
	assert_true(flow._hub.station_dot.visible)
	for _tier: int in 4:
		flow.station.claim(now[0])
	flow.refresh()
	assert_false(flow._hub.station_dot.visible, "Tout est pris")
	now[0] += FOUR_HOURS
	flow.refresh()
	assert_true(flow._hub.station_dot.visible, "Recharge finie")


func test_panels_cover_the_whole_screen() -> void:
	var flow: RewardsFlow = _flow([T0] as Array[int])
	var screen: Vector2 = flow._hub.settings_panel.get_viewport_rect().size
	assert_eq(flow.station_panel.size, screen)
	assert_eq(flow.wheel_panel.size, screen)
	assert_eq(flow._hub.settings_panel.size, screen)


func test_station_screen_claims_free_tier_then_ad_tier() -> void:
	var now: Array[int] = [T0]
	var flow: RewardsFlow = _flow(now)
	flow._hub.station_button.pressed.emit()
	assert_true(flow.station_panel.visible)
	assert_eq(flow.station_panel.claim_button.text, tr("STATION_CLAIM") % 15)
	flow.station_panel.claim_button.pressed.emit()
	assert_eq(_wallet.balance(), 15)
	assert_eq(flow.station_panel.claim_button.text, tr("STATION_CLAIM_AD") % 20)
	flow.station_panel.claim_button.pressed.emit()
	await wait_seconds(0.1)
	assert_eq(_wallet.balance(), 35)


func test_draw_and_gain_happen_before_the_animation_ends() -> void:
	var now: Array[int] = [T0]
	var flow: RewardsFlow = _flow(now)
	for _win: int in 10:
		flow.wheel.record_win()
	flow._hub.wheel_button.pressed.emit()
	flow.wheel_panel.spin_button.pressed.emit()
	assert_true(flow.wheel_panel.is_spinning())
	assert_gt(_analytics.logged_events.find("wheel_spin"), -1, "Tirage journalisé avant la fin de l'animation")
	assert_eq(flow.wheel.free_spins(), 0)
