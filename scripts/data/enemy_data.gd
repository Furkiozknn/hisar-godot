class_name EnemyData
extends Resource
## Static stats for one enemy type.

@export var id: StringName = &""
@export var name_key: String = ""
@export var hp: float = 50.0
@export var speed: float = 2.5
@export var gold: int = 5
## Fraction of arrow damage blocked (cannonballs are blocked by half of it).
@export_range(0.0, 0.95) var armor: float = 0.0
## Fortress lives lost when this enemy reaches the gate.
@export var lives: int = 1
## Model height in world units (health bar and text placement).
@export var height: float = 1.6
@export var model_scale: float = 1.6
@export var is_boss: bool = false
