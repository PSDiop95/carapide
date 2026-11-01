extends GutTest
## Configuration, journal du porte-monnaie, écran de victoire, économie simulée sans pub.
## Le simulateur énumère tous les tirages de la Roue : le résultat est exact, sans hasard.

const LEVELS: int = 30
const COXEUR_PERIOD: int = 5
## Hypothèse : une Station gratuite ramassée tous les 5 niveaux (la recharge dure 4 h).
const STATION_PERIOD: int = 5
const GARAGE_KEY: String = "garage"
const COXEUR_KEY: String = "coxeur"
const JACKPOT: int = 500
## Seuils du second test : joueur qui achète ses Coxeur, joueur qui n'achète rien.
const BUYER_MAX_PROBABILITY: float = 0.02
const HOARDER_MAX_PROBABILITY: float = 0.2

var _economy: EconomyConfig = EconomyConfig.load_default()


func before_all() -> void:
	UiStrings.register()


func _free_spins() -> int:
	return int(float(LEVELS) / float(_economy.wheel_wins_per_free_spin))


## Pic de solde sur 30 niveaux, ou -1 si un Coxeur prévu n'a pas pu être acheté.
func _peak(spins: Array[WheelCell], buys: bool, with_station: bool) -> int:
	var balance: int = 0
	var peak: int = 0
	var spin: int = 0
	var coxeur: int = _economy.booster_price(COXEUR_KEY)
	for level: int in range(1, LEVELS + 1):
		balance += _economy.victory_coins
		if with_station and level % STATION_PERIOD == 0:
			balance += _economy.station_tiers[0]
		if level % _economy.wheel_wins_per_free_spin == 0:
			if spins[spin].is_coins():
				balance += spins[spin].amount
			spin += 1
		peak = maxi(peak, balance)
		if buys and level % COXEUR_PERIOD == 0:
			if balance < coxeur:
				return -1
			balance -= coxeur
	return peak


## Toutes les suites de tirages de la Roue sur ces cases.
func _all_spins(cells: Array[WheelCell]) -> Array[Array]:
	var empty: Array[WheelCell] = []
	var sequences: Array[Array] = [empty]
	for _spin: int in _free_spins():
		var longer: Array[Array] = []
		for sequence: Array in sequences:
			for cell: WheelCell in cells:
				var next: Array[WheelCell] = []
				next.assign(sequence)
				next.append(cell)
				longer.append(next)
		sequences = longer
	return sequences


func _as_cells(sequence: Array) -> Array[WheelCell]:
	var cells: Array[WheelCell] = []
	cells.assign(sequence)
	return cells


func _without_jackpot() -> Array[WheelCell]:
	var cells: Array[WheelCell] = []
	for cell: WheelCell in _economy.wheel_cells:
		if not (cell.is_coins() and cell.amount == JACKPOT):
			cells.append(cell)
	return cells


## Probabilité exacte que le solde atteigne le prix du Garage, Roue complète.
func _garage_probability(buys: bool) -> float:
	var total: float = 0.0
	for cell: WheelCell in _economy.wheel_cells:
		total += float(cell.weight)
	var garage: int = _economy.booster_price(GARAGE_KEY)
	var probability: float = 0.0
	for sequence: Array in _all_spins(_economy.wheel_cells):
		var spins: Array[WheelCell] = _as_cells(sequence)
		if _peak(spins, buys, true) >= garage:
			var chance: float = 1.0
			for cell: WheelCell in spins:
				chance *= float(cell.weight) / total
			probability += chance
	return probability


func test_economy_file_holds_the_prompt_values() -> void:
	assert_eq(_economy.victory_coins, 20)
	assert_eq(_economy.victory_ad_multiplier, 2)
	assert_eq(_economy.booster_price(GARAGE_KEY), 900)
	assert_eq(_economy.station_tiers, PackedInt32Array([15, 20, 50, 100]))
	assert_eq(_economy.station_recharge_hours, 4)
	assert_eq(_economy.wheel_cells.size(), 6)
	assert_eq(_economy.wheel_ad_spins_per_day, 3)
	assert_eq(_economy.rewarded_ads_per_day, 25)


func test_booster_config_reads_prices_from_economy() -> void:
	var config: BoosterConfig = BoosterConfig.load_default()
	assert_eq(config.price(BoosterAccess.Kind.COXEUR), _economy.booster_price(COXEUR_KEY))
	assert_eq(config.garage_max_uses(), _economy.garage_max_uses)


