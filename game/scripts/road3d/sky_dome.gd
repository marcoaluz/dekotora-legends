class_name SkyDome
extends RefCounted
## T-188: sky shader of the new scenery (WorldEnv uses it when ScenicZone.enabled()).
## - gradient in 3 bands (zenith, middle, horizon haze) + glow on the horizon (sunset, or the city at night);
## - sun with a soft halo, or a MOON (shaded disk with darker "seas") at night;
## - stars: SMALL points (1-2 px, never squares) with varied brightness and colour, a faint second layer and a
##   milky-way band; slight twinkle;
## - clouds with volume: density from noise, lit side toward the sun, darker belly, fading into the horizon haze.
## Stars and clouds stay out of the reflection cubemap (AT_CUBEMAP_PASS), as before.

const SHADER := """
shader_type sky;
uniform vec3 top_color : source_color;
uniform vec3 mid_color : source_color;
uniform vec3 horizon_color : source_color;
uniform vec3 ground_color : source_color;
uniform vec3 glow_color : source_color;
uniform float glow_falloff = 8.0;
uniform vec3 disk_color : source_color;
uniform float disk_energy = 3.0;
uniform float disk_cos = 0.9997;
uniform float halo = 0.4;
uniform float moon = 0.0;
uniform float stars = 0.0;
uniform float clouds = 0.0;
uniform vec3 cloud_color : source_color;
uniform vec3 cloud_shade : source_color;
uniform int octaves = 5;
uniform float fuji = 0.0;
uniform float fuji_az = 2.8;
uniform vec3 fuji_color : source_color;
uniform float snow = 1.0;

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 6; i++) {
		if (i >= octaves) { break; }
		s += a * vn(p);
		p = p * 2.07 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return s;
}
// One layer of point stars: cell grid on the sphere, one candidate per cell, round soft dot of `size` cells.
vec3 star_layer(vec3 d, float density, float keep, float size, float gain) {
	float lat = asin(clamp(d.y, -1.0, 1.0));
	vec2 uv = vec2(atan(d.x, d.z) * cos(lat), lat) * density;
	vec2 cell = floor(uv);
	float r = h(cell);
	if (r < keep) { return vec3(0.0); }
	vec2 pos = vec2(h(cell + 3.1), h(cell + 5.7)) * 0.6 + 0.2;
	float dist = length(fract(uv) - pos);
	float sz = size * (0.6 + 0.8 * h(cell + 9.2));
	float b = smoothstep(sz, sz * 0.25, dist);
	float bright = 0.25 + 0.75 * pow(h(cell + 1.3), 3.0);
	float tw = 0.85 + 0.15 * sin(TIME * (1.5 + 3.0 * h(cell + 4.4)) + r * 40.0);
	vec3 col = mix(vec3(0.72, 0.82, 1.0), vec3(1.0, 0.88, 0.72), h(cell + 2.2));
	return col * b * bright * tw * gain;
}

void sky() {
	vec3 d = EYEDIR;
	float y = d.y;
	float yy = max(y, 0.0);
	vec3 c = mix(horizon_color, mid_color, smoothstep(0.0, 0.18, yy));
	c = mix(c, top_color, smoothstep(0.06, 0.55, yy));
	c += glow_color * exp(-yy * glow_falloff);
	vec3 sun_dir = LIGHT0_ENABLED ? LIGHT0_DIRECTION : vec3(0.0, 1.0, 0.0);
	if (LIGHT0_ENABLED) {
		float dd = dot(d, sun_dir);
		c += disk_color * (pow(max(dd, 0.0), 6.0) * 0.12 + pow(max(dd, 0.0), 120.0) * 0.6) * halo;
		float disk = smoothstep(disk_cos - 0.00025, disk_cos + 0.00005, dd);
		if (disk > 0.0) {
			float shade = 1.0;
			if (moon > 0.0) {
				vec3 t1 = normalize(cross(sun_dir, vec3(0.0, 1.0, 0.0)));
				vec3 t2 = cross(t1, sun_dir);
				vec2 q = vec2(dot(d, t1), dot(d, t2)) / sqrt(max(1.0 - disk_cos * disk_cos, 1e-6));
				float seas = smoothstep(0.45, 0.7, fbm(q * 2.3 + 4.0));
				float limb = sqrt(max(1.0 - dot(q, q), 0.0));
				shade = (0.75 - 0.3 * seas) * (0.6 + 0.4 * limb);
			}
			c = mix(c, disk_color * disk_energy * shade, disk);
		}
	}
	if (!AT_CUBEMAP_PASS) {
		if (stars > 0.0 && y > 0.0) {
			float fade = smoothstep(0.03, 0.3, y);
			vec3 s = star_layer(d, 220.0, 0.9, 0.22, 2.4) + star_layer(d, 520.0, 0.8, 0.28, 0.9);
			vec3 band_n = normalize(vec3(0.35, 0.55, 0.76));
			float band = exp(-pow(dot(d, band_n) / 0.2, 2.0)) * fbm(vec2(atan(d.x, d.z), y) * 6.0);
			c += (s + vec3(0.55, 0.6, 0.8) * band * 0.06) * fade * stars;
		}
		if (clouds > 0.0 && y > 0.0) {
			vec2 p = d.xz / (y + 0.07);
			vec2 wind = vec2(TIME * 0.006, TIME * 0.002);
			float dens = fbm(p * 0.75 + wind);
			float cov = smoothstep(0.44, 0.74, dens);
			vec2 toward = normalize(sun_dir.xz + vec2(1e-4)) * 0.09;
			float lit = clamp(0.55 + (dens - fbm(p * 0.75 + wind + toward)) * 5.0, 0.0, 1.15);
			float belly = smoothstep(0.85, 0.55, dens);
			vec3 cc = mix(cloud_shade, cloud_color, lit * mix(0.7, 1.0, belly));
			float cl = cov * clouds * smoothstep(0.0, 0.14, y);
			cc = mix(cc, horizon_color + glow_color * 0.5, exp(-y * 9.0) * 0.55);
			c = mix(c, cc, cl);
		}
	}
	if (fuji > 0.0 && y > -0.01) {
		float az = atan(d.x, d.z);
		float da = abs(mod(az - fuji_az + 3.14159, 6.28318) - 3.14159);
		float prof = min(0.13 * pow(max(1.0 - da / 0.42, 0.0), 1.9), 0.118);
		if (y < prof) {
			float cap = step(prof * 0.66 + 0.006 * sin(az * 90.0), y);
			vec3 mc = mix(fuji_color, horizon_color, 0.45);
			c = mix(mc, vec3(0.92, 0.94, 1.0) * mix(0.35, 1.0, snow), cap);
		}
	}
	if (y < 0.0) {
		c = mix(horizon_color * 0.7, ground_color, smoothstep(0.0, -0.1, y));
	}
	COLOR = c;
}
"""


