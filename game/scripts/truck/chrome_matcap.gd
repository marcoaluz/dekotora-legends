class_name ChromeMatcap
extends RefCounted
## Cromo por matcap (V6): o Compatibility nao tem reflexo de tela e o ceu noturno e quase preto, entao o
## cromo "real" ficava escuro. Aqui o cromo le uma esfera pintada com o ambiente (textures/matcap_chrome_*.png,
## gerada por blender/scripts/build_matcaps.py) pela normal vista da camera: sempre brilha, custa uma textura.
## Modos: "night" (postes de sodio, neon), "day" (ceu azul, sol) e "studio" (garagem, neutro). Troca os materiais "chrome" e "paint_gold".
## Soma ao cromo PBR (nunca fica mais escuro que antes).

const SHADER := """
shader_type spatial;
uniform sampler2D matcap : source_color, filter_linear, repeat_disable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float strength = 1.0;
void fragment() {
	vec3 n = normalize(NORMAL);                    // espaco da camera
	vec2 uv = vec2(n.x, -n.y) * 0.49 + 0.5;
	vec3 m = texture(matcap, uv).rgb * tint;
	ALBEDO = vec3(0.9) * tint;                     // continua PBR: brilho das luzes reais (farois, postes)
	METALLIC = 1.0;
	ROUGHNESS = 0.12;
	EMISSION = m * strength;                       // + o ambiente pintado (cidade a noite / ceu de dia)
}
"""
const TARGETS: Dictionary = {"chrome": Color(1, 1, 1), "paint_gold": Color("#f6c453")}
## Forca do ambiente pintado por modo. "studio" = garagem (T-138): cinza neutro com softbox, sem o azul da noite.
const STRENGTH: Dictionary = {"night": 2.2, "day": 0.45, "studio": 0.95}

static var _cache: Dictionary = {}


static func material(mode: String, target: String) -> ShaderMaterial:
	var key: String = mode + "/" + target
	if _cache.has(key):
		return _cache[key]
	var sh := Shader.new()
	sh.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.resource_name = target                       # mantem o nome: swap_material("chrome", "steel") continua valendo
	m.set_shader_parameter("matcap", load("res://assets/textures/matcap_chrome_%s.png" % mode))
	m.set_shader_parameter("tint", TARGETS.get(target, Color.WHITE))
	m.set_shader_parameter("strength", float(STRENGTH.get(mode, 0.45)))
	_cache[key] = m
	return m


## Troca os materiais cromados/dourados de todas as malhas abaixo de `root`.
static func apply(root: Node, mode: String) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			var cur: Material = m.get_active_material(s)
			if cur != null and TARGETS.has(cur.resource_name) and not (cur is ShaderMaterial):
				m.set_surface_override_material(s, material(mode, cur.resource_name))
