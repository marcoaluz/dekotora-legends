class_name PoliceBeacon
extends RefCounted
## Police car light bar (T-143). car_police.glb has the light bar in its own node, "beacon", with UV per column
## (blender/scripts/lib/traffic_police.py): u 0..0.25 left lenses, 0.25..0.5 right lenses (both red, Japanese style),
## 0.5..0.75 white, the rest is the housing. Its material becomes an unshaded shader that flashes left and right
## alternately (one shared material for every police car: no extra draw call).

const SHADER := """
shader_type spatial;
render_mode unshaded;
uniform float rate = 1.6;
uniform float level = 1.0;
void fragment() {
	float col = floor(clamp(UV.x, 0.0, 0.999) * 4.0);
	float ph = fract(TIME * rate);
	float fast = step(0.5, fract(TIME * rate * 4.0));      // double flash inside each half
	float left = step(ph, 0.5) * fast;
	float right = (1.0 - step(ph, 0.5)) * fast;
	vec3 red = vec3(1.0, 0.12, 0.08);
	vec3 c;
	if (col < 0.5) {
		c = red * (0.3 + 2.4 * left);
	} else if (col < 1.5) {
		c = red * (0.3 + 2.4 * right);
	} else if (col < 2.5) {
		c = vec3(0.95, 0.95, 1.0) * (0.5 + 0.8 * max(left, right));
	} else {
		c = vec3(0.07, 0.075, 0.085) * level;
	}
	ALBEDO = c;
}
"""
const NODE_NAME := "beacon"

static var _mat: ShaderMaterial = null


## Shared light bar material (`level` = housing brightness: 1 by day, less at night).
static func material(level: float = 1.0) -> ShaderMaterial:
	if _mat == null:
		var s := Shader.new()
		s.code = SHADER
		_mat = ShaderMaterial.new()
		_mat.shader = s
	_mat.set_shader_parameter("level", level)
	return _mat


## Turns the light bar of the instanced car `car` on. Returns the light bar centre in car coordinates (to place the
## glow quads around it), or Vector3.INF when the model has no light bar.
static func apply(car: Node3D, level: float = 1.0) -> Vector3:
	var found: Array[Node] = car.find_children(NODE_NAME + "*", "MeshInstance3D", true, false)
	if found.is_empty():
		return Vector3.INF
	var mi: MeshInstance3D = found[0] as MeshInstance3D
	mi.material_override = material(level)
	var box: AABB = mi.mesh.get_aabb()
	return _local_to(car, mi) * box.get_center()


## Transform of `n` in the space of `root` (works inside or outside the scene tree).
static func _local_to(root: Node3D, n: Node3D) -> Transform3D:
	var t: Transform3D = Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t
