class_name PartDef
extends Resource
## Peca decorativa/estrutural do caminhao (docs/BALANCEAMENTO.md). O modelo 3D vem da biblioteca de
## acessorios (`accessory_id` no catalog.json) com variantes de material opcionais.

@export var id: StringName
@export var display_key: String = ""            # chave de i18n (game/data/i18n)
@export var slot: StringName                    # front_bumper, visor, roof_lights, side_skirts, andon, ...
@export var zones: PackedStringArray = []       # zonas de dano: front, rear, left, right, roof, wheels
@export var weight_kg: float = 0.0
@export var durability: float = 0.0             # 0 = sem durabilidade (murais: riscam em vez de quebrar)
@export var fame: int = 0
@export var price: int = 0
@export var fame_required: int = 0              # Fama minima para liberar na loja
@export var accessory_id: String = ""           # id em assets/vehicles/dekotora/catalog.json
@export var variant: Dictionary = {}           # {"main": "paint_gold", "accent": "lamp_cyan"}
@export var horn: String = ""                  # som de buzina que a peca traz (audio/sfx/truck), se tiver
## T-211 (decisao 4 do Marco): so etiquetas nos dados, NAO travam a compra. "" = peca Classica (antes da T-211).
@export var rarity: StringName = &""            # comum | incomum | rara | lendaria
@export var fame_min: int = 0                   # Fama minima sugerida (informativa; quem trava e fame_required)


## Dicionario usado pela simulacao (DamageModel.make_part): da mais externa para a interna = ordem da lista.
func to_sim_part() -> Dictionary:
	return DamageModel.make_part(String(id), Array(zones), weight_kg, durability, fame)