func test_wallet_logs_every_gain_and_spend_with_source_and_balance() -> void:
	var wallet: WalletService = WalletService.new()
	wallet.analytics = AnalyticsService.new()
	wallet.add(100, WalletService.SOURCE_VICTORY)
	assert_true(wallet.try_spend(80, "booster_coxeur"))
	assert_eq(wallet.analytics.logged_events, ["coins_earned", "coins_spent"] as Array[String])
	assert_eq(wallet.analytics.logged_params[0], {"source": "victory", "amount": 100, "balance": 100})
	assert_eq(wallet.analytics.logged_params[1], {"source": "booster_coxeur", "amount": 80, "balance": 20})


func test_refused_spend_logs_nothing() -> void:
	var wallet: WalletService = WalletService.new()
	wallet.analytics = AnalyticsService.new()
	assert_false(wallet.try_spend(1, "booster_coxeur"))
	assert_eq(wallet.analytics.logged_events.size(), 0)


func test_game_wallet_reports_to_analytics() -> void:
	assert_same(Services.wallet.analytics, Services.analytics)


func test_booster_purchase_is_logged_with_its_source() -> void:
	var wallet: WalletService = WalletService.new()
	wallet.analytics = AnalyticsService.new()
	wallet.add(200, WalletService.SOURCE_VICTORY)
	var save: SaveService = SaveService.new()
	var inventory: BoosterInventory = BoosterInventory.new(BoosterConfig.load_default(), save, wallet, AdsService.new())
	inventory.enter_level(3)
	save.set_int(BoosterInventory.STOCK_KEY % COXEUR_KEY, 0)
	assert_true(await inventory.pay(BoosterAccess.Kind.COXEUR))
	var source: String = wallet.analytics.logged_params[-1]["source"]
	assert_eq(source, "booster_coxeur")


func test_victories_alone_buy_a_coxeur_every_five_levels() -> void:
	var no_coins: WheelCell = WheelCell.new()
	no_coins.reward = COXEUR_KEY
	var spins: Array[WheelCell] = []
	for _spin: int in _free_spins():
		spins.append(no_coins)
	assert_gt(_peak(spins, true, false), 0, "Coxeur inabordable avec les seules victoires")


## Cadrage décidé : bloquant hors case 500, sur le joueur du test, celui qui achète ses Coxeur.
func test_no_garage_without_ad_outside_the_jackpot() -> void:
	var garage: int = _economy.booster_price(GARAGE_KEY)
	var worst: int = 0
	for sequence: Array in _all_spins(_without_jackpot()):
		var peak: int = _peak(_as_cells(sequence), true, true)
		assert_gt(peak, 0, "Coxeur inabordable")
		worst = maxi(worst, peak)
	print("Économie : pic de solde hors jackpot, Coxeur achetés, pire tirage : %d (Garage %d)" % [worst, garage])
	assert_lt(worst, garage)


func test_probability_of_a_garage_with_the_jackpot_stays_bounded() -> void:
	var buyer: float = _garage_probability(true)
	var hoarder: float = _garage_probability(false)
	print("Économie : Garage sans pub au niveau 30, jackpot compris : acheteur %.2f %%, sans achat %.2f %%" % [buyer * 100.0, hoarder * 100.0])
	assert_lt(buyer, BUYER_MAX_PROBABILITY)
	assert_lt(hoarder, HOARDER_MAX_PROBABILITY)


func _hud() -> Hud:
	var hud: Hud = Hud.new()
	hud.configure(PresentationConfig.load_default())
	add_child_autofree(hud)
	return hud


func test_end_screen_hides_the_play_interface() -> void:
	var hud: Hud = _hud()
	hud.show_victory("WON_TITLE", "NEXT_BUTTON")
	assert_false(hud.booster_layer.visible)
	hud.hide_result()
	assert_true(hud.booster_layer.visible)


func test_apprentice_cheers_on_victory_only() -> void:
	var hud: Hud = _hud()
	hud.show_victory("WON_TITLE", "NEXT_BUTTON")
	assert_true(hud.apprentice.visible)
	hud.apprentice._process(0.2)
	assert_gt(hud.apprentice.hop_height(), 0.0)
	hud.hide_result()
	hud.show_result("LOST_TITLE", "RETRY_BUTTON")
	assert_false(hud.apprentice.visible)
