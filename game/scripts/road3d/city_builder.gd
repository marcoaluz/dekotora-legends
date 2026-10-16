class_name CityBuilder
extends Node3D
## Cidade noturna ao fundo: predios (caixas) com janelas iluminadas por shader procedural, em
## MultiMesh (um unico draw call por grupo) ao longo da pista, e montanhas escuras ao longe.
## Determinístico (semente fixa).

const WINDOW_SHADER := """
shader_type spatial;
render_mode cull_back;
uniform vec3 wall_color : source_color = vec3(0.07, 0.07, 0.16);
uniform vec3 window_color : source_color = vec3(1.0, 0.85, 0.4);
uniform float energy = 2.2;
varying vec3 wpos;
varying vec3 wnormal;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
void fragment() {
	vec2 uv = abs(wnormal.x) > 0.5 ? vec2(wpos.z, wpos.y) : vec2(wpos.x, wpos.y);
	vec2 cell = floor(uv / vec2(3.0, 3.5));
	vec2 f = fract(uv / vec2(3.0, 3.5));
	float win = step(0.2, f.x) * step(f.x, 0.8) * step(0.25, f.y) * step(f.y, 0.75);
	float on = step(0.55, hash(cell + floor(wpos.xz * 0.01)));
	float side = step(0.5, abs(wnormal.y) < 0.5 ? 1.0 : 0.0);
	ALBEDO = wall_color;
	EMISSION = window_color * win * on * side * energy * (0.6 + 0.8 * hash(cell * 3.1));
	ROUGHNESS = 0.8;
}
"""

var path: TrackPath


func build(path_: TrackPath, seed_: int = 21) -> void:
	path = path_
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = WINDOW_SHADER
	mat.shader = sh
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var xforms: Array[Transform3D] = []
	var z: float = 0.0
	while z < path.track.length_m + 200.0:
		for side in [-1.0, 1.0]:
			if rng.randf() < 0.75:
				var dist: float = rng.randf_range(95.0, 260.0)
				var w: float = rng.randf_range(14.0, 34.0)
				var d: float = rng.randf_range(14.0, 34.0)
				var h: float = rng.randf_range(25.0, 110.0)
				var c: Vector3 = path.world_point(minf(z, path.track.length_m - 1.0), side * dist / Track.ROAD_HALF_WIDTH_M, 0.0)
				var yaw: float = path.yaw_at(minf(z, path.track.length_m - 1.0))
				var t := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(w, h, d)), c + Vector3.UP * (h * 0.5 - 4.0))
				xforms.append(t)
		z += rng.randf_range(18.0, 40.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = box
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	# montanhas: cones achatados bem longe
	var mmesh := CylinderMesh.new()
	mmesh.top_radius = 0.0
	mmesh.bottom_radius = 1.0
	mmesh.height = 1.0
	mmesh.radial_segments = 7
	var mtn := MultiMesh.new()
	mtn.transform_format = MultiMesh.TRANSFORM_3D
	mtn.mesh = mmesh
	var count: int = 40
	mtn.instance_count = count
	for i in count:
		var zz: float = rng.randf_range(0.0, path.track.length_m)
		var sd: float = -1.0 if rng.randf() < 0.5 else 1.0
		var c2: Vector3 = path.world_point(zz, sd * rng.randf_range(520.0, 800.0) / Track.ROAD_HALF_WIDTH_M, 0.0)
		var hh: float = rng.randf_range(90.0, 260.0)
		var rr: float = rng.randf_range(160.0, 380.0)
		mtn.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(rr, hh, rr)), c2 + Vector3.UP * (hh * 0.5 - 6.0)))
	var mm_mat := StandardMaterial3D.new()
	mm_mat.albedo_color = Color("#16143a")
	mm_mat.roughness = 1.0
	var mi2 := MultiMeshInstance3D.new()
	mi2.multimesh = mtn
	mi2.material_override = mm_mat
	mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi2)
