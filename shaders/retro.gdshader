shader_type canvas_item;
// Ретро-фільтр у дусі старих RPG: пікселізація, обмежена палітра з дизерингом,
// часткове знебарвлення, віньєтка й легке зерно.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float pixel_size = 3.0;
uniform float levels = 22.0;
uniform float desat = 0.3;
uniform float vignette = 0.55;
uniform float grain = 0.035;
uniform vec3 tint = vec3(1.0, 0.93, 0.84);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float px = max(1.0, floor(pixel_size * res.y / 720.0 + 0.5));
	vec2 cell = floor(FRAGCOORD.xy / px);
	vec2 uv = (cell * px + px * 0.5) / res;
	vec3 c = texture(screen_tex, uv).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l) * tint, desat);
	int bx = int(mod(cell.x, 4.0));
	int by = int(mod(cell.y, 4.0));
	float bayer[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	float d = bayer[by * 4 + bx] / 16.0 - 0.5;
	c = floor(c * levels + d + 0.5) / levels;
	c += (hash(cell + vec2(TIME * 13.0, TIME * 7.0)) - 0.5) * grain;
	vec2 q = SCREEN_UV - 0.5;
	c *= clamp(1.0 - dot(q, q) * vignette * 2.0, 0.0, 1.0);
	COLOR = vec4(c, 1.0);
}
