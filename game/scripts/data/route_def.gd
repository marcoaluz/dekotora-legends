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
@export var places: PackedStringArray = []      # cidades do trecho (origem/destino dos contratos)


func build_track(seed_: int = 7) -> Track:
	var t := Track.new()
	for s in sections:
		t.add_section(float(s["length"]), float(s["curve"]), float(s.get("hill", 0.0)))
	t.decorate_roadside(seed_)
	return t
