class_name QueueBlock
extends RefCounted
## Bloc de passagers consécutifs de même destination.

var dest: String
var count: int


func _init(block_dest: String, block_count: int) -> void:
	dest = block_dest
	count = block_count
