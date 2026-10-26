class_name SpeedFx
extends CanvasLayer
## Sensacao de velocidade na TELA (cada efeito com chave em Opcoes > Graficos):
## - linhas de velocidade nas bordas acima de 110 km/h (shader de tela barato: um ColorRect);
## - clarao rapido ao dar o Passing;
## - ajuda da camera: quanto o FOV abre, tremor continuo acima de 100 km/h e atraso nas curvas
##   (a cena chama camera_extra() e fov_extra()).

const LINES_SHADER := """
shader_type canvas_item;
uniform float amount = 0.0;
uniform float aspect = 1.777;
float h(float x) { return fract(sin(x * 127.1) * 43758.5453); }
void fragment() {
	vec2 p = UV - 0.5;
	p.x *= aspect;
	float r = length(p);
	float a = atan(p.y, p.x) / 6.28318 + 0.5;
	float n = 110.0;
	float id = floor(a * n);
	float rnd = h(id);
	float s = fract(a * n);
	float stripe = 1.0 - smoothstep(0.0, 0.09, abs(s - 0.5));
	float d = fract(r * 2.2 - TIME * (2.5 + rnd * 2.5) + rnd);
	float dash = smoothstep(0.0, 0.25, d) * smoothstep(1.0, 0.55, d);
	float edge = smoothstep(0.42, 0.95, r);
	COLOR = vec4(1.0, 1.0, 1.0, stripe * dash * edge * step(0.5, rnd) * amount * 0.55);
}
"""

var _lines: ColorRect
var _lines_mat: ShaderMaterial
var _flash: ColorRect
var _flash_a: float = 0.0
var _t: float = 0.0
var _lag: float = 0.0
var enabled: bool = true


func _ready() -> void:
	layer = 4                                      # abaixo do HUD (5)
	enabled = bool(get_node("/root/Settings").fx_speed)
	_lines = ColorRect.new()
	_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = LINES_SHADER
	_lines_mat.shader = sh
	_lines.material = _lines_mat
	_lines.visible = false
	add_child(_lines)
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1.0, 0.97, 0.9, 0.0)
	add_child(_flash)


## Atualiza com a velocidade (m/s) do jogador.
func update(speed: float, dt: float) -> void:
	_t += dt
	var kmh: float = speed * 3.6
	var amt: float = clampf((kmh - 110.0) / 50.0, 0.0, 1.0) if enabled else 0.0
	_lines.visible = amt > 0.01
	if _lines.visible:
		var vs: Vector2 = get_viewport().get_visible_rect().size
		_lines_mat.set_shader_parameter("amount", amt)
		_lines_mat.set_shader_parameter("aspect", vs.x / maxf(vs.y, 1.0))
	_flash_a = maxf(_flash_a - dt * 5.0, 0.0)
	_flash.color.a = _flash_a


func passing_flash() -> void:
	if enabled:
		_flash_a = 0.35


## Deslocamento extra da camera: tremor sutil acima de 100 km/h + atraso para fora da curva.
## Devolve [deslocamento da posicao (unidades laterais da pista), deslocamento do alvo, tremor em metros].
func camera_extra(speed: float, curve: float, dt: float) -> Array:
	if not enabled:
		return [0.0, 0.0, Vector3.ZERO]
	_lag = lerpf(_lag, curve, minf(1.5 * dt, 1.0))           # a camera "atrasa" ao entrar e sair da curva
	var kmh: float = speed * 3.6
	var f: TruckFeel = TruckFeel.current()          # T-219: numeros no data/feel/truck_feel.tres (antes 100 km/h, 0,035 m)
	var amp: float = clampf((kmh - f.speed_shake_from_kmh) / 60.0, 0.0, 1.0) * f.speed_shake_m
	var shake := Vector3(sin(_t * 37.0) + 0.5 * sin(_t * 61.0), sin(_t * 43.0 + 1.3) + 0.5 * sin(_t * 71.0), 0.0) * amp
	return [_lag * 0.28, -_lag * 0.22, shake]


## Quanto o FOV abre com a velocidade (graus).
func fov_extra(speed: float) -> float:
	var f: TruckFeel = TruckFeel.current()          # T-219 (antes 0,42 grau por m/s, sem teto)
	return minf(speed * (f.fov_deg_per_mps if enabled else 0.25), f.fov_max_extra_deg)
