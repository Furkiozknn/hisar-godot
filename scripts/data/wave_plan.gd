class_name WavePlan
extends Resource
## Ordered list of WaveRule groups that make up every wave.

@export var rules: Array[WaveRule] = []
## Pause between two groups in seconds.
@export var group_pause: float = 1.6
