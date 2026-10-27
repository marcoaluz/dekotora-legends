class_name LightPatterns
extends RefCounted
## Padroes de pisca das luzinhas de marcacao (fileiras do bau, cabine, andon, pecas). Um unico ShaderMaterial por cor
## (sem luz real, sem script por lampada): o padrao e calculado no shader pela posicao da lampada no modelo, entao o
## custo e o mesmo de um material comum. Escolha na garagem: GameState.profile["light_pattern"].

const IDS: Array[String] = ["steady", "sequential", "alternate", "breathing"]
## Materiais de luz que piscam; lamp_red (lanterna/freio) e lamp_white (farol) ficam fixos.
const ANIMATED: Array[String] = ["lamp_amber", "lamp_yellow", "lamp_pink", "lamp_cyan", "lamp_green", "lamp_blue", "lamp_violet",
	"lamp_orange", "lamp_ice", "lamp_lime", "lamp_ruby"]
## T-231: luzes que acendem a noite mas NAO piscam (lanterna das pecas da traseira); de dia ficam vermelho-escuro.
const STEADY_LIT: Array[String] = ["lamp_tail"]
const STEADY_FLOOR: float = 0.3
## T-214: sufixo do material de LED com lente (DecoStyle): o shader desenha a lente pela UV 0..1 de cada LED.
const LENS_SUFFIX := "@lens"
## T-239: freio = todas as luzes ficam vermelhas e fixas (sem padrao). BRAKE_LEVEL = brilho minimo com o freio (de dia as
## luzes estao apagadas em 0,12: freando elas acendem de verdade); a lanterna (STEADY_LIT) ainda ganha BRAKE_GAIN.
const BRAKE_COLOR := Color(1.0, 0.07, 0.04)
const BRAKE_LEVEL: float = 0.75
const BRAKE_GAIN_TAIL: float = 1.5

const SHADER := """
shader_type spatial;
render_mode unshaded;
uniform vec4 base_color : source_color = vec4(1.0, 0.7, 0.2, 1.0);
uniform float energy = 1.5;
uniform int pattern = 0;          // 0 fixas, 1 sequencial, 2 alternado, 3 respirando
uniform float level = 1.0;        // brilho geral: 1 noite/tunel, ~0.4 previa de dia, ~0.12 apagadas
uniform float speed = 1.0;
uniform float lens = 0.0;         // T-214: LED com lente (UV 0..1 por LED): centro forte, borda mais escura
uniform float floor_level = 0.0;  // T-231: brilho minimo (lanterna: lente vermelha de dia)
uniform float brake = 0.0;        // T-239: 0..1 freio (cor vai para brake_color, padrao para fixo, brilho sobe)
uniform vec4 brake_color : source_color = vec4(1.0, 0.07, 0.04, 1.0);
uniform float brake_level = 0.75;
uniform float brake_gain = 1.0;
varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float t = TIME * speed;
	float k = 1.0;
	if (pattern == 1) {
		// sequencial: uma onda de luz corre da traseira para a frente (e volta pelo outro lado)
		float ph = fract(lp.z * 0.55 - t * 0.7);
		k = 0.1 + 0.9 * smoothstep(0.0, 0.12, ph) * (1.0 - smoothstep(0.12, 0.42, ph));
	} else if (pattern == 2) {
		// alternado: lampadas em dois grupos (vai e vem em z, esquerda/direita) que trocam de lugar
		float grp = mod(floor(lp.z * 2.2) + (lp.x > 0.0 ? 1.0 : 0.0), 2.0);
		float phase = step(0.5, fract(t * 0.9));
		k = mix(0.1, 1.0, 1.0 - abs(grp - phase));
	} else if (pattern == 3) {
		// respirando: tudo sobe e desce junto, devagar
		k = 0.18 + 0.82 * (0.5 + 0.5 * sin(t * 2.2));
	}
	if (lens > 0.5) {
		float d = length(UV - vec2(0.5));
		k *= mix(1.3, 0.42, smoothstep(0.10, 0.52, d));
	}
	float lv = max(level, floor_level);
	lv = mix(lv, max(lv, brake_level) * brake_gain, brake);
	k = mix(k, max(k, 1.0), brake);
	ALBEDO = mix(base_color.rgb, brake_color.rgb, brake) * energy * lv * k;
}
"""

static var _shader: Shader


static func make_material(src: Material) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var col := Color(1.0, 0.7, 0.2)
	if src is BaseMaterial3D:
		var b: BaseMaterial3D = src as BaseMaterial3D
		col = b.emission if b.emission_enabled else b.albedo_color
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("base_color", col)
	m.set_shader_parameter("energy", 1.6)
	if src != null and src.resource_name.ends_with(LENS_SUFFIX):
		m.set_shader_parameter("lens", 1.0)
	if src != null and is_steady_lit(src.resource_name):
		m.set_shader_parameter("lens", 1.0)
		m.set_shader_parameter("floor_level", STEADY_FLOOR)
		m.set_shader_parameter("brake_gain", BRAKE_GAIN_TAIL)
	m.set_shader_parameter("brake_color", BRAKE_COLOR)
	m.set_shader_parameter("brake_level", BRAKE_LEVEL)
	return m


## Luz que acende a noite sem piscar (T-231)?
static func is_steady_lit(name: String) -> bool:
	return STEADY_LIT.has(base_name(name))


## Nome sem o sufixo da lente ("lamp_cyan@lens" -> "lamp_cyan").
static func base_name(name: String) -> String:
	return name.trim_suffix(LENS_SUFFIX)


## Material de luz que pisca (com ou sem lente)?
static func is_animated(name: String) -> bool:
	return ANIMATED.has(base_name(name))


static func label_key(id: String) -> String:
	return "lights." + id
