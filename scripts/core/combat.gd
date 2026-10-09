class_name Combat extends RefCounted

static func calculate_damage(attacker: Unit, defender: Unit) -> int:
	var damage: int = attacker.data.attack - defender.data.defense
	if damage > 0:
		return damage
	else:
		return 1

static func in_range(unit: Unit, from: Vector2i, to: Vector2i) -> bool:
	var dist := absi(from.x - to.x) + absi(from.y - to.y)
	return dist >= unit.data.attack_range_min and dist <= unit.data.attack_range_max
	
static func resolve_attack(attacker: Unit, defender: Unit) -> Array[Hit]:
	var hits: Array[Hit] = []

	var dmg := calculate_damage(attacker, defender)
	var defender_hp := defender.hp - dmg
	hits.append(Hit.new(attacker, defender, dmg, defender_hp <= 0))
	if defender_hp > 0 and in_range(defender, defender.cell, attacker.cell):
		var counter_dmg := calculate_damage(defender, attacker)
		var attacker_hp := attacker.hp - counter_dmg
		hits.append(Hit.new(defender, attacker, counter_dmg, attacker_hp <= 0))
	return hits

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
