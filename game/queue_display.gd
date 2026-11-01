class_name QueueDisplay
extends RefCounted
## Blocs encore dans la file, pour les compteurs : les cubes sont plafonnés, pas ce calcul.


## Blocs restants une fois `served` passagers partis ; blocs voisins de même destination fusionnés.
static func remaining_blocks(queue: Array[QueueBlock], served: int) -> Array[QueueBlock]:
	var blocks: Array[QueueBlock] = []
	var to_skip: int = served
	for block: QueueBlock in queue:
		var skipped: int = mini(to_skip, block.count)
		to_skip -= skipped
		var left: int = block.count - skipped
		if left == 0:
			continue
		if not blocks.is_empty() and blocks[-1].dest == block.dest:
			blocks[-1].count += left
		else:
			blocks.append(QueueBlock.new(block.dest, left))
	return blocks
