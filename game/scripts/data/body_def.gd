class_name BodyDef
extends Resource
## Modelo de caminhao (carroceria) para a simulacao: massa vazia, capacidade do bau, comprimento (hitbox), agilidade
## na troca de faixa e torque do motor. Arquivos em data/bodies/<id>.tres (leve, base, longo, canter, graneleira e, desde
## a T-218, os caminhoes de homenagem alubox, tarp, pinkbox, tanker, dump; desde a T-240 com cabine trocavel).
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
## T-240: cabine de fabrica (caminhoes de homenagem): vem montada ao comprar o modelo; depois o jogador troca na garagem.
@export var factory_cab: String = ""
## Tipo de carroceria para os contratos (T-145): &"box" = bau fechado; &"open" = aberta com lona (graneleira, lona,
## cacamba); &"tank" = tanque (T-218: so ele leva combustivel).
## A carga diz o que precisa em CargoDef.needs; Contracts.body_kind/needs_body aplicam a regra.
@export var cargo_kind: StringName = &"box"
## T-218 (caminhoes de homenagem; numeros sao PROPOSTA para o Marco): preco na garagem (0 = de graca, como os antigos)
## e Fama minima para comprar. Comprado uma vez, fica no perfil (`owned_bodies`).
@export var price: int = 0
@export var fame_required: int = 0
## Cor de fabrica (#rrggbb): a garagem pinta o caminhao com ela ao comprar o modelo; o rival usa a dele (RivalDef.paint).
@export var default_paint: String = ""
## Mural proprio do modelo (PNG 4:1) e a emissao dele para a noite (neons); "" = o mural trocavel de sempre.
@export var mural: String = ""
@export var mural_emit: String = ""

const DIR := "res://data/bodies/"
## Modelos que os bots (corrida offline sem rival fixo e sala online) podem receber no sorteio (T-218).
const BOT_POOL: Array[String] = ["base", "leve", "longo", "graneleira", "alubox", "tarp", "pinkbox", "tanker", "dump"]


## Cabine de um caminhao de bot/rival (T-240): os de homenagem continuam com a cabine de fabrica (Trovao Rosa = rosa com a
## cabine plana larga); os outros usam `fallback`. Codigo puro (servidor).
static func default_cab(body: String, fallback: String) -> String:
	var bd: BodyDef = find(body)
	return bd.factory_cab if bd != null and bd.factory_cab != "" else fallback


static func find(body: String) -> BodyDef:
	var path: String = DIR + body + ".tres"
	return load(path) as BodyDef if ResourceLoader.exists(path) else null
