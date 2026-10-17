class_name RouteDef
extends Resource
## Trecho de rota: forma da pista (secoes), frete, cenario e rival. Gera um Track para a simulacao.

@export var id: StringName
@export var display_key: String = ""
@export var region: StringName = &"kanto"
@export var freight: int = 0
@export var sections: Array[Dictionary] = []   # {length, curve, hill}
@export var scenery: StringName = &"coast"     # coast, city, mountain
@export var rival_id: StringName
@export var traffic: int = 1                   # TrafficSim.Density
@export var night: bool = true                 # musica e farois; derivado da hora do dia (dia = false)
@export var time_of_day: StringName = &"night" # preset em data/time/ (night, dusk, day)
@export var fame_required: int = 0
@export var tunnels: Array[Vector2] = []        # (inicio m, comprimento m) so visual: Tunnel3D
@export var places: PackedStringArray = []      # cidades do trecho (origem/destino dos contratos)
@export var deadline_s: float = 0.0             # prazo de entrega (s); 0 = calculado pelo comprimento do trecho

const DEADLINE_REF_SPEED: float = 27.0           # m/s (~97 km/h) de referencia para o prazo
const DEADLINE_SLACK: float = 1.2                # folga sobre o tempo de referencia


func length_m() -> float:
	var total: float = 0.0
	for s in sections:
		total += float(s["length"])
	return total


## Prazo de entrega em segundos: vence quem chega primeiro E dentro deste tempo (docs/DECISOES.md, ATB-1).
func deadline() -> float:
	if deadline_s > 0.0:
		return deadline_s
	return roundf(length_m() / DEADLINE_REF_SPEED * DEADLINE_SLACK)


func build_track(seed_: int = 7) -> Track:
	var t := Track.new()
	for s in sections:
		t.add_section(float(s["length"]), float(s["curve"]), float(s.get("hill", 0.0)))
	t.decorate_roadside(seed_)
	return t
