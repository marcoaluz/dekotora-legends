class_name Protocol
extends RefCounted
## Constantes do protocolo de rede (docs/MULTIPLAYER.md).

const VERSION: int = 8                   # 2 = T-139: eventos de pista no setup; 3 = T-144/T-141: buzina no comando, buzina/freada/empurrao e carro arremessado no snapshot; 4 = T-152: tranco da batida no snapshot; 5 = T-153: trechos de 2 faixas (`lane_sections`) no setup; 6 = T-156: abertura frente a frente (`intro`, `countdown_total` no setup; contagem do servidor mais longa), grid lado a lado e comboio; 7 = T-173: descritor com `horn` (buzina escolhida) e os outros tocam motor/turbo/escape do descritor; 8 = T-183: carro acidentado no snapshot (1 byte por carro)
const DEFAULT_PORT: int = 24600
const MAX_PLAYERS: int = 4
const COMMAND_RATE: float = 30.0          # comandos por segundo (cliente -> servidor)
const SNAPSHOT_RATE: float = 20.0         # snapshots por segundo (servidor -> clientes)
const SERVER_TICK: float = 1.0 / 30.0     # igual a RaceSim.FIXED_DT
const COUNTDOWN_SECONDS: float = 3.0
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
