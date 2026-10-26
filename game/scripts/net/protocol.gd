class_name Protocol
extends RefCounted
## Constantes do protocolo de rede (docs/MULTIPLAYER.md).

const VERSION: int = 16                  # 2 = T-139: eventos de pista no setup; 3 = T-144/T-141: buzina no comando, buzina/freada/empurrao e carro arremessado no snapshot; 4 = T-152: tranco da batida no snapshot; 5 = T-153: trechos de 2 faixas (`lane_sections`) no setup; 6 = T-156: abertura frente a frente (`intro`, `countdown_total` no setup; contagem do servidor mais longa), grid lado a lado e comboio; 7 = T-173: descritor com `horn` (buzina escolhida) e os outros tocam motor/turbo/escape do descritor; 8 = T-183: carro acidentado no snapshot (1 byte por carro); 9 = T-204: abertura nova do duelo (5 s + 3 s de contagem: `countdown_total` 8 s em vez de 9,4 s); 10 = T-207: pedagio com ilha central e fisica (a simulacao mudou: cliente antigo preveria errado); 11 = T-208: abertura de 8,9 s (`countdown_total` 11,9 s) e o servidor so comeca a contar quando todos montaram a corrida (`c_race_loaded`; `s_state(COUNTDOWN)` = o relogio comecou agora); 12 = T-211: descritor com `style` (cor L/R e letreiro) por peca e acoes set_part_color/set_part_sign; 13 = T-214/T-215: estilo com cor das luzes (`led`/`neon`) e 2o nivel do deque (`top`), acoes set_part_light/install_top; 14 = T-218: caminhoes de homenagem (modelos novos no descritor, bots com modelo sorteado no setup, acao buy_body); 15 = T-219: peso do caminhao (aceleracao, troca de faixa e inercia da carga/pecas pelo data/feel/truck_feel.tres; histerese do bot preso atras de um lento): a simulacao mudou, cliente antigo preveria errado; 16 = T-231: pecas da oficina lote 2 (para-choque traseiro com lanternas, foguete, contorno do bau; encaixes novos `rocket`/`box_light_*`) e bots com pecas sorteadas pela semente (descritor e massa mudaram)
const DEFAULT_PORT: int = 24600
const MAX_PLAYERS: int = 4
const COMMAND_RATE: float = 30.0          # comandos por segundo (cliente -> servidor)
const SNAPSHOT_RATE: float = 20.0         # snapshots por segundo (servidor -> clientes)
const SERVER_TICK: float = 1.0 / 30.0     # igual a RaceSim.FIXED_DT
const COUNTDOWN_SECONDS: float = 3.0
## T-208: o servidor espera cada jogador montar a corrida (c_race_loaded) antes de contar; no maximo isto (celular lento).
const LOAD_WAIT_MAX: float = 30.0
const ROOM_CODE_LENGTH: int = 6
const ROOM_CODE_ALPHABET: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const INTERPOLATION_DELAY: float = 0.1    # outros caminhoes desenhados 100 ms no passado

enum RoomState { LOBBY, COUNTDOWN, RACING, FINISHED }
enum DamageMode { REAL, RACE_ONLY }

static func default_rules() -> Dictionary:
	return {
		"route": "kanto_1_coast",
		"damage": DamageMode.REAL,       # "Real" grava o dano no perfil; "Só na corrida" nao grava
		"bots": 1,                       # bots para completar o grid (ate 4 caminhoes no total)
		"traffic": 1,                    # TrafficSim.Density
		"night": true,
		"events": true,                  # T-139: eventos de pista (fixos da rota + sorteados pelo servidor)
	}


static func make_room_code(rng: RandomNumberGenerator) -> String:
	var s: String = ""
	for i in ROOM_CODE_LENGTH:
		s += ROOM_CODE_ALPHABET[rng.randi_range(0, ROOM_CODE_ALPHABET.length() - 1)]
	return s
