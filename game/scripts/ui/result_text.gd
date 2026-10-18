class_name ResultText
extends RefCounted
## Frases da tela de resultado (T-138): explicam em portugues simples o que aconteceu na corrida, a partir do
## Dictionary de RaceRules.build_result (dados da T-102: perda de carga, batidas, encostadas, pecas).
## Funcoes puras (testaveis sem tela); textos em game/data/i18n/pt-BR.json.


## Relogio m:ss (prazo, folga).
static func clock(t: float) -> String:
	var s: int = maxi(roundi(t), 0)
	return "%d:%02d" % [s / 60, s % 60]


## Tempo de prova m:ss,cc.
static func race_clock(t: float) -> String:
	return ("%d:%05.2f" % [int(t) / 60, fmod(t, 60.0)]).replace(".", ",")


## "1 batida" / "3 batidas" (chave .one / .many no pt-BR.json).
static func count(n: int, key: String) -> String:
	return Tr.t(key + (".one" if n == 1 else ".many"), [n])


## Titulo grande do resultado.
static func title(res: Dictionary) -> String:
	match String(res.get("outcome", "win")):
		"win":
			return Tr.t("result.title_win", [int(res.get("position", 1))])
		"lose_rival":
			return Tr.t("result.title_lose")
	return Tr.t("result.title_timeout")


## Frases em ordem: desfecho, carga, pecas, fama.
static func lines(res: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var outcome: String = String(res.get("outcome", "win"))
	var won: bool = outcome == "win"
	match outcome:
		"win":
			out.append(Tr.t("result.why_win", [int(res.get("position", 1)), clock(float(res.get("time_left", 0.0)))]))
		"lose_rival":
			out.append(Tr.t("result.why_lose", [int(res.get("position", 2))]))
		_:
			out.append(Tr.t("result.why_timeout", [clock(float(res.get("deadline", 0.0)))]))
	out.append(cargo_line(res, won))
	out.append(parts_line(res.get("parts", []) as Array))
	if won:
		out.append(Tr.t("result.why_fame", [int(res.get("fame", 0)), count(int(res.get("overtakes", 0)), "result.overtakes")]))
	else:
		out.append(Tr.t("result.why_no_fame"))
	return out


## Perda de carga: quanto da carga estragou, por que (batidas, encostadas, dano no bau) e quanto custou.
static func cargo_line(res: Dictionary, won: bool) -> String:
	var loss: float = float(res.get("cargo_loss", 0.0))
	if loss <= 0.0005:
		return Tr.t("result.cargo_ok")
	var pct: int = maxi(roundi(loss / TruckSim.MAX_CARGO_LOSS * 100.0), 1)        # % da carga estragada
	var causes: PackedStringArray = []
	var hits: int = int(res.get("cargo_hits", 0))
	var touches: int = int(res.get("cargo_touches", 0))
	if hits > 0:
		causes.append(count(hits, "result.hits"))
	if touches > 0:
		causes.append(count(touches, "result.touches"))
	if float(res.get("cargo_from_damage", 0.0)) > 0.0005:
		causes.append(Tr.t("result.cause_box"))
	var why: String = Tr.t("result.cause_hits") if causes.is_empty() else (" " + Tr.t("result.and") + " ").join(causes)
	var text: String = Tr.t("result.cargo_lost", [pct, why])
	if won:
		text += " " + Tr.t("result.cargo_cost", [Tr.yen(int(res.get("cargo_loss_yen", 0)))])
	if String(res.get("cargo_trait", "normal")) == "fragile":
		text += " " + Tr.t("result.cargo_fragile")
	return text


## Pecas quebradas/amassadas: quantas e o que fazer.
static func parts_line(parts: Array) -> String:
	var broken: int = 0
	var dent: int = 0
	for p in parts:
		match String((p as Dictionary).get("state", "ok")):
			"broken":
				broken += 1
			"dent":
				dent += 1
	if broken == 0 and dent == 0:
		return Tr.t("result.parts_ok") if not parts.is_empty() else Tr.t("result.parts_none")
	var bits: PackedStringArray = []
	if broken > 0:
		bits.append(count(broken, "result.broken"))
	if dent > 0:
		bits.append(count(dent, "result.dented"))
	return Tr.t("result.parts_damaged", [(" " + Tr.t("result.and") + " ").join(bits)])


## Estado da peca para a tela: "inteira" / "amassada" / "quebrada".
static func state_name(state: String) -> String:
	return Tr.t("part_state." + (state if state in ["ok", "dent", "broken"] else "ok"))


static func state_color(state: String) -> Color:
	match state:
		"broken":
			return UiTheme.BAD
		"dent":
			return UiTheme.WARN
	return UiTheme.GOOD
