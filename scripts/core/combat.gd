class_name Combat extends RefCounted
## Pure combat rules. Nothing in here changes game state, so the AI can call
## these freely to predict outcomes ("what if I attacked from that cell?").

class Hit:
	var attacker: Unit
	var defender: Unit
	var damage: int
	var lethal: bool

	func _init(p_attacker: Unit, p_defender: Unit, p_damage: int, p_lethal: bool) -> void:
		attacker = p_attacker
		defender = p_defender
		damage = p_damage
		lethal = p_lethal


static func calculate_damage(attacker: Unit, defender: Unit) -> int:
	return maxi(1, attacker.data.attack - defender.data.defense)


static func in_range(unit: Unit, from: Vector2i, to: Vector2i) -> bool:
	var dist := absi(from.x - to.x) + absi(from.y - to.y)
	return dist >= unit.data.attack_range_min and dist <= unit.data.attack_range_max


## Enemies `unit` could hit if it stood at `from_cell`.
static func targets_from(unit: Unit, from_cell: Vector2i, grid: Grid, units: Dictionary) -> Array[Unit]:
	var targets: Array[Unit] = []
	for cell in grid.get_cells_in_range(from_cell, unit.data.attack_range_min, unit.data.attack_range_max):
		var other: Unit = units.get(grid.get_occupant(cell))
		if other and other.team != unit.team:
			targets.append(other)
	return targets


## Predicts a full exchange: the attack, plus a counter if the defender survives
## and can reach `attacker_cell`. Changes nothing.
static func resolve_attack(attacker: Unit, defender: Unit, attacker_cell: Vector2i) -> Array[Hit]:
	var hits: Array[Hit] = []

	var dmg := calculate_damage(attacker, defender)
	var defender_hp := defender.hp - dmg
	hits.append(Hit.new(attacker, defender, dmg, defender_hp <= 0))

	if defender_hp > 0 and in_range(defender, defender.cell, attacker_cell):
		var counter_dmg := calculate_damage(defender, attacker)
		var attacker_hp := attacker.hp - counter_dmg
		hits.append(Hit.new(defender, attacker, counter_dmg, attacker_hp <= 0))

	return hits
