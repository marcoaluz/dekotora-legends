class_name MenuBgHall
extends MenuBackdrop
## Fundo antigo da tela inicial: o galpao da garagem (GarageStage). Mantido para comparar (`--menu-bg=hall`).

var stage: GarageStage


func _ready() -> void:
	stage = GarageStage.new()
	add_child(stage)
	truck = stage.truck
	stage.focus_hero()


func _process(_delta: float) -> void:
	pass


func spawn_truck() -> void:
	stage.refresh_truck()


func refresh_truck() -> void:
	stage.refresh_truck()


func set_body(kind: String) -> void:
	stage.set_body(kind)
	truck = stage.truck


func focus_hero() -> void:
	if stage != null:
		stage.focus_hero()


func focus_default() -> void:
	if stage != null:
		stage.focus_default()
