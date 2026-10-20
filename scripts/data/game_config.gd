class_name GameConfig
extends Resource
## Global balance numbers.

@export var max_waves: int = 15
@export var start_gold: int = 180
@export var start_lives: int = 20
@export var sell_refund: float = 0.7
## Enemy HP multiplier: 1 + hp_linear * (w - 1) + hp_quadratic * (w - 1)^2.
@export var hp_linear: float = 0.18
@export var hp_quadratic: float = 0.022
## Gold paid when a wave is fully cleared: clear_bonus_base + clear_bonus_per_wave * w.
@export var clear_bonus_base: int = 15
@export var clear_bonus_per_wave: int = 3
## Gold paid for calling the next wave early: early_bonus_base + early_bonus_per_wave * w.
@export var early_bonus_base: int = 8
@export var early_bonus_per_wave: int = 2
## Extra gold per kill every N waves.
@export var gold_bonus_every: int = 5
@export var max_puddles: int = 40
