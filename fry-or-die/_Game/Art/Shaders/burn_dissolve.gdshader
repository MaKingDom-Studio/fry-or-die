// Растворение «сгорая от точки»: изображение выгорает кругом из точки
// position, край свечения подкрашивается burnColor, а всё, что внутри
// круга, становится прозрачным. Неровность кромки даёт шум noiseTexture.
//
// Анимация — тюнингом одного параметра radius от 0 до ~2 (см.
// IngredientNode.burn_away): 0 — целое изображение, 2 — выгорело полностью.
shader_type canvas_item;

// Точка начала выжигания в UV изображения (0..1).
uniform vec2 position = vec2(0.5, 0.5);
// Радиус выгоревшего круга в UV; растёт по времени.
uniform float radius = 0.0;
// Толщина светящейся кромки.
uniform float borderWidth = 0.02;
// Насколько шум искажает кромку.
uniform float burnMult = 0.135;
uniform sampler2D noiseTexture : repeat_enable;
uniform vec4 burnColor : source_color = vec4(1.0, 0.45, 0.1, 1.0);

void fragment() {
	float dist = length(position - UV) + texture(noiseTexture, UV).b * burnMult;
	COLOR.rgb = mix(COLOR.rgb, burnColor.rgb, float(dist < radius + borderWidth));
	COLOR.a *= 1.0 - float(dist < radius);
}
