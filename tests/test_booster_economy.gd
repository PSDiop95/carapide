extends GutTest
## Porte-monnaie, publicité mock, inventaire, persistance, limite du solveur.

const SAVE_PATH: String = "user://test_booster_economy.json"


func before_each() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func after_all() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func _ads(available: bool = true, succeeds: bool = true) -> AdsService:
	var ads: AdsService = AdsService.new()
	ads.available = available
	ads.succeeds = succeeds
	ads.delay_seconds = 0.01
	return ads


func _inventory(save: SaveService, wallet: WalletService, ads: AdsService) -> BoosterInventory:
	return BoosterInventory.new(BoosterConfig.load_default(), save, wallet, ads)


func test_config_matches_the_prompt() -> void:
	var config: BoosterConfig = BoosterConfig.load_default()
	assert_eq(config.price(BoosterAccess.Kind.COXEUR), 80)
	assert_eq(config.unlock_level(BoosterAccess.Kind.COXEUR), 3)
	assert_eq(config.price(BoosterAccess.Kind.APPRENTI), 120)
	assert_eq(config.unlock_level(BoosterAccess.Kind.APPRENTI), 8)
	assert_eq(config.gift(BoosterAccess.Kind.COXEUR), 3)
	assert_eq(config.economy.victory_coins, 20)
	assert_eq(config.economy.victory_ad_multiplier, 2)


func test_wallet_refuses_overdraft_without_debit() -> void:
	var wallet: WalletService = WalletService.new()
	wallet.add(50, "test")
	assert_false(wallet.try_spend(80, "test"))
	assert_eq(wallet.balance(), 50)
	assert_true(wallet.try_spend(50, "test"))
	assert_eq(wallet.balance(), 0)


func test_coins_and_stock_survive_a_relaunch() -> void:
	var save: FileSaveService = FileSaveService.new(SAVE_PATH)
	var wallet: SavedWalletService = SavedWalletService.new(save)
	wallet.add(140, "test")
	var inventory: BoosterInventory = _inventory(save, wallet, _ads())
	inventory.enter_level(3)
	await inventory.pay(BoosterAccess.Kind.COXEUR)
	var reopened: FileSaveService = FileSaveService.new(SAVE_PATH)
	var wallet_after: SavedWalletService = SavedWalletService.new(reopened)
	assert_eq(wallet_after.balance(), 140)
	var inventory_after: BoosterInventory = _inventory(reopened, wallet_after, _ads())
	inventory_after.enter_level(3)
	assert_eq(inventory_after.stock(BoosterAccess.Kind.COXEUR), 2, "Pas de second cadeau après relance")


func test_unlock_gift_is_given_once_at_unlock_level() -> void:
	var inventory: BoosterInventory = _inventory(SaveService.new(), WalletService.new(), _ads())
	inventory.enter_level(2)
	assert_eq(inventory.offer(BoosterAccess.Kind.COXEUR), BoosterInventory.Offer.LOCKED)
	assert_eq(inventory.stock(BoosterAccess.Kind.COXEUR), 0)
	inventory.enter_level(3)
	assert_eq(inventory.stock(BoosterAccess.Kind.COXEUR), 3)
	inventory.enter_level(4)
	assert_eq(inventory.stock(BoosterAccess.Kind.COXEUR), 3)
	assert_eq(inventory.offer(BoosterAccess.Kind.APPRENTI), BoosterInventory.Offer.LOCKED)


func test_payment_order_is_stock_then_coins_then_ad() -> void:
	var wallet: WalletService = WalletService.new()
	var ads: AdsService = _ads()
	var inventory: BoosterInventory = _inventory(SaveService.new(), wallet, ads)
	inventory.enter_level(3)
	for _gift: int in 3:
		assert_true(await inventory.pay(BoosterAccess.Kind.COXEUR))
	wallet.add(90, "test")
	assert_eq(inventory.offer(BoosterAccess.Kind.COXEUR), BoosterInventory.Offer.COINS)
	assert_true(await inventory.pay(BoosterAccess.Kind.COXEUR))
	assert_eq(wallet.balance(), 10)
	assert_eq(inventory.offer(BoosterAccess.Kind.COXEUR), BoosterInventory.Offer.AD)
	assert_true(await inventory.pay(BoosterAccess.Kind.COXEUR))
	assert_eq(ads.shown, 1)
	assert_eq(wallet.balance(), 10)


