extends Node
## Point d'accès aux services (autoload `Services`). Mocks par défaut, aucun SDK.

const SAVE_PATH: String = "user://progress.json"
const PLAYTEST_CSV_PATH: String = "user://playtest.csv"

var save: SaveService = FileSaveService.new(SAVE_PATH)
var analytics: AnalyticsService = CsvAnalyticsService.new(PLAYTEST_CSV_PATH)
var haptics: HapticsService = _make_haptics()
var wallet: WalletService = SavedWalletService.new(save, analytics)
var ads: AdsService = CappedAdsService.new(save, EconomyConfig.load_default().rewarded_ads_per_day)
var iap: IapService = IapService.new()


static func _make_haptics() -> HapticsService:
	if OS.has_feature("mobile"):
		return DeviceHapticsService.new()
	return HapticsService.new()
