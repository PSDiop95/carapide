class_name WheelLogic
extends RefCounted
## Tirage pondéré de la Roue : logique pure, la graine est fournie.


static func draw(cells: Array[WheelCell], seed_value: int) -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var total: int = 0
	for cell: WheelCell in cells:
		total += cell.weight
	var roll: int = rng.randi_range(0, total - 1)
	for index: int in cells.size():
		roll -= cells[index].weight
		if roll < 0:
			return index
	return cells.size() - 1
