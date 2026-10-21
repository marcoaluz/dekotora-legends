class_name GarageHorns
extends RefCounted
## Garage, MECHANICS tab (T-173): horn choice (free, sound only) and the "LISTEN" previews of engine/turbo/exhaust.
## Kept out of GarageShop so the shop file stays small; the layout only adds a section at the end of the tab.


## Engine rev of the current truck with `changes` ({"engine"|"turbo"|"exhaust": id}) applied.
static func preview_engine(gs: Node, changes: Dictionary) -> void:
	var desc: Dictionary = {"engine": String(gs.profile["engine"]), "turbo": String(gs.profile["turbo"]), "exhaust": String(gs.profile["exhaust"])}
	desc.merge(changes, true)
	SoundPreview.engine(gs.get_node("/root/AudioBus"), EngineSounds.from_descriptor(desc))


## Row: the card's main button (expands) + a small LISTEN button.
static func with_listen(main: Button, on_listen: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(main)
	var lb: Button = GarageShop.small_button(Tr.t("garage.listen"), 86)
	lb.pressed.connect(on_listen)
	row.add_child(lb)
	return row


## HORN section: one button per horn; pressing it picks the horn and plays it.
static func build(box: VBoxContainer, gs: Node) -> void:
	box.add_child(UiKit.heading(Tr.t("garage.horn_title").to_upper(), 18, UiTheme.PINK))
	box.add_child(GarageShop.wl(Tr.t("garage.horn_hint"), 12, UiTheme.TEXT_DIM))
	var cur: String = String(gs.profile.get("horn", HornCatalog.AUTO))
	if not HornCatalog.is_valid(cur):
		cur = HornCatalog.AUTO
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	var ids: Array[String] = [HornCatalog.AUTO]
	ids.append_array(HornCatalog.IDS)
	for id in ids:
		var on: bool = id == cur
		var b: Button = UiTheme.button(Tr.t(HornCatalog.label_key(id)) + ("  ✔" if on else ""), Vector2(0, 38))
		b.add_theme_font_size_override("font_size", 15)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_stylebox_override("normal", UiTheme.box(Color(1, 0.18, 0.53, 0.2) if on else Color(1, 1, 1, 0.04), UiTheme.PINK if on else Color(1, 1, 1, 0.12), 1, 8, 8))
		b.pressed.connect(func() -> void:
			if not on:
				gs.set_horn(id)
			SoundPreview.horn(gs.get_node("/root/AudioBus"), gs.installed_horn()))
		grid.add_child(b)
