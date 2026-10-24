class_name DeckStack
extends RefCounted
## Deque de 2 niveis (T-215): canhoes embaixo + caixa em cima, ou caixa embaixo + canhoes em cima. A peca de cima fica
## no encaixe extra "andon_top" do perfil (a de baixo continua em "andon"). So conta (aparece, pesa, vai para a rede)
## quando a dupla CABE no caminhao atual: formato certo (SocketSeat.stack_pair_ok) e a conta geometrica (StackFit: caixa
## do encaixe, altura `stack_max_y`, zonas protegidas, apoio), guardada numa tabela por caminhao. Codigo puro: usado pelo perfil, pela
## garagem, pelo TruckNode e pelo teste de encaixe.

const SLOT := "andon_top"            # chave do perfil (installed) da peca de cima
const LOWER_SLOT := "andon"


## Dados de encaixe do caminhao (carroceria + cabine).
static func truck_data(body: String, cab: String) -> Dictionary:
	return TruckSockets.for_model(TruckNode.model_path(body, cab))


## A peca de cima (id do catalogo de acessorios) cabe em cima da de baixo neste caminhao?
static func fits(data: Dictionary, lower_acc: String, upper_acc: String) -> bool:
	if lower_acc == "" or upper_acc == "" or lower_acc == upper_acc:
		return false
	var cat: AccessoryCatalog = AccessoryCatalog.get_instance()
	var lo: Dictionary = cat.entry(lower_acc)
	var up: Dictionary = cat.entry(upper_acc)
	if lo.is_empty() or up.is_empty() or not SocketSeat.stack_pair_ok(lo, up):
		return false
	var tab: Dictionary = StackFit.table()
	var stem: String = String(data.get("model", ""))
	if tab.has(stem):                                # tabela da conta geometrica (StackFit, tools_dev/gen_stack_fit.gd)
		return (tab[stem] as Dictionary).has(StackFit.key(lower_acc, upper_acc))
	return SocketSeat.stack_fits(data, lo, up, TruckSockets.fit_scale(data, lo))   # (sem tabela: so a altura)


## A peca de baixo aceita alguma peca em cima (pelo formato)?
static func accepts_top(lower_acc: String) -> bool:
	var info: Dictionary = SocketSeat.stack_info(AccessoryCatalog.get_instance().entry(lower_acc))
	return not info.is_empty() and bool(info.get("base", false))
