class_name RivalDef
extends Resource
## Rival (bot): nome, dificuldade da IA, cor do caminhao e pecas instaladas. `boss` = chefe do trecho.

@export var id: StringName
@export var display_name: String = ""          # nome provisorio (decisao aberta do Marco)
@export var difficulty: int = 1                # BotDriver.Difficulty
@export var paint: Color = Color.WHITE
@export var part_ids: PackedStringArray = []
@export var boss: bool = false
@export var taunt_key: String = ""