## Material for the sky of the race (`q` = Settings.quality: fewer cloud octaves on low).
static func material(tod: TimeOfDay, fuji: bool, q: int) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	var night: float = 1.0 - clampf(tod.day_amount * 4.0, 0.0, 1.0)
	m.set_shader_parameter("top_color", tod.sky_top)
	m.set_shader_parameter("mid_color", tod.sky_top.lerp(tod.sky_horizon, 0.45))
	m.set_shader_parameter("horizon_color", tod.sky_horizon)
	m.set_shader_parameter("ground_color", tod.sky_ground)
	m.set_shader_parameter("glow_color", tod.horizon_glow * 0.6)
	m.set_shader_parameter("glow_falloff", tod.glow_falloff)
	m.set_shader_parameter("disk_color", tod.disk_color)
	m.set_shader_parameter("disk_energy", tod.disk_energy)
	m.set_shader_parameter("disk_cos", cos(deg_to_rad(tod.disk_size_deg * 0.5)))
	m.set_shader_parameter("halo", tod.halo)
	m.set_shader_parameter("moon", night)
	m.set_shader_parameter("stars", tod.stars)
	m.set_shader_parameter("clouds", tod.clouds if q >= 1 else tod.clouds * 0.7)
	m.set_shader_parameter("cloud_color", tod.cloud_color)
	m.set_shader_parameter("cloud_shade", tod.cloud_color.lerp(tod.sky_top, 0.55) * 0.75)
	m.set_shader_parameter("octaves", 5 if q >= 1 else 3)
	m.set_shader_parameter("fuji", 1.0 if fuji else 0.0)
	m.set_shader_parameter("fuji_color", Color("#1c2340").lerp(Color("#5a6a8c"), tod.day_amount))
	m.set_shader_parameter("snow", 0.4 + 0.6 * tod.day_amount)
	return m
