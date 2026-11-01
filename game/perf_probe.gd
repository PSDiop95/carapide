class_name PerfProbe
extends Node
## Sonde de mesure en release, activée seulement par un fichier témoin déposé par adb :
## l'argument de lancement n'arrive pas au jeu en release, et `run-as` y est interdit.
## Joue le niveau de référence, déclenche l'effet mesuré, écrit le résultat dans logcat.

const MARKER_PATH: String = "/storage/emulated/0/Android/data/com.carapide.prototype/files/perf_probe.txt"
const LOG_PREFIX: String = "CARAPIDE_PERF"
const REFERENCE_LEVEL: int = 10
## Niveau le plus chargé en draw calls, mesuré à part.
const PEAK_EFFECT: String = "level14"
const PEAK_LEVEL: int = 14
const WARMUP_SECONDS: float = 2.0
const DURATION_SECONDS: float = 60.0
const STEP_SECONDS: float = 0.8
const LOW_PERCENTILE: float = 0.05
const MEDIAN_PERCENTILE: float = 0.5
const NONE: String = "none"

static var _effect_ms_peak: float = 0.0

var _main: GameMain
var _effect: String = NONE
var _frames: PackedFloat32Array = PackedFloat32Array()
var _draw_peak: float = 0.0
var _elapsed: float = 0.0
var _next_step: float = 0.0
var _finished: bool = false
var _gpu_ms_total: float = 0.0
var _cpu_ms_total: float = 0.0
var _video_peak: float = 0.0


## Effet demandé par le fichier témoin, vide hors mesure.
static func requested_effect() -> String:
	if not OS.has_feature("android") or not FileAccess.file_exists(MARKER_PATH):
		return ""
	return FileAccess.get_file_as_string(MARKER_PATH).strip_edges()


static func record_effect_ms(duration_ms: float) -> void:
	_effect_ms_peak = maxf(_effect_ms_peak, duration_ms)


func setup(main: GameMain, effect: String) -> void:
	_main = main
	_effect = effect


## Le premier écran répond aux taps : repère du démarrage réel, lu dans logcat.
static func log_interactive() -> void:
	print("%s interactive" % LOG_PREFIX)


func _ready() -> void:
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_main.prepare_for_measure()
	_main.jump_to_level(PEAK_LEVEL if _effect == PEAK_EFFECT else REFERENCE_LEVEL)


func _process(delta: float) -> void:
	if _finished:
		return
	_elapsed += delta
	if _elapsed > WARMUP_SECONDS:
		_frames.append(delta)
		_draw_peak = maxf(_draw_peak, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		_video_peak = maxf(_video_peak, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
		var rid: RID = get_viewport().get_viewport_rid()
		_gpu_ms_total += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		_cpu_ms_total += RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu()
	if _elapsed >= _next_step:
		_next_step = _elapsed + STEP_SECONDS
		_main.measure_step(_effect)
	if _elapsed >= WARMUP_SECONDS + DURATION_SECONDS:
		_finished = true
		_report()


func _report() -> void:
	_frames.sort()
	var p50: float = 1.0 / _frames[int(float(_frames.size() - 1) * MEDIAN_PERCENTILE)]
	var p5: float = 1.0 / _frames[int(float(_frames.size() - 1) * (1.0 - LOW_PERCENTILE))]
	var count: float = float(_frames.size())
	print("%s effect=%s frames=%d fps_p50=%.1f fps_p5=%.1f draw_peak=%d gpu_ms=%.1f render_cpu_ms=%.1f video_mb=%.0f static_mb=%.0f effect_ms=%.0f done=1" % [
		LOG_PREFIX, _effect, _frames.size(), p50, p5, int(_draw_peak), _gpu_ms_total / count, _cpu_ms_total / count,
		_video_peak / 1048576.0, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, _effect_ms_peak,
	])
