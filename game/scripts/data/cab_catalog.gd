class_name CabCatalog
extends RefCounted
## Cabines do caminhao grande (T-129: so cabines vindas de modelos de arquivo, Royalty Free, marca apagada).
## Os ids aparecem no perfil (`profile.cab`), no descritor de rede (`"cab"`) e no nome do .glb
## (`dekotora_truck_<bau>_<cabine>.glb`). Codigo puro: o servidor tambem usa (sem render).

## Ordem da lista da garagem. A primeira e a padrao dos perfis novos.
const IDS: Array[String] = ["chata", "jac", "curta", "americana"]
## Cabine dos perfis novos e de qualquer id desconhecido: a "cara chata" (cab-over japonesa grande com
## dormitorio, a mais proxima do Dekotora classico).
const DEFAULT: String = "chata"
## Cabines feitas por codigo, retiradas na T-129 -> a nova de visual mais parecido.
## padrao (arredondada, Volvo FH), classica (quadrada) e alta (teto alto/dormitorio) -> chata (cab-over grande);
## aero (para-brisa inclinado, moderna) -> jac (cabine japonesa moderna).
const LEGACY: Dictionary = {"padrao": "chata", "classica": "chata", "alta": "chata", "aero": "jac"}


## Id valido de cabine para qualquer valor salvo (perfil antigo, rede, argumento de depuracao).
static func normalize(id: Variant) -> String:
	var s: String = String(id) if id != null else ""
	if s in IDS:
		return s
	return String(LEGACY.get(s, DEFAULT))


## O id ja e de uma cabine que existe hoje?
static func is_valid(id: String) -> bool:
	return id in IDS
