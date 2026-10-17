class_name RaceRules
extends RefCounted
## Regras de pontuacao e pagamento (GDD secao 3 + BALANCEAMENTO). Funcoes puras e testaveis.
##
## pagamento = frete x integridade_da_carga + bonus_de_posicao(% do frete) + bonus_de_Fama(Fama x FAME_TO_YEN)
## Fama_corrida = soma(fama das pecas INTEIRAS) x fator_posicao + ultrapassagens x FAME_PER_OVERTAKE

const POSITION_BONUS: Array[float] = [0.5, 0.2, 0.05, 0.0]   # 1o..4o (BALANCEAMENTO: bonus de posicao)
const FAME_FACTOR: Array[float] = [1.0, 0.8, 0.6, 0.5]       # fator_posicao (BALANCEAMENTO)
const FAME_PER_OVERTAKE: float = 2.0                          # suposicao: ver docs/DECISOES.md
const FAME_TO_YEN: int = 50                                   # suposicao: 1 Fama = 50 yen de bonus

static func _idx(position: int) -> int:
	return clampi(position - 1, 0, 3)


static func position_bonus(freight: int, position: int) -> int:
	return roundi(float(freight) * POSITION_BONUS[_idx(position)])


static func fame_gain(intact_fame: float, position: int, overtakes: int) -> int:
	return roundi(intact_fame * FAME_FACTOR[_idx(position)] + float(overtakes) * FAME_PER_OVERTAKE)


## Desfecho: "win" (1o E dentro do prazo), "lose_rival" (chegou depois do rival), "timeout" (acabou o prazo).
static func outcome(truck: TruckSim, position: int) -> String:
	if truck.timed_out or truck.finish_position == 0:
		return "timeout"
	return "win" if position == 1 else "lose_rival"


## Perda do premio por carga estragada: 0..40% (TruckSim.MAX_CARGO_LOSS) conforme a integridade.
static func cargo_loss(cargo_integrity: float) -> float:
	return TruckSim.MAX_CARGO_LOSS * (1.0 - clampf(cargo_integrity, 0.0, 1.0))


static func payment(freight: int, cargo_integrity: float, position: int, fame: int) -> int:
	var base: int = roundi(float(freight) * (1.0 - cargo_loss(cargo_integrity)))
	return base + position_bonus(freight, position) + fame * FAME_TO_YEN


## Fama das pecas ainda inteiras (nao quebradas) de um caminhao.
static func intact_fame(truck: TruckSim) -> float:
	var total: float = 0.0
	for p in truck.loadout:
		if not bool(p["broken"]):
			total += float(p["fame"])
	return total


## Resultado completo de um caminhao ao terminar. `position` = 1..4.
static func build_result(truck: TruckSim, position: int, freight: int, finish_time: float, deadline: float = 0.0) -> Dictionary:
	var out: String = outcome(truck, position)
	var won: bool = out == "win"
	var fame: int = fame_gain(intact_fame(truck), position, truck.overtakes) if won else 0
	var shown_time: float = finish_time if finish_time >= 0.0 else deadline
	var parts: Array[Dictionary] = []
	for p in truck.loadout:
		parts.append({"id": p["id"], "state": DamageModel.part_state(p), "dur": p["dur"], "max": p["max"]})
	return {
		"position": position,
		"time": shown_time,
		"outcome": out,
		"deadline": deadline,
		"time_left": maxf(deadline - shown_time, 0.0) if deadline > 0.0 else 0.0,
		"cargo": truck.cargo_integrity(),
		"cargo_loss": truck.cargo_loss(),
		"cargo_loss_yen": roundi(float(freight) * truck.cargo_loss()),
		"cargo_trait": truck.cargo_trait,
		"freight": freight,
		"position_bonus": position_bonus(freight, position) if won else 0,
		"fame": fame,
		"pay": payment(freight, truck.cargo_integrity(), position, fame) if won else 0,
		"overtakes": truck.overtakes,
		"parts": parts,
		"systems": truck.systems.duplicate(),
	}
