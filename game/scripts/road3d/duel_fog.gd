class_name DuelFog
extends Node3D
## Purple ground fog of the duel studio (T-204). Everywhere: soft puffs (one MultiMesh = 1 draw call) drifting low
## over the floor plus a violet sheen on the floor. PC Ultra (Forward+) also gets a real volumetric fog volume, so
## the headlights and the studio lights show beams in it. Presentation only.

const PUFF_TEX := "res://assets/textures/duel/fog_puff.png"   # T-204 (tools_dev/make_duel_art.gd)
const COUNT: int = 42
const X_SPAN: float = 26.0
const Z_MIN: float = -30.0
const Z_MAX: float = 6.0                                     # never between the launch lens (z ~ 10) and the trucks

var _mm: MultiMesh
var _base: Array[Vector4] = []                               # x, y, z, width
var _speed: PackedFloat32Array = []
var _cols: Array[Color] = []


func build(volumetric: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 204
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	var q := QuadMesh.new()                                    # faces +Z: the studio camera always looks along -Z
	q.size = Vector2(1.0, 0.55)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = load(PUFF_TEX) as Texture2D
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.disable_receive_shadows = true
	q.material = m
	_mm.mesh = q
	_mm.instance_count = COUNT
	var thin: float = 0.6 if volumetric else 1.0               # the volume already fills the air on Ultra
	for i in COUNT:
		var z: float = rng.randf_range(Z_MIN, Z_MAX)
		var w: float = rng.randf_range(6.0, 12.0) * (1.25 if z < -14.0 else 1.0)
		_base.append(Vector4(rng.randf_range(-X_SPAN, X_SPAN), rng.randf_range(0.15, 0.9), z, w))
		_speed.append(rng.randf_range(0.35, 1.1) * (1.0 if rng.randf() < 0.5 else -1.0))
		var c: Color = Color("#5b25b8").lerp(Color("#a24de6"), rng.randf())
		c.a = rng.randf_range(0.28, 0.55) * thin
		_cols.append(c)
		_mm.set_instance_color(i, c)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = _mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "FogPuffs"
	add_child(mi)
	update(0.0)
	_sheen()
	if volumetric:
		_volume()


## Puffs drift sideways (wrapping) and breathe; the same `t` gives the same picture on every client.
func update(t: float) -> void:
	if _mm == null:
		return
	for i in COUNT:
		var b: Vector4 = _base[i]
		var x: float = fposmod(b.x + _speed[i] * t + X_SPAN, X_SPAN * 2.0) - X_SPAN
		var k: float = b.w * (1.0 + 0.06 * sin(t * 0.9 + float(i)))
		_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(k, k, 1.0)), Vector3(x, b.y + k * 0.18, b.z)))


## Violet light on the floor under the fog (additive, radial).
func _sheen() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0.42, 0.18, 0.75, 0.55))
	g.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(64.0, 46.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = tex
	pm.material = m
	mi.mesh = pm
	mi.position = Vector3(0.0, 0.02, -8.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "FogSheen"
	add_child(mi)


## PC Ultra: a low box of volumetric fog (the camera environment turns volumetric fog on).
func _volume() -> void:
	var fv := FogVolume.new()
	fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	fv.size = Vector3(80.0, 1.5, 46.0)                    # top at 1.5 m (under the lens), ends at z = 4
	fv.position = Vector3(0.0, 0.75, -19.0)
	var fm := FogMaterial.new()
	fm.density = 0.35
	fm.albedo = Color(0.6, 0.4, 1.0)
	fm.emission = Color(0.06, 0.02, 0.12)
	fm.height_falloff = 0.9
	fm.edge_fade = 0.6
	fv.material = fm
	fv.name = "FogVolume"
	add_child(fv)
