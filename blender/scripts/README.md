# Scripts do Blender

A arte do jogo nasce aqui. Leia `docs/PIPELINE_ARTE_BLENDER.md`.

Os scripts serão criados pelo Claude a partir do prompt **P10**:

| Script | Prompt | Faz |
| --- | --- | --- |
| `lib/*.py` | P10 | Biblioteca comum (cena, materiais, formas, câmera, render, pixelização, exportação, dano, paleta) |
| `test_lib.py` | P10 | Teste rápido da biblioteca |
| `build_truck_base.py`, `render_truck.py` | P11 | Caminhão base e render dos 5 ângulos |
| `parts/*.py` | P12, P40 | Uma peça por arquivo |
| `build_roadside_*.py` | P23, P46 | Cenário e beira de estrada |
| `build_all.py` | P40 | Regenera toda a arte |

Rodar: `blender -b -P blender/scripts/<script>.py -- <argumentos>`
