class_name IapService
extends RefCounted
## Interface des achats intégrés. Mock vide : aucun produit (hors scope tant que non demandé).


func product_ids() -> PackedStringArray:
	return PackedStringArray()


func purchase(_product_id: String) -> bool:
	return false
