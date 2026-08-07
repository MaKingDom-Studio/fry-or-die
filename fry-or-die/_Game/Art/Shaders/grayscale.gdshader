// Обесцвечивание кадра кольцевой волной («2D screen grayscale ripple»).
//
// Шейдер лежит на заливке во весь вьюпорт и берёт уже нарисованный кадр из
// заднего буфера (screen_texture), поэтому над заливкой должен стоять
// BackBufferCopy — им и является узел GrayscaleOverlay.
//
// Переход играет волна, расходящаяся кругами из точки wave_origin (в бою это
// бутылка водки на столе). Внутри фронта кадр держит новое состояние
// (amount_to), снаружи прежнее (amount_from), а по самому фронту и за ним идут
// подсвеченные кольца. Прогон фронта — wave 0..1, его и анимируют: 0 — волна
// только пошла из точки, 1 — дошла до самого далёкого угла экрана, и весь кадр
// живёт по amount_to. Обесцвечивание: 0 — кадр как был, 1 — полностью
// чёрно-белый.
//
// luminance — вклад каналов в яркость (ITU-R BT.601), contrast/brightness
// подтягивают вылинявший кадр, tint красит серое (например в сепию),
// не возвращая цвет исходной картинке.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform float amount_from : hint_range(0.0, 1.0) = 0.0;
uniform float amount_to : hint_range(0.0, 1.0) = 0.0;
uniform float wave : hint_range(0.0, 1.0) = 1.0;
uniform vec3 luminance = vec3(0.299, 0.587, 0.114);
uniform float contrast : hint_range(0.0, 3.0) = 1.0;
uniform float brightness : hint_range(0.0, 3.0) = 1.0;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Волна. Источник в экранных UV: (0.5, 0.5) — центр экрана; в бою его ставит
// режим боя по месту бутылки.
uniform vec2 wave_origin = vec2(0.5, 0.5);
// Размытость фронта в долях его пути: 0 — резкая кромка, 1 — на весь экран.
uniform float wave_width : hint_range(0.01, 1.0) = 0.12;
// Кольца: сколько их идёт за фронтом (не больше 4), расстояние между ними
// и толщина линии — в тех же долях пути.
uniform float ring_count : hint_range(0.0, 4.0) = 3.0;
uniform float ring_spacing : hint_range(0.01, 0.5) = 0.11;
uniform float ring_thickness : hint_range(0.001, 0.1) = 0.008;
// Цвет колец и их сила (0 — колец не видно).
uniform vec4 crest_color : source_color = vec4(0.35, 0.8, 1.0, 1.0);
uniform float crest_strength : hint_range(0.0, 1.0) = 0.7;

void fragment() {
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	vec3 gray = vec3(dot(source, luminance));
	// Контраст крутится вокруг середины серого, чтобы кадр не уплывал в чёрное.
	gray = clamp((gray - 0.5) * contrast + 0.5, 0.0, 1.0) * brightness * tint.rgb;

	// Круги должны быть круглыми: UV по ширине растянуты, поэтому мерим
	// расстояния в высотах экрана.
	vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float dist = length((SCREEN_UV - wave_origin) * aspect);
	// Путь волны — до самого далёкого от источника угла экрана.
	float reach = max(length(max(wave_origin, vec2(1.0) - wave_origin) * aspect), 0.001);
	float axis = dist / reach;

	// Фронт едет от -wave_width до 1: внутри него новое состояние.
	float front = wave * (1.0 + wave_width) - wave_width;
	float passed = 1.0 - smoothstep(front, front + wave_width, axis);
	vec3 result = mix(source, gray, clamp(mix(amount_from, amount_to, passed), 0.0, 1.0));

	// Кольца: первое — по самому фронту, следующие отстают и тусклее.
	float rings = 0.0;
	float lead = front + wave_width * 0.5;
	for (int i = 0; i < 4; i++) {
		if (float(i) >= ring_count) {
			break;
		}
		float radius = lead - float(i) * ring_spacing;
		float line = 1.0 - smoothstep(0.0, ring_thickness, abs(axis - radius));
		rings = max(rings, line * (1.0 - float(i) / max(ring_count, 1.0)));
	}
	// К концу прогона кольца гаснут — на покое их быть не должно.
	rings *= 1.0 - smoothstep(0.75, 1.0, wave);
	COLOR = vec4(mix(result, crest_color.rgb, rings * crest_strength * crest_color.a), 1.0);
}
