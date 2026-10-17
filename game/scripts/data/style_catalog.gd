class_name StyleCatalog
extends RefCounted
## Pintura e adesivos: pontos de DESTAQUE e catalogo (docs/BALANCEAMENTO.md, "Nota de destaque").
## O destaque total do caminhao = pecas inteiras + escape + pintura + adesivos (GameState.destaque()).

## Pinturas: pontos de destaque e Fama minima para liberar. A primeira e a de fabrica (0 ponto).
const PAINTS: Array[Dictionary] = [
	{"id": "branco", "hex": "#e9eef5", "points": 0, "fame_required": 0},
	{"id": "grafite", "hex": "#2b2f3a", "points": 3, "fame_required": 0},
	{"id": "vermelho", "hex": "#c8202f", "points": 6, "fame_required": 10},
	{"id": "azul", "hex": "#1d3f8a", "points": 6, "fame_required": 10},
	{"id": "rosa", "hex": "#ff2e88", "points": 9, "fame_required": 30},
	{"id": "jade", "hex": "#1fa37a", "points": 9, "fame_required": 30},
	{"id": "dourado", "hex": "#f0b83a", "points": 14, "fame_required": 60},
]
const DECAL_POINTS: int = 6          # cada adesivo colocado soma isto (tamanho e cor nao mudam a nota)
const MAX_DECALS: int = 4            # um por lugar: lateral esquerda, lateral direita, traseira, cabine


static func paint_points(hex: String) -> int:
	for p in PAINTS:
		if String(p["hex"]).to_lower() == hex.to_lower():
			return int(p["points"])
	return 4                          # cor fora da lista (arquivo antigo/edicao manual)


static func decal_points(decals: Array) -> int:
	return mini(decals.size(), MAX_DECALS) * DECAL_POINTS
