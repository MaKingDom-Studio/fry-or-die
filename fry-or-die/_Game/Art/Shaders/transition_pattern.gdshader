// Переход между сценами с узором («transition shader with patterns»).
//
// Экран закрывает заливка, кромка которой идёт по градиенту (gradient_texture)
// и рвётся узором (shape_texture) — получаются кляксы с дырами, как на
// референсе. Всей анимацией управляет один параметр factor:
// 0 — экран открыт (заливки нет), 1 — экран закрыт целиком. Уровень
// открывается прогоном 1 → 0, загрузка локации — обратным прогоном 0 → 1
// (см. [SceneTransition]).
//
// gradient_texture задаёт порядок открытия: открывается там, где градиент
// светлее (у нас радиальный белый в центре — уровень раскрывается из центра).
// gradient_fixed выправляет пропорции по высоте, чтобы клякса не была овальной.
// shape_tiling / shape_rotation / shape_scroll — как ложится узор кромки,
// shape_feathering — мягкость её края, shape_treshold — сколько узора попадает
// в кромку.
shader_type canvas_item;

uniform vec4 base_color : source_color;
uniform vec2 node_resolution;

uniform float factor : hint_range(0.0, 1.0, 0.01) = 0.54;
uniform float width = 0.4;

group_uniforms gradient;
uniform sampler2D gradient_texture;
uniform bool gradient_fixed = false;

group_uniforms shape;
uniform sampler2D shape_texture;
uniform float shape_tiling = 32.0;
uniform float shape_rotation = 0.0;
uniform vec2 shape_scroll = vec2(0.0);
uniform float shape_feathering : hint_range(0.0, 1.0, 0.01) = 0.00;
uniform float shape_treshold : hint_range(0.0, 2.0, 0.01) = 1.0;

// Отличие от оригинала: параметр «fixed» переименован в use_fixed — fixed
// зарезервировано в GLSL ES, на котором собирается рендерер GL Compatibility.
float gradient(vec2 uv, vec2 fixed_uv, bool use_fixed) {
	float value = 0.0;
	if (use_fixed) {
		value = texture(gradient_texture, fixed_uv).r;
	} else {
		value = texture(gradient_texture, uv).r;
	}
	return value;
}

vec2 rotate(vec2 uv, vec2 pivot, float angle)
{
	mat2 rotation = mat2(vec2(sin(angle), -cos(angle)),
						vec2(cos(angle), sin(angle)));
	uv -= pivot;
	uv = uv * rotation;
	uv += pivot;
	return uv;
}

void fragment() {
	float progress = mix(-width, 1.0, factor);
	float aspect = node_resolution.y / node_resolution.x;

	vec2 aspect_uv = ((UV - vec2(0.0, 0.5)) * vec2(1.0, aspect)) + vec2(0.0, 0.5);

	float value = clamp((gradient(UV, aspect_uv, gradient_fixed) - progress) / (width), 0.0, 1.0);

	vec2 tiled_uv = rotate(mod((aspect_uv + vec2(TIME) * shape_scroll) * shape_tiling, 1.0), vec2(0.5), radians(shape_rotation));
	float shape_value = 1.0 - texture(shape_texture, tiled_uv).r;

	shape_value = mix(shape_feathering * 0.5, 1.0 - shape_feathering * 0.5, shape_value);
	float shaped_gradient = smoothstep(value - (shape_feathering * 0.5), value + (shape_feathering * 0.5), shape_treshold - shape_value);

	// Отличие от оригинала: цвет заливки берётся из base_color (в оригинале
	// зашит чёрный) — чтобы перекрытие настраивалось в материале.
	COLOR.rgb = base_color.rgb;
	COLOR.a = shaped_gradient * base_color.a;
}