func test_refused_ad_charges_nothing() -> void:
	var inventory: BoosterInventory = _inventory(SaveService.new(), WalletService.new(), _ads(true, false))
	inventory.enter_level(3)
	for _gift: int in 3:
		await inventory.pay(BoosterAccess.Kind.COXEUR)
	assert_false(await inventory.pay(BoosterAccess.Kind.COXEUR))
	assert_eq(inventory.stock(BoosterAccess.Kind.COXEUR), 0)


func test_no_stock_no_coins_no_ad_means_lost_not_blocked() -> void:
	var inventory: BoosterInventory = _inventory(SaveService.new(), WalletService.new(), _ads(false))
	inventory.enter_level(3)
	assert_true(inventory.can_obtain(BoosterAccess.Kind.COXEUR))
	for _gift: int in 3:
		await inventory.pay(BoosterAccess.Kind.COXEUR)
	assert_false(inventory.can_obtain(BoosterAccess.Kind.COXEUR))
	var raw: Dictionary = {
		"id": 1, "slots": 1, "board": [12, 12],
		"vehicles": [
			{"type": "taxi", "dest": "b", "pos": [1, 5], "angle": 90},
			{"type": "taxi", "dest": "a", "pos": [2, 5], "angle": 90},
		],
		"queue": [{"dest": "a", "count": 4}, {"dest": "b", "count": 4}],
	}
	var level: LevelData = LevelLoader.parse_dict(raw, VehicleCatalog.load_default()).level
	var rules: GameRules = GameRules.new(level, inventory)
	rules.tap(0)
	assert_eq(rules.status, GameRules.Status.LOST)


func test_reset_clears_coins_stock_and_tutorial() -> void:
	var wallet: WalletService = WalletService.new()
	wallet.add(100, "test")
	var inventory: BoosterInventory = _inventory(SaveService.new(), wallet, _ads())
	inventory.enter_level(3)
	inventory.mark_tutorial_done(BoosterAccess.Kind.COXEUR)
	inventory.reset()
	assert_eq(wallet.balance(), 0)
	assert_eq(inventory.stock(BoosterAccess.Kind.COXEUR), 0)
	inventory.enter_level(3)
	assert_eq(inventory.stock(BoosterAccess.Kind.COXEUR), 3)
	assert_true(inventory.needs_tutorial(BoosterAccess.Kind.COXEUR))


func test_feature_flag_defaults_to_config_and_can_be_forced() -> void:
	var save: SaveService = SaveService.new()
	assert_true(Features.boosters_enabled(save))
	Features.force_boosters(save, false)
	assert_false(Features.boosters_enabled(save))
	Features.force_boosters(save, true)
	assert_true(Features.boosters_enabled(save))


func test_iap_mock_sells_nothing() -> void:
	var iap: IapService = IapService.new()
	assert_eq(iap.product_ids().size(), 0)
	assert_false(iap.purchase("x"))


# --- Limite du solveur ---

func _lane_level(count: int) -> LevelData:
	var entries: Array = []
	var blocks: Array = []
	for id: int in count:
		var column: int = floori(float(id) / 8.0)
		entries.append({"type": "taxi", "dest": "d%d" % id, "pos": [1.5 + float(column) * 2.0, 3.0 + float(id % 8) * 5.0], "angle": 90})
	for id: int in range(count - 1, -1, -1):
		blocks.append({"dest": "d%d" % id, "count": 4})
	var raw: Dictionary = {"id": 1, "slots": 4, "board": [24, 44], "vehicles": entries, "queue": blocks}
	var loaded: LevelLoadResult = LevelLoader.parse_dict(raw, VehicleCatalog.load_default())
	assert_true(loaded.is_ok(), "%s" % loaded.errors)
	return loaded.level


func test_solver_handles_80_vehicles_and_blockers_above_bit_62() -> void:
	var result: SolverResult = Solver.solve(_lane_level(Solver.MAX_VEHICLES), 4)
	assert_true(result.solvable)
	assert_false(result.aborted)
	assert_eq(result.min_slots, 1)
	assert_eq(result.solution.size(), Solver.MAX_VEHICLES)
	assert_eq(result.solution[0], Solver.MAX_VEHICLES - 1)
	var rules: GameRules = GameRules.new(_lane_level(Solver.MAX_VEHICLES))
	for id: int in result.solution:
		rules.tap(id)
	assert_eq(rules.status, GameRules.Status.WON)


func test_solver_respects_blocker_above_bit_62() -> void:
	var level: LevelData = _lane_level(70)
	var board: BoardLogic = BoardLogic.new(level)
	assert_true(board.blockers_of(69).is_empty())
	assert_true(board.blockers_of(64).has(69), "Colonne au-delà du bit 62")
	var result: SolverResult = Solver.solve(level, 4)
	assert_true(result.solution.find(69) < result.solution.find(64))
