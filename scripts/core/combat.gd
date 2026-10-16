class_name Combat extends RefCounted

const STRONG := 1.5
const WEAK := .75

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

const BEATS := {
	UnitData.Type.HUMAN: UnitData.Type.ALIEN,
	UnitData.Type.ALIEN: UnitData.Type.META,
	UnitData.Type.META: UnitData.Type.HUMAN,
}

static func type_multiplier(attacker_type: UnitData.Type, defender_type: UnitData.Type) -> float:
	if BEATS[attacker_type] == defender_type:
		return STRONG
	if BEATS[defender_type] == attacker_type:
		return WEAK
	return 1.0


static func calculate_damage(attacker: Unit, defender: Unit) -> int:
	var damage := attacker.attack * type_multiplier(attacker.type, defender.type)
	return maxi(0, maxi(1, roundi(damage)) - defender.shield)

static func in_range(unit: Unit, from: Vector2i, to: Vector2i) -> bool:
	var dist := absi(from.x - to.x) + absi(from.y - to.y)
	return dist >= unit.data.attack_range_min and dist <= unit.data.attack_range_max


static func targets_from(unit: Unit, from_cell: Vector2i, grid: Grid, units: Dictionary) -> Array[Unit]:
	var targets: Array[Unit] = []
	for cell in grid.get_cells_in_range(from_cell, unit.data.attack_range_min, unit.data.attack_range_max):
		var other: Unit = units.get(grid.get_occupant(cell))
		if other and other.team != unit.team:
			targets.append(other)
	return targets



static func resolve_attack(attacker: Unit, defender: Unit, _attacker_cell: Vector2i) -> Array[Hit]:
	var hits: Array[Hit] = []
	var damage := calculate_damage(attacker, defender)
	hits.append(Hit.new(attacker, defender, damage, defender.hp - damage <= 0))
	return hits
