class_name DamageModel
extends RefCounted
## Dano por zona (docs/BALANCEAMENTO.md, "Distribuicao do dano"):
##  1) o impacto acerta uma zona (front, rear, left, right);
##  2) as pecas da zona absorvem ate zerar a durabilidade, da mais externa para a mais interna;
##  3) a sobra vai 50% para o sistema da zona (frente->motor, laterais->direcao, traseira->carga)
##     e 50% para a carga;
##  4) motor ferido: potencia x (0,5 + 0,5 x saude); direcao ferida: puxa 0,1 x (1 - saude) para um lado.
## Uma "peca" aqui e um Dictionary: {id, zones:[...], weight, max, dur, fame}. A P41 gera isso a partir de PartDef.

const K_DAMAGE: float = 4.0                 # BALANCEAMENTO: k_dano
const POINTS_PER_HEALTH: float = 10.0       # pontos de dano que tiram 1 de saude (0..100) de um sistema
const ZONE_SYSTEM: Dictionary = {"front": "engine", "left": "steering", "right": "steering", "rear": "cargo"}


static func make_part(id: String, zones: Array, weight: float, durability: float, fame: int = 0) -> Dictionary:
	return {"id": id, "zones": zones, "weight": weight, "max": durability, "dur": durability, "fame": fame}


## dano_impacto = k_dano x |delta v| x massa_do_outro / 1000
static func impact_damage(delta_v: float, other_mass: float) -> float:
	return K_DAMAGE * absf(delta_v) * other_mass / 1000.0


## Aplica `amount` de dano na zona. Devolve a lista de ids de pecas que QUEBRARAM neste impacto.
static func apply_impact(truck: TruckSim, zone: String, amount: float) -> Array[String]:
	var broken: Array[String] = []
	var remaining: float = amount
	for part in truck.loadout:      # ordem da lista = da mais externa para a mais interna
		if remaining <= 0.0:
			break
		if bool(part["broken"]) or not (zone in part["zones"]) or float(part["max"]) <= 0.0:
			continue
		var absorbed: float = minf(float(part["dur"]), remaining)
		part["dur"] = float(part["dur"]) - absorbed
		remaining -= absorbed
		if float(part["dur"]) <= 0.0:
			part["dur"] = 0.0
			part["broken"] = true
			truck.mass -= float(part["weight"])      # a peca cai: o caminhao fica mais leve
			broken.append(String(part["id"]))
	if remaining > 0.0:
		var system: String = String(ZONE_SYSTEM.get(zone, "cargo"))
		_hurt_system(truck, system, remaining * 0.5)
		_hurt_system(truck, "cargo", remaining * 0.5)
	truck.refresh_damage_effects()
	return broken


static func _hurt_system(truck: TruckSim, system: String, points: float) -> void:
	truck.systems[system] = maxf(float(truck.systems[system]) - points / POINTS_PER_HEALTH, 0.0)


## Estado "ok" / "dent" / "broken" de uma peca, para a apresentacao (camadas do TruckView).
static func part_state(part: Dictionary) -> String:
	if bool(part["broken"]):
		return "broken"
	var ratio: float = float(part["dur"]) / maxf(float(part["max"]), 0.001)
	return "dent" if ratio < 0.6 else "ok"


## Saude de uma zona (0..1) para o HUD/garagem: media ponderada das pecas da zona; se nao ha
## pecas, usa a saude do sistema da zona.
static func zone_health(truck: TruckSim, zone: String) -> float:
	var cur: float = 0.0
	var mx: float = 0.0
	for part in truck.loadout:
		if zone in part["zones"] and float(part["max"]) > 0.0:
			cur += float(part["dur"])
			mx += float(part["max"])
	if mx > 0.0:
		return cur / mx
	return float(truck.systems[String(ZONE_SYSTEM.get(zone, "cargo"))]) / 100.0
