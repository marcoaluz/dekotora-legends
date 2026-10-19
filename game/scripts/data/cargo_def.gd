class_name CargoDef
extends Resource
## Tipo de carga dos contratos do Mercado de fretes: faixa de peso, multiplicador do pagamento e fragilidade
## (multiplica o dano que a carga recebe nas batidas; 1,0 = normal, 2,0 = estraga o dobro).

@export var id: StringName
@export var display_key: String = ""
@export var icon: String = "package"              # icone (assets/ui/icons)
@export var weight_min_t: float = 4.0
@export var weight_max_t: float = 10.0
@export var pay_mult: float = 1.0
@export var fragility: float = 1.0
## fragile = perde mais prêmio por batida · heavy = acelera menos · perishable = prazo 20% menor · normal
@export var trait_kind: StringName = &"normal"
## Carroceria que a carga exige (T-145): &"any" = qualquer uma; &"box" = bau fechado (eletronicos, refrigerados, louca);
## &"open" = carroceria aberta/graneleira (granel: graos, brita). Ver BodyDef.cargo_kind e docs/DECISOES.md.
@export var needs: StringName = &"any"
