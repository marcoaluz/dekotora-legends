class_name TruckFeel
extends Resource
## T-219: "game feel" (sensacao de PESO) do caminhao num arquivo so: game/data/feel/truck_feel.tres.
## Abra o .tres no Godot (painel Inspetor) ou num editor de texto, mude um numero, salve e rode a corrida de novo.
##
## Dois grupos:
##  - SIMULACAO (sim_*): muda o resultado da corrida (aceleracao, troca de faixa, peso). Vale igual para o jogador,
##    os bots, o servidor e a predicao do cliente. Online, o servidor e os celulares precisam ter o MESMO arquivo
##    (mudou aqui = gere o APK de novo e suba o Protocol.VERSION em scripts/net/protocol.gd).
##  - VISUAL (o resto): so a tela, o som e a vibracao do proprio aparelho. Pode mudar a vontade.
## A simulacao le so os campos sim_* (nada de render aqui: e so um Resource com numeros).

const PATH := "res://data/feel/truck_feel.tres"

@export_group("Simulacao (vale online)")
## Forca maxima nas rodas na arrancada (N). Menor = sai mais devagar nas marchas baixas. Antes da T-219: 32000.
@export var sim_traction_limit_n: float = 29000.0
## Corte de torque em cada troca de marcha (s). Maior = o caminhao "respira" mais a cada marcha. Antes: 0,35.
@export var sim_shift_time_s: float = 0.45
## Quanto cada kg de CARGA ACIMA DE 4 t (a carga padrao) pesa na inercia (aceleracao e troca de faixa). 1,0 = so a massa
## real. Bau cheio de 12 t com 1,25: os 8 t a mais pesam como 10 t. Antes: 1,0.
@export var sim_cargo_inertia: float = 1.25
## Quanto cada kg de PECA (e motor) pesa na inercia. 1,5 = uma peca de 500 kg pesa como 750 kg. Antes: 1,0.
@export var sim_parts_inertia: float = 1.5
## Inercia lateral no comeco da troca de faixa (1/s). Menor = demora mais para comecar a sair da faixa. Antes: 3,2.
@export var sim_steer_response: float = 2.6
## Quanto o caminhao corre atras da faixa nova (1/s). Menor = o fim da troca "arrasta" mais. Antes: 1,9.
@export var sim_lane_gain: float = 1.7
## Velocidade lateral maxima (unidades de faixa por s; 1 = 7,2 m/s). Antes: 0,95.
@export var sim_lane_max_vel: float = 0.95
## Quanto a massa (com a inercia acima) deixa a troca de faixa mais lenta: (12 t / massa) elevado a este numero.
## 0 = a massa nao muda nada alem da aderencia (como antes); 0,4 = bau cheio (contrato de 12 t) troca ~25% mais devagar.
@export var sim_lane_mass_exp: float = 0.4

@export_group("Inclinacao do bau (roll)")
## Graus de inclinacao por m/s2 de aceleracao lateral (curva + troca de faixa). O bau tomba para FORA.
## A troca de faixa chega a ~10 m/s2 (0,35 = ~3,5 graus no pico).
@export var roll_deg_per_mps2: float = 0.35
## Inclinacao maxima (graus).
@export var roll_max_deg: float = 4.0
## Frequencia do balanco (Hz). Menor = mais mole, mais "atrasado". Caminhao carregado: 0,8 a 1,3.
@export var roll_freq_hz: float = 1.05
## Amortecimento (0..1). Menor = balanca mais vezes antes de parar (0,35 = volta passando um pouco do meio).
@export var roll_damping: float = 0.38
## Quanto a curva da pista entra na inclinacao (0 = so a troca de faixa). As curvas das rotas sao suaves (~1 m/s2 a
## 100 km/h): com 3 uma curva longa inclina ~1 grau.
@export var roll_curve_share: float = 3.0

@export_group("Cabeceio (pitch)")
## Graus por m/s2 de aceleracao para a frente/tras. Acelerando o nariz sobe; freando o nariz afunda.
@export var pitch_deg_per_mps2: float = 0.5
@export var pitch_max_deg: float = 2.5
@export var pitch_freq_hz: float = 1.2
@export var pitch_damping: float = 0.45

