class_name SpeedBlur
extends MeshInstance3D
## T-189: optional "motion blur" of the Ultra quality (Settings.fx_motion_blur). Godot 4 has no built-in motion blur,
## so this is a radial speed blur: a full-screen quad that samples the screen towards the centre, stronger at the
## edges and only above ~70 km/h. The centre (truck and road ahead) stays sharp.

const SHADER := """
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float amount = 0.0;
void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - vec2(0.5, 0.56);
	float edge = smoothstep(0.12, 0.62, length(d));
	vec3 c = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		c += textureLod(screen_tex, uv - d * amount * edge * float(i) * 0.012, 0.0).rgb;
	}
	ALBEDO = c / 8.0;
	ALPHA = edge * clamp(amount * 4.0, 0.0, 1.0);
}
"""

var _mat: ShaderMaterial


## Null when off (below Ultra or option off).
static func attach(cam: Camera3D, q: int, on: bool) -> SpeedBlur:
	if not on or not UltraLook.active(q):
		return null
	var b := SpeedBlur.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(2.0, 2.0)
	b.mesh = qm
	b._mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	b._mat.shader = sh
	b.material_override = b._mat
	b.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))   # never culled
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.position = Vector3(0, 0, -1)
	cam.add_child(b)
	return b


## `speed` in m/s.
func update(speed: float) -> void:
	_mat.set_shader_parameter("amount", clampf((speed - 19.0) / 22.0, 0.0, 1.0))
