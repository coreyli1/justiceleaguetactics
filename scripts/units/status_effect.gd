class_name StatusEffect extends RefCounted

var name := ""
var turns_left := 1    
var move_bonus := 0
var shield := 0        
var phasing := false   


static func speed(amount: int) -> StatusEffect:
	var effect := StatusEffect.new()
	effect.name = "Speed"
	effect.move_bonus = amount
	return effect


static func shielded(amount: int) -> StatusEffect:
	var effect := StatusEffect.new()
	effect.name = "Shield"
	effect.shield = amount
	return effect


static func phase() -> StatusEffect:
	var effect := StatusEffect.new()
	effect.name = "Phasing"
	effect.phasing = true
	return effect
