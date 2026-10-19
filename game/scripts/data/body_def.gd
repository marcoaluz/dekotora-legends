class_name BodyDef
extends Resource
## Modelo de caminhao (carroceria) para a simulacao: massa vazia, capacidade do bau, comprimento (hitbox), agilidade
## na troca de faixa e torque do motor. Arquivos em data/bodies/<id>.tres (leve, base, longo, canter, graneleira).
## O baú leve/medio/longo ainda usam os mesmos numeros do caminhao padrao (so a capacidade muda: decisao pendente).

@export var id: StringName
@export var base_mass_kg: float = 8000.0          # vazio, com bau
@export var capacity_t: float = 12.0              # contrato mais pesado que isto nao pode ser aceito
@export var default_cargo_kg: float = 4000.0      # carga quando nao ha contrato (corrida livre, multiplayer)
@export var length_m: float = 12.0                # comprimento na simulacao (colisao, vacuo)
@export var agility: float = 1.0                  # multiplica a rapidez da troca de faixa (1,2 = ~0,85 s)
@export var torque_mult: float = 1.0              # motor menor (Canter: 4 cilindros)
## Cabine fixa do modelo ("" = escolhe na garagem). O Canter so tem a cabine curta do JAC.
@export var fixed_cab: String = ""
## Tipo de carroceria para os contratos (T-145): &"box" = bau fechado; &"open" = aberta com lona (graneleira).
## A carga diz o que precisa em CargoDef.needs; Contracts.body_kind/needs_body aplicam a regra.
@export var cargo_kind: StringName = &"box"

const DIR := "res://data/bodies/"


static func find(body: String) -> BodyDef:
	var path: String = DIR + body + ".tres"
	return load(path) as BodyDef if ResourceLoader.exists(path) else null
