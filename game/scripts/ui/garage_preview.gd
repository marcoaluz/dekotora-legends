class_name GaragePreview
extends RefCounted
## Previa da garagem (T-171): mostra no caminhao uma peca (ou uma cor) ANTES de comprar/equipar, sem tocar no
## perfil nem no dinheiro. Guarda so a escolha temporaria; o palco (GarageStage.refresh_truck) pede a montagem
## "como ficaria" aqui. Sair do cartao/encaixe/aba chama clear() e o caminhao volta ao que esta equipado.
## Mecanica (motor, turbo, escape, upgrades) nao tem peca visivel: a previa dela continua sendo o texto do efeito.

## Peca em previa ("" = nenhuma). Substitui a peca instalada no MESMO encaixe.
var part_id: String = ""
## Cor em previa ("" = nenhuma; ex.: cor ainda travada por Fama).
var paint_hex: String = ""


func active() -> bool:
	return part_id != "" or paint_hex != ""


func clear() -> void:
	part_id = ""
	paint_hex = ""


## Mostra a peca `id` (a cor em previa sai: uma previa por vez).
func set_part(id: String) -> void:
	part_id = id
	paint_hex = ""


func set_paint(hex: String) -> void:
	paint_hex = hex.to_lower()
	part_id = ""


## Encaixe da peca em previa ("" sem peca).
func slot(gs: Node) -> String:
	var d: PartDef = gs.part(part_id) if part_id != "" else null
	return String(d.slot) if d != null else ""


## Pecas que o caminhao mostra: as instaladas, com a peca da previa no lugar da do mesmo encaixe.
func loadout(gs: Node) -> Array[PartDef]:
	var defs: Array[PartDef] = gs.installed_part_defs()
	var d: PartDef = gs.part(part_id) if part_id != "" else null
	if d == null:
		return defs
	var out: Array[PartDef] = []
	for x in defs:
		if x.slot != d.slot:
			out.append(x)
	out.append(d)
	return out


## Cor que o caminhao mostra (a da previa ou a do perfil).
func paint(gs: Node) -> Color:
	return Color(paint_hex if paint_hex != "" else String(gs.profile.get("paint", "#e9eef5")))


## Depois de qualquer mudanca no perfil: previa que virou realidade (peca instalada, cor aplicada) ou que nao
## existe mais acaba sozinha. Devolve true se acabou.
func settle(gs: Node) -> bool:
	if part_id != "":
		var d: PartDef = gs.part(part_id)
		if d == null or gs.installed_id(String(d.slot)) == part_id:
			part_id = ""
			return true
	if paint_hex != "" and String(gs.profile.get("paint", "")).to_lower() == paint_hex:
		paint_hex = ""
		return true
	return false
