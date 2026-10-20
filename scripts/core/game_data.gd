class_name GameData
extends RefCounted
## Loads every balance resource from res://data once and hands them to the simulation.

const TOWER_ORDER: Array[StringName] = [&"archer", &"cannon", &"tar"]
const ENEMY_ORDER: Array[StringName] = [&"raider", &"rider", &"shield", &"ram"]

var config: GameConfig
var waves: WavePlan
var towers: Dictionary = {}   # StringName -> TowerData
var enemies: Dictionary = {}  # StringName -> EnemyData

static var _cached: GameData = null


static func load_default() -> GameData:
	if _cached != null:
		return _cached
	var d := GameData.new()
	d.config = load("res://data/config.tres") as GameConfig
	d.waves = load("res://data/waves.tres") as WavePlan
	for id: StringName in TOWER_ORDER:
		d.towers[id] = load("res://data/towers/%s.tres" % id) as TowerData
	for id: StringName in ENEMY_ORDER:
		d.enemies[id] = load("res://data/enemies/%s.tres" % id) as EnemyData
	_cached = d
	return d


func tower(id: StringName) -> TowerData:
	return towers[id] as TowerData


func enemy(id: StringName) -> EnemyData:
	return enemies[id] as EnemyData
