class_name UpgradeDef
extends Resource
## Outros upgrades mecanicos (freio-motor, pneus): um efeito numerico simples.

@export var id: StringName
@export var display_key: String = ""
@export var effect: StringName                 # engine_brake, grip, tire_wear
@export var value: float = 0.0                 # 0.35 = +35%
@export var side_effect: StringName
@export var side_value: float = 0.0
@export var price: int = 0
