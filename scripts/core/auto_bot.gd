class_name AutoBot
extends RefCounted
## Self-test player (started with `-- --auto`): builds towers near the gate in a fixed
## order, upgrades the cheapest tower when it can, and starts every wave at once.

const PLAN: Array[StringName] = [&"archer", &"archer", &"cannon", &"tar", &"archer", &"cannon", &"archer", &"tar", &"cannon", &"archer"]
const THINK: float = 0.5

var sim: BattleSim
var _pads: Array[int] = []
var _plan_idx: int = 0
var _timer: float = 0.0


func _init(battle: BattleSim) -> void:
	sim = battle
	for i: int in range(sim.layout.pads.size()):
		_pads.append(i)
	var pads: Array[Vector2] = sim.layout.pads
	_pads.sort_custom(func(a: int, b: int) -> bool:
		return pads[a].distance_to(Vector2(12, 0)) < pads[b].distance_to(Vector2(12, 0)))


## Returns true if the bot did something this call (for the view to react).
func update(dt: float) -> bool:
	_timer -= dt
	if _timer > 0.0 or sim.over:
		return false
	_timer = THINK
	var acted: bool = false
	var free: int = -1
	for p: int in _pads:
		if sim.tower_on_pad(p) == null:
			free = p
			break
	var type: StringName = PLAN[_plan_idx % PLAN.size()]
	var cheapest: BattleSim.Tower = null
	var cheapest_cost: int = 1 << 30
	for t: BattleSim.Tower in sim.towers:
		var c: int = sim.upgrade_cost(t)
		if c >= 0 and c < cheapest_cost:
			cheapest_cost = c
			cheapest = t
	if free >= 0 and sim.gold >= sim.build_cost(type) and (sim.towers.size() < 8 or cheapest == null or sim.gold > 260):
		if sim.build(free, type) != null:
			_plan_idx += 1
			acted = true
	elif cheapest != null and sim.gold >= cheapest_cost:
		acted = sim.upgrade(cheapest)
	if sim.phase == &"build" and not sim.over:
		acted = sim.start_wave() or acted
	return acted
