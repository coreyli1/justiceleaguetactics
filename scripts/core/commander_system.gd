class_name CommanderSystem extends RefCounted
## Runs the chosen commanders' bonuses during a battle: applies passives at the
## start, activates abilities, ticks cooldowns, and lets bonuses react to deaths.

signal changed   # uses or cooldowns changed, so menus can refresh

var states: Array[CommanderState] = []
var _battle: Battle


func _init(battle: Battle) -> void:
	_battle = battle
	for character in GameState.commanders:
		if character.data.commander_bonus:
			states.append(CommanderState.new(character))


func start() -> void:
	for state in states:
		state.deployed = _battle.get_unit_for(state.character) != null
		state.bonus.on_battle_start(_battle)


## Commanders that show up in the Commander menu.
func activatable() -> Array[CommanderState]:
	var result: Array[CommanderState] = []
	for state in states:
		if state.bonus.is_activated():
			result.append(state)
	return result


## Abilities that can be used right now, from any hero's action menu:
## activated, their commander was deployed (alive or not), and ready.
func usable() -> Array[CommanderState]:
	var result: Array[CommanderState] = []
	for state in activatable():
		if state.deployed and state.is_ready():
			result.append(state)
	return result


func activate(state: CommanderState, target: Unit = null) -> void:
	if not state.is_ready():
		return
	state.bonus.activate(_battle, target)
	state.spend()
	changed.emit()


## Called at the start of each new turn.
func tick() -> void:
	for state in states:
		state.tick()
	changed.emit()


## Gives bonuses a chance to stop a death (Green Lantern). True = the unit lives.
func prevent_death(unit: Unit) -> bool:
	for state in states:
		if state.uses_left != 0 and state.bonus.on_unit_died(_battle, unit, state):
			changed.emit()
			return true
	return false
