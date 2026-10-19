class_name TimeOfDay
extends Resource
## Hora do dia de uma corrida (preset em data/time/: night, dusk, day). Tudo que muda entre noite, fim de
## tarde e dia fica aqui: ceu (shader), luz do sol/lua, neblina, exposicao, janelas dos predios, neon, pocas
## de luz dos postes, farois e cores do fundo. Escolhido por rota (RouteDef.time_of_day) ou por --time=<id>.

const DIR := "res://data/time/"

@export var id: StringName = &"night"
@export_group("Ceu")
@export var sky_top: Color = Color("#02030a")
@export var sky_horizon: Color = Color("#0b1030")
@export var sky_ground: Color = Color("#030308")
@export var horizon_glow: Color = Color("#3d1a0e")    # brilho da cidade (noite) ou do por do sol (tarde)
@export var glow_falloff: float = 14.0                # maior = brilho mais colado no horizonte
@export var disk_color: Color = Color("#fff4e0")      # sol ou lua (posicao = direcao da luz principal)
@export var disk_energy: float = 3.0
@export var disk_size_deg: float = 1.4
@export var halo: float = 0.4
@export var stars: float = 1.0
@export var clouds: float = 0.0
@export var cloud_color: Color = Color("#ffffff")
@export_group("Luz")
@export var light_color: Color = Color("#8ea6ff")
@export var light_energy: float = 0.6
@export var light_rotation: Vector3 = Vector3(-26, 32, 0)
@export var ambient_energy: float = 0.7
@export var fog_color: Color = Color("#141a33")
@export var fog_density: float = 0.0028
@export var exposure: float = 1.0
@export var contrast: float = 1.18
@export var saturation: float = 0.9
@export var glow_intensity: float = 1.1
@export var glow_bloom: float = 0.08
@export var glow_threshold: float = 0.9
@export_group("Cenario")
@export var day_amount: float = 0.0                   # 0 = noite, 1 = dia (paredes claras, vidro refletindo o ceu)
@export var window_energy: float = 2.0
@export var neon_energy: float = 1.0
@export var pool_energy: float = 0.75                 # poca de luz de sodio sob os postes
@export var lamps_on: bool = true
@export var headlights: bool = true
## Luz falsa das luzinhas sobre o mural das laterais (bau e tampas da graneleira; MuralGlow, T-155): 0 = nenhuma.
@export var mural_glow: float = 0.8
@export var road_roughness: float = 0.55              # menor = asfalto mais molhado
@export var line_emission: float = 0.8
@export var mountain_color: Color = Color("#16143a")
@export var land_color: Color = Color("#080c1c")
@export var water_color: Color = Color("#010a1e")


static func by_id(tid: StringName) -> TimeOfDay:
	var p: String = DIR + String(tid) + ".tres"
	if ResourceLoader.exists(p):
		return load(p) as TimeOfDay
	return TimeOfDay.new()
