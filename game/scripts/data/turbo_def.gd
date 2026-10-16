class_name TurboDef
extends Resource
## Turbo: ganho de torque em alta rotacao, rotacao minima e atraso (turbo lag).

@export var id: StringName
@export var display_key: String = ""
@export var torque_gain: float = 0.0           # 0.18 = +18%
@export var min_rpm: float = 1500.0
@export var lag_s: float = 0.0
@export var price: int = 0
