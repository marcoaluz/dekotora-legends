class_name RivalDef
extends Resource
## Rival (bot): nome, dificuldade da IA, cor do caminhao e pecas instaladas. `boss` = chefe do trecho.

@export var id: StringName
@export var display_name: String = ""          # nome provisorio (decisao aberta do Marco)
@export var difficulty: int = 1                # BotDriver.Difficulty
@export var paint: Color = Color.WHITE
@export var part_ids: PackedStringArray = []
@export var boss: bool = false
@export var taunt_key: String = ""              # short taunt in the face-to-face opening (T-156)
@export var truck_key: String = ""             # name of the rival's truck (i18n, T-156)
@export var crest: String = ""                 # one kanji on the crest of the band (no portrait art yet, T-156)
@export var min_fame: int = 0                  # Fama minima do jogador para o rival aceitar o desafio
@export var min_destaque: int = 0              # Destaque minimo (pecas, pintura, adesivos) para aceitar
@export var refuse_key: String = ""            # fala curta de recusa (i18n)
