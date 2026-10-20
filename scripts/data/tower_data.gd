class_name TowerData
extends Resource
## Static stats for one tower type. Every array has one entry per level (0, 1, 2).

@export var id: StringName = &""
@export var name_key: String = ""
@export var desc_key: String = ""
@export var cost: PackedInt32Array = PackedInt32Array()
@export var reach: PackedFloat32Array = PackedFloat32Array()
## Seconds between shots.
@export var rate: PackedFloat32Array = PackedFloat32Array()
## Direct damage (archer, cannon).
@export var damage: PackedFloat32Array = PackedFloat32Array()
## Splash radius (cannon, tar). Empty means single target.
@export var splash: PackedFloat32Array = PackedFloat32Array()
## Burn damage per second (tar).
@export var burn_dps: PackedFloat32Array = PackedFloat32Array()
## Speed multiplier applied to slowed enemies (tar). Lower is slower.
@export var slow: PackedFloat32Array = PackedFloat32Array()
## Height of the turret pivot above the pad, per level (used for the muzzle position).
@export var pivot: PackedFloat32Array = PackedFloat32Array()
## Flight time of ballistic shots in seconds (0 means a homing arrow).
@export var flight_time: float = 0.0
## Projectile kind: "arrow", "ball" or "tar".
@export var projectile: StringName = &"arrow"


func levels() -> int:
	return cost.size()


func stat(values: PackedFloat32Array, level: int) -> float:
	if values.is_empty():
		return 0.0
	return values[clampi(level, 0, values.size() - 1)]
