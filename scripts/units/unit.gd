class_name Unit extends GridEntity

const HIT_FLASH_AMOUNT := 0.5  
const HIT_FLASH_TIME := 0.1    
var _flash_tween: Tween

enum Team { PLAYER, ENEMY }

var data: UnitData
var team: Team
var type: UnitData.Type

var hp: int:
	set(value):
		hp = value
		_redraw_bar()
var has_acted: bool
var character: CharacterState

var bonus_attack := 0
var bonus_move := 0
var bonus_max_hp := 0
var effects: Array[StatusEffect] = []  

var attack: int:
	get:
		return data.attack + bonus_attack

var max_hp: int:
	get:
		return data.max_hp + bonus_max_hp

var move_range: int:
	get:
		var total := data.move_range + bonus_move
		for effect in effects:
			total += effect.move_bonus
		return total

var shield: int:
	get:
		var total := 0
		for effect in effects:
			total += effect.shield
		return total

var can_fly: bool:
	get:
		return data.can_fly or _is_phasing()

var can_pass_units: bool:
	get:
		return _is_phasing()



func setup(p_data: UnitData, p_team: Team) -> void:
	data = p_data
	if data.sprite:
		$Sprite2D.texture = data.sprite
	team = p_team
	type = data.type
	hp = data.max_hp
	
	update_visual()

func set_type(new_type: UnitData.Type) -> void:
	type = new_type
	_redraw_bar()   # the bar shows the type pip


func add_effect(effect: StatusEffect) -> void:
	effects.append(effect)
	_redraw_bar()


func tick_effects() -> void:
	var kept: Array[StatusEffect] = []
	for effect in effects:
		effect.turns_left -= 1
		if effect.turns_left > 0:
			kept.append(effect)
	effects = kept
	_redraw_bar()


func _is_phasing() -> bool:
	for effect in effects:
		if effect.phasing:
			return true
	return false


func _redraw_bar() -> void:
	var bar := get_node_or_null("HpBar") as CanvasItem
	if bar:
		bar.queue_redraw()


func show_hp(value: bool) -> void:
	$HpBar.visible = value


func update_visual() -> void:
	modulate = Color.WHITE   
	if has_acted:
		modulate = modulate.darkened(0.5)
	

func move_along(path: Array[Vector2i], grid: Grid) -> Tween:
	if path.is_empty():
		return null
	cell = path[-1]
	if path.size() < 2:
		return null
	var tween := create_tween()
	for step in path.slice(1):
		tween.tween_property(self, "position", grid.cell_to_world(step), 0.12)
	return tween

func flash_hit() -> void:
	var sprite: Sprite2D = $Sprite2D
	if _flash_tween:
		_flash_tween.kill()   # a new hit restarts the flash instead of fighting the old one
	sprite.modulate = Color.WHITE.darkened(HIT_FLASH_AMOUNT)
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "modulate", Color.WHITE, HIT_FLASH_TIME)
