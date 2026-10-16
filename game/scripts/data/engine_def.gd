class_name EngineDef
extends Resource
## Motor (BALANCEAMENTO: "Motor, turbo e escape"). A curva de torque entra na P44.

@export var id: StringName
@export var display_key: String = ""
@export var weight_kg: float = 0.0             # peso extra sobre o motor padrao
@export var max_torque_nm: float = 1400.0
@export var redline_rpm: float = 2400.0
@export var price: int = 0                     # 0 = vem de fabrica
@export var sound_set: String = ""             # prefixo dos loops de audio (P50/P51)
