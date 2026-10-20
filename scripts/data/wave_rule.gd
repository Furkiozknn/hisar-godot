class_name WaveRule
extends Resource
## One group of enemies inside a wave. Count and gap scale with the wave number w:
## count = base_count + floor(count_per_wave * (w - count_offset)),
## gap = max(gap_min, gap_base - gap_per_wave * w).

@export var enemy: StringName = &"raider"
@export var from_wave: int = 1
## The group only appears on waves where w % every == 0 (1 = every wave).
@export var every: int = 1
@export var base_count: int = 0
@export var count_per_wave: float = 1.0
@export var count_offset: int = 0
@export var gap_base: float = 1.0
@export var gap_per_wave: float = 0.0
@export var gap_min: float = 0.3


func applies(w: int) -> bool:
	return w >= from_wave and (every <= 1 or w % every == 0)


func count_for(w: int) -> int:
	return maxi(0, base_count + floori(count_per_wave * float(w - count_offset) + 0.0001))


func gap_for(w: int) -> float:
	return maxf(gap_min, gap_base - gap_per_wave * float(w))
