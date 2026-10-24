class_name RetiredParts
extends RefCounted
## Pecas que SAIRAM do jogo (T-215, pedido do Marco): as pecas antigas de teto da cabine, que ficavam na frente do deque
## novo. Os .tres e os modelos continuam no projeto (precos para o reembolso, saves antigos, rede), mas a loja, a garagem,
## os rivais e a montagem nao usam mais. Perfil antigo com uma delas: reembolso do preco CHEIO em ¥ e a peca sai do
## perfil (GameState.migrate_profile; decisao em docs/DECISOES.md).

const IDS: Array[String] = ["roof_lights_row", "roof_lights_crown", "roof_marker_small_lamps", "marker_crown_dx",
	"antenna_decor_mount", "roof_light_frame_halo", "fumi_wing", "andon_kanji", "andon_ichiban_dx"]
## Encaixes que so essas pecas usavam (somem da garagem junto).
const SLOTS: Array[String] = ["roof_lights", "roof_frame", "roof_ornament", "roof_wing"]


static func has(id: String) -> bool:
	return IDS.has(id)
