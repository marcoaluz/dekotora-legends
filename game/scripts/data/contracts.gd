class_name Contracts
extends RefCounted
## Contratos do Mercado de fretes (codigo puro, sem tela: roda nos testes).
## Um contrato = trecho (RouteDef) + origem/destino (cidades do trecho) + tipo de carga (CargoDef) + peso + valor.
## Regras (docs/DECISOES.md):
## - capacidade do bau (BodyDef.capacity_t): Canter 4 t, leve 6 t, medio 12 t, longo 16 t (mais pesado nao pode ser aceito);
## - valor = frete do trecho x multiplicador da carga x (0,8 + 0,6 x peso relativo na faixa da carga), de 50 em 50;
## - o peso entra na massa do caminhao na corrida (mais pesado = mais lento) e a fragilidade multiplica o dano na carga;
## - o quadro e sorteado com semente: muda ao concluir um frete ou ao tocar ATUALIZAR.

const CAPACITY_T: Dictionary = {"leve": 6.0, "base": 12.0, "longo": 16.0, "canter": 4.0}   # reserva (sem data/bodies)
const PER_ROUTE: int = 2                     # contratos por trecho liberado
const CARGO_DIR := "res://data/cargo/"
const PERISHABLE_DEADLINE: float = 0.8       # perecivel: prazo 20% menor


static func capacity_t(body: String) -> float:
	var d: BodyDef = BodyDef.find(body)
	return d.capacity_t if d != null else float(CAPACITY_T.get(body, 12.0))


static func all_cargos() -> Array[CargoDef]:
	var out: Array[CargoDef] = []
	for f in DirAccess.get_files_at(CARGO_DIR):
		var name: String = f.trim_suffix(".remap")
		if name.ends_with(".tres"):
			out.append(load(CARGO_DIR + name) as CargoDef)
	out.sort_custom(func(a: CargoDef, b: CargoDef) -> bool: return String(a.id) < String(b.id))
	return out


static func reward(route: RouteDef, cargo: CargoDef, weight_t: float) -> int:
	var span: float = maxf(cargo.weight_max_t - cargo.weight_min_t, 0.001)
	var rel: float = clampf((weight_t - cargo.weight_min_t) / span, 0.0, 1.0)
	var v: float = float(route.freight) * cargo.pay_mult * (0.8 + 0.6 * rel)
	return int(round(v / 50.0)) * 50


## Gera o quadro: PER_ROUTE contratos para cada trecho liberado (sempre pelo menos um que caiba no bau
## informado). Determinístico para a mesma semente.
static func generate(seed_: int, routes: Array[RouteDef], unlocked: Callable, body: String) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var cargos: Array[CargoDef] = all_cargos()
	var cap: float = capacity_t(body)
	var out: Array[Dictionary] = []
	for r in routes:
		if not bool(unlocked.call(r)):
			continue
		for k in PER_ROUTE:
			var cargo: CargoDef = cargos[rng.randi() % cargos.size()]
			var hi: float = cargo.weight_max_t
			if k == 0:                                   # o primeiro de cada trecho sempre cabe no bau atual
				while cargo.weight_min_t > cap:
					cargo = cargos[rng.randi() % cargos.size()]
				hi = minf(hi, cap)
			var w: float = snappedf(rng.randf_range(cargo.weight_min_t, hi), 0.5)
			var pl: PackedStringArray = r.places if r.places.size() >= 2 else PackedStringArray(["Origem", "Destino"])
			var a: int = rng.randi() % pl.size()
			var b: int = (a + 1 + rng.randi() % (pl.size() - 1)) % pl.size()
			out.append({
				"id": "%s_%d_%d" % [r.id, seed_ % 100000, k], "route": String(r.id),
				"origin": pl[a], "destination": pl[b], "cargo": String(cargo.id), "weight_t": w,
				"reward": reward(r, cargo, w), "fragility": cargo.fragility, "trait": String(cargo.trait_kind),
				"deadline_s": roundf(r.deadline() * (PERISHABLE_DEADLINE if cargo.trait_kind == &"perishable" else 1.0)),
			})
	return out


## Descritor extra para a simulacao (TruckConfig.apply): massa e fragilidade da carga do contrato.
static func sim_fields(contract: Dictionary) -> Dictionary:
	if contract.is_empty():
		return {}
	return {"cargo_kg": float(contract["weight_t"]) * 1000.0, "cargo_fragility": float(contract.get("fragility", 1.0)),
		"cargo_trait": String(contract.get("trait", "normal"))}
