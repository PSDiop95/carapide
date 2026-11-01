class_name AdsService
extends RefCounted
## Interface de publicité récompensée. Implémentation par défaut : mock, aucun SDK.

var available: bool = true
var succeeds: bool = true
var delay_seconds: float = 1.0
var shown: int = 0


func is_rewarded_available() -> bool:
	return available


## Vrai si la pub a été vue jusqu'au bout.
func show_rewarded() -> bool:
	shown += 1
	var tree: SceneTree = Engine.get_main_loop()
	await tree.create_timer(delay_seconds).timeout
	return succeeds