@export_group("Suspensao (lombadas e emendas)")
## Compressao (m) por m/s2 de aceleracao vertical da pista (topo de morro estica, baixada comprime).
@export var heave_m_per_mps2: float = 0.035
@export var heave_max_m: float = 0.12
@export var heave_freq_hz: float = 1.6
@export var heave_damping: float = 0.3
## Pancada da emenda do viaduto/ponte: velocidade vertical (m/s) do tranco a 100 km/h (cresce com a velocidade).
@export var joint_kick_mps: float = 0.22
## Distancia entre emendas no viaduto e nas pontes (m).
@export var joint_spacing_m: float = 32.0

@export_group("Camera")
## Quao rapido a camera alcanca o caminhao (1/s). Menor = mais atraso, sensacao de massa. Antes: 14.
@export var cam_follow_rate: float = 8.0
## Graus de FOV que abrem por m/s (com "Efeitos de velocidade" ligado). Antes: 0,42.
@export var fov_deg_per_mps: float = 0.45
## FOV extra maximo pela velocidade (graus).
@export var fov_max_extra_deg: float = 20.0
## Tremor leve em alta velocidade: comeca nesta velocidade (km/h) e chega no maximo 60 km/h depois. Antes: 100.
@export var speed_shake_from_kmh: float = 95.0
## Tremor maximo em alta velocidade (m). Antes: 0,035.
@export var speed_shake_m: float = 0.045
## Tremor da batida: metros por unidade de impacto (0..1). Antes: 0,25.
@export var impact_shake_m: float = 0.32
## "Congela" a imagem por um instante nas batidas grandes (ms). 0 = desliga. Online so a camera para.
@export var hitstop_ms: float = 75.0
## Batida a partir desta forca (m/s de diferenca de velocidade) ganha o congelamento.
@export var hitstop_min_force: float = 9.0
## Com "Reduzir tremor da camera" ligado, todos os tremores sao multiplicados por isto (e sem congelamento).
@export var reduced_shake_scale: float = 0.25

@export_group("Vibracao do celular")
## Multiplica a duracao das vibracoes (1 = como antes).
@export var haptic_strength: float = 1.0
## Forca do motor de vibracao (0..1; -1 = padrao do aparelho).
@export var haptic_amplitude: float = 0.8

@export_group("Batidas e pneus")
## Fumaca/poeira dos pneus depois de uma batida (s).
@export var crash_tire_smoke_s: float = 0.9
## Poeira no acostamento (a partir desta velocidade, m/s; 0 = desliga).
@export var offroad_dust_from_mps: float = 6.0

@export_group("Som")
## Volume do vento pela velocidade (dB somados; 0 = como antes).
@export var wind_gain_db: float = 2.0
## Vibracao da carroceria (ronco grave que cresce com a velocidade), dB. -80 = desliga.
@export var body_rumble_db: float = -12.0
## Rangido da estrutura ao frear forte (dB). -80 = desliga.
@export var creak_db: float = -9.0
## Pancada grave somada as batidas grandes (dB). -80 = desliga.
@export var impact_thud_db: float = -2.0
## Pancada da emenda do viaduto (dB). -80 = desliga.
@export var joint_thump_db: float = -14.0

static var _current: TruckFeel


## O feel em uso (carregado uma vez). A simulacao, o servidor e a apresentacao leem daqui.
static func current() -> TruckFeel:
	if _current == null:
		_current = load(PATH) as TruckFeel if ResourceLoader.exists(PATH) else null
		if _current == null:
			_current = TruckFeel.new()
	return _current


## Troca o feel em uso (testes; `null` volta ao arquivo).
static func use(f: TruckFeel) -> void:
	_current = f


## Valores de antes da T-219 (comparacao e testes): a simulacao fica igual a de antes.
static func legacy() -> TruckFeel:
	var f := TruckFeel.new()
	f.sim_traction_limit_n = 32000.0
	f.sim_shift_time_s = 0.35
	f.sim_cargo_inertia = 1.0
	f.sim_parts_inertia = 1.0
	f.sim_steer_response = 3.2
	f.sim_lane_gain = 1.9
	f.sim_lane_max_vel = 0.95
	f.sim_lane_mass_exp = 0.0
	return f
