## Листок уровня: рисуется двумя частями и умеет летать на иглу.
##
## Листок разрезан по дырке от иглы на переднюю часть (ниже дырки) и
## заднюю (выше). Задние части всех листков рисуются до иглы, передние —
## после, поэтому игла видна выше дырки и скрыта листком ниже: получается,
## что она листок проткнула.
##
## Части берутся из [SheetArt] (`Back_Sheet_01`/`Forward_Sheet_01` и
## дальше по порядку) — обе картинки лежат на одном холсте, поэтому листок
## достаточно нарисовать дважды одним и тем же прямоугольником: перспектива
## и наклон уже нарисованы художником. Пока картинок нет, листок рисуется
## бумажным прямоугольником, который режется горизонталью по дырке в
## экранных координатах.
##
## Жизнь листка после прохождения уровня ([enum Phase]):
##
## [codeblock]
## FALLING_AWAY  листок точки графа падает вниз и уходит за экран
## DROPPING      на смену ему над иглой появляется другой и падает на неё
##               сверху — ровно по её оси, без покачивания
## SLIDING       дырка дошла до острия — дальше строго вниз по игле
## SEATED        доехал до своего места в стопке, заранее настроенного
## [/codeblock]
class_name PaperSheet
extends RefCounted

enum Phase {
	## Лежит на своём месте — в стопке или в точке графа.
	SEATED,
	## Падает вниз и уходит за экран.
	FALLING_AWAY,
	## Появился над иглой и падает на неё сверху, ровно по её оси.
	DROPPING,
	## Наколот на иглу и едет вертикально вниз.
	SLIDING,
	## Ушёл за экран — можно выбрасывать.
	GONE,
}

## Углы холста листка для отрисовки картинки четырёхугольником.
static var QUAD_UVS := PackedVector2Array([
	Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0),
])

var style: SpikeStyle
var phase: Phase = Phase.SEATED

## Дырка от иглы — опорная точка листка: именно она садится на иглу.
var pierce := Vector2.ZERO
var tilt := 0.0
var sheet_scale := 1.0
## Где дырка внутри листка, в долях листка.
var pierce_uv := Vector2(0.5, 0.42)
## Размер холста листка, px, до [member sheet_scale].
var sheet_size := Vector2(150.0, 88.0)
## Разовая поправка размера: листок под курсором чуть подрастает.
var grow := 1.0
## Цвет, которым красится листок: им притухают точки, куда шагнуть нельзя.
var modulate := Color.WHITE

## Картинки частей листка; пусто — рисуется бумажная заглушка.
var back_texture: Texture2D
var front_texture: Texture2D

## Буква в углу листка: S — магазин, M — минибосс, B — босс. Нужна только
## заглушке — у нарисованного листка своя иконка.
var letter := ""
## Номер листка в стопке — как на накалывателе с чеками. Тоже только для
## заглушки: у нарисованных листков номер уже напечатан.
var number := ""

## Листок ещё не показывается: ждёт своей очереди, с.
var delay := 0.0

## Свои масштаб и место дырки листка — до поправок от места в стопке.
## Место можно назначать повторно (окно меняет размер), поэтому поправки
## всегда считаются от этих значений, а не от текущих.
var _own_scale := 1.0
var _own_pierce_uv := Vector2(0.5, 0.42)

var _velocity := Vector2.ZERO
var _spin := 0.0
## Ось иглы и её острие: по оси листок падает, на острие накалывается.
var _needle_x := 0.0
var _needle_top := 0.0
var _target_y := 0.0
var _target_tilt := 0.0
## Ниже этой строки листок считается ушедшим за экран.
var _bottom_limit := 2000.0


## Листок стопки: картинки — из [SheetArt], размер — из стиля иглы.
static func create(sheet_style: SpikeStyle, art: SheetArt = null, sheet_letter := "",
		sheet_number := "") -> PaperSheet:
	var sheet := PaperSheet.new()
	sheet.style = sheet_style if sheet_style != null else SpikeStyle.new()
	sheet.letter = sheet_letter
	sheet.number = sheet_number
	sheet.sheet_size = sheet.style.sheet_size
	sheet.pierce_uv = sheet.style.pierce_uv
	if art != null:
		sheet.back_texture = art.back_texture
		sheet.front_texture = art.front_texture
		sheet.pierce_uv = art.pierce_or(sheet.style.pierce_uv)
		sheet.sheet_scale = art.scale
	sheet._remember_own()
	return sheet


## Листок точки графа: свои картинка, размер и наклон ([MapPointArt]).
static func create_point(sheet_style: SpikeStyle, art: MapPointArt,
		fallback_letter := "") -> PaperSheet:
	var sheet := PaperSheet.new()
	sheet.style = sheet_style if sheet_style != null else SpikeStyle.new()
	sheet.sheet_size = sheet.style.sheet_size
	sheet.pierce_uv = sheet.style.pierce_uv
	sheet.letter = fallback_letter
	if art == null:
		sheet._remember_own()
		return sheet
	sheet.front_texture = art.texture
	sheet.back_texture = art.back_texture
	sheet.sheet_size = art.size
	sheet.pierce_uv = art.pivot
	if art.texture != null or art.back_texture != null:
		# У нарисованного листка своя иконка — буква не нужна.
		sheet.letter = ""
	elif art.letter != "":
		sheet.letter = art.letter
	sheet._remember_own()
	return sheet


## Запомнить свои масштаб и место дырки: место в стопке правит их поверх.
func _remember_own() -> void:
	_own_scale = sheet_scale
	_own_pierce_uv = pierce_uv


## Нарисован ли листок картинками: у такого нет ни обводки, ни дырки —
## всё уже нарисовано.
func has_art() -> bool:
	return front_texture != null or back_texture != null


# --- Постановка и полёт ---

## Сразу поставить листок на его место в стопке — без анимации
## (карта открылась, а уровни пройдены раньше).
func seat(slot: SpikeSlot, needle_x: float, base_y: float) -> void:
	_apply_slot(slot, needle_x, base_y)
	pierce = Vector2(needle_x, _target_y)
	tilt = _target_tilt
	phase = Phase.SEATED


## Поставить листок в точку графа: он просто лежит на своём месте.
## `scale_value` — общая поправка размера всех точек ([MapStyle]).
func place(at: Vector2, sheet_tilt := 0.0, scale_value := 1.0) -> void:
	pierce = at
	tilt = sheet_tilt
	sheet_scale = _own_scale * scale_value
	phase = Phase.SEATED


## Прямоугольник листка на экране — по нему карта и ловит клики.
func bounds() -> Rect2:
	var rect := _local_rect()
	return Rect2(rect.position + pierce, rect.size)


## Первый шаг: листок падает вниз и уходит за экран.
func fall_away(from: Vector2, bottom_limit: float, rng: RandomNumberGenerator) -> void:
	pierce = from
	_bottom_limit = bottom_limit
	_velocity = Vector2(rng.randf_range(-style.fall_side_speed, style.fall_side_speed),
			style.fall_start_speed)
	_spin = rng.randf_range(-style.fall_spin, style.fall_spin)
	phase = Phase.FALLING_AWAY


## Второй шаг: листок появляется над иглой — ровно на её оси — и падает
## на неё сверху. Он появляется выше своего места в стопке и выше острия,
## чтобы было видно, как игла его протыкает, и было куда ехать вниз.
func drop_on_needle(slot: SpikeSlot, needle_x: float, needle_top: float,
		base_y: float) -> void:
	_apply_slot(slot, needle_x, base_y)
	var start_y := minf(_target_y - style.drop_height, needle_top - style.drop_above_tip)
	pierce = Vector2(needle_x, start_y)
	# Наклон — только тот, что нарисован на картинке: падает листок ровно.
	tilt = 0.0
	delay = style.spawn_delay
	_velocity = Vector2(0.0, style.drop_start_speed)
	_needle_top = needle_top
	phase = Phase.DROPPING


## Летит ли листок прямо сейчас — карта на это время запрещает клики.
func is_busy() -> bool:
	return phase == Phase.FALLING_AWAY or phase == Phase.DROPPING \
			or phase == Phase.SLIDING


func is_gone() -> bool:
	return phase == Phase.GONE


## Виден ли листок: пока не вышла задержка, его ещё нет на экране.
func is_visible() -> bool:
	return delay <= 0.0 and phase != Phase.GONE


func update(delta: float) -> void:
	if delay > 0.0:
		delay -= delta
		return
	match phase:
		Phase.FALLING_AWAY:
			_update_falling(delta)
		Phase.DROPPING:
			_update_dropping(delta)
		Phase.SLIDING:
			_update_sliding(delta)


func _update_falling(delta: float) -> void:
	_velocity.y += style.fall_gravity * delta
	pierce += _velocity * delta
	tilt += _spin * delta
	if pierce.y > _bottom_limit:
		phase = Phase.GONE


## Падение на иглу: строго вертикально, по оси иглы. Как только дырка
## дошла до острия, листок считается наколотым и дальше едет по игле.
func _update_dropping(delta: float) -> void:
	pierce.x = _needle_x
	_velocity.y += style.drop_gravity * delta
	pierce.y += _velocity.y * delta
	if pierce.y >= _needle_top or pierce.y >= _target_y:
		_pierce_on_needle()


func _pierce_on_needle() -> void:
	pierce.x = _needle_x
	pierce.y = maxf(pierce.y, _needle_top)
	_velocity.y = maxf(_velocity.y, style.slide_start_speed)
	phase = Phase.SLIDING


## Спуск по игле: строго вертикально до заранее настроенного места.
## Наклон доворачивается до наклона места.
func _update_sliding(delta: float) -> void:
	pierce.x = _needle_x
	_velocity.y += style.slide_gravity * delta
	if pierce.y < _target_y:
		pierce.y = minf(pierce.y + _velocity.y * delta, _target_y)
	else:
		pierce.y = move_toward(pierce.y, _target_y, style.slide_start_speed * delta)
	tilt = lerp_angle(tilt, _target_tilt, minf(style.settle_speed * delta, 1.0))
	if is_equal_approx(pierce.y, _target_y):
		pierce.y = _target_y
		tilt = _target_tilt
		phase = Phase.SEATED


func _apply_slot(slot: SpikeSlot, needle_x: float, base_y: float) -> void:
	var place_slot := slot if slot != null else SpikeSlot.new()
	_needle_x = needle_x
	_target_y = base_y - place_slot.height
	_target_tilt = deg_to_rad(place_slot.tilt_degrees)
	sheet_scale = _own_scale * place_slot.scale
	pierce_uv = _own_pierce_uv + place_slot.pierce_shift


# --- Отрисовка ---

## Тень листка — рисуется до всех листков, чтобы не ложиться на соседей.
## У нарисованного листка тень уже на картинке, поэтому её не рисуем.
func draw_shadow(canvas: CanvasItem) -> void:
	if not is_visible() or has_art() or style.shadow_color.a <= 0.0:
		return
	canvas.draw_colored_polygon(_quad(style.shadow_offset), style.shadow_color)


## Задняя часть — всё, что выше дырки. Рисуется до иглы, поэтому игла
## проходит поверх неё.
func draw_back(canvas: CanvasItem) -> void:
	if not is_visible():
		return
	if has_art():
		_draw_texture(canvas, back_texture)
		return
	_draw_paper(canvas, true)


## Передняя часть — всё, что ниже дырки. Рисуется после иглы и закрывает
## её собой, поэтому игла кажется воткнутой в листок.
func draw_front(canvas: CanvasItem) -> void:
	if not is_visible():
		return
	if has_art():
		_draw_texture(canvas, front_texture)
		return
	_draw_paper(canvas, false)
	if style.hole_radius > 0.0:
		canvas.draw_circle(pierce, style.hole_radius, style.hole_color)
	_draw_labels(canvas)


## Картинка части листка: обе части лежат на одном холсте, поэтому
## рисуются одним и тем же прямоугольником. Рисуем четырёхугольником, а не
## `draw_texture_rect`, чтобы листок можно было наклонять и чтобы не сбить
## общий сдвиг панели (её прокрутку). Наклон — только тот, что листок
## набрал в полёте: на картинке он уже нарисован.
func _draw_texture(canvas: CanvasItem, texture: Texture2D) -> void:
	if texture == null:
		return
	canvas.draw_colored_polygon(_quad(), modulate, QUAD_UVS, texture)


func _draw_paper(canvas: CanvasItem, is_back: bool) -> void:
	for piece: PackedVector2Array in _split(_quad(), is_back):
		if piece.size() < 3:
			continue
		canvas.draw_colored_polygon(piece, style.paper_color * modulate)
		_draw_edges(canvas, piece)


## Обводка части листка. Отрезок, лежащий на линии разреза, не рисуется —
## иначе поперёк листка шла бы лишняя черта по дырке.
func _draw_edges(canvas: CanvasItem, piece: PackedVector2Array) -> void:
	if style.border_width <= 0.0 or style.paper_border.a <= 0.0:
		return
	for i in piece.size():
		var a := piece[i]
		var b := piece[(i + 1) % piece.size()]
		if is_equal_approx(a.y, pierce.y) and is_equal_approx(b.y, pierce.y):
			continue
		canvas.draw_line(a, b, style.paper_border, style.border_width, true)


func _draw_labels(canvas: CanvasItem) -> void:
	if letter == "" and number == "":
		return
	var font := UiFont.resolve(style.font)
	var xform := Transform2D(tilt, pierce)
	var rect := _local_rect()
	# Листок в графе мельче, чем в стопке, — подписи ужимаются вместе с ним.
	if letter != "":
		var size_px := maxi(roundi(style.letter_font_size * sheet_scale), 6)
		var size := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1.0, size_px)
		var at: Vector2 = xform * (rect.get_center() + Vector2(-size.x * 0.5, size.y * 0.34))
		canvas.draw_string(font, at, letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
				size_px, style.letter_color)
	if number != "":
		# Номер — в левом нижнем углу листка, как на чеках накалывателя.
		var size_px := maxi(roundi(style.number_font_size * sheet_scale), 6)
		var at: Vector2 = xform * (rect.position + Vector2(rect.size.x * 0.12, rect.size.y * 0.94))
		canvas.draw_string(font, at, number, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
				size_px, style.number_color)


## Прямоугольник листка в его собственных координатах: начало координат —
## дырка от иглы, поэтому прямоугольник сдвинут на [member pierce_uv].
func _local_rect() -> Rect2:
	var size := sheet_size * sheet_scale * grow
	return Rect2(-size * pierce_uv, size)


func _quad(offset := Vector2.ZERO) -> PackedVector2Array:
	var rect := _local_rect()
	var xform := Transform2D(tilt, pierce + offset)
	return PackedVector2Array([
		xform * rect.position,
		xform * Vector2(rect.end.x, rect.position.y),
		xform * rect.end,
		xform * Vector2(rect.position.x, rect.end.y),
	])


## Разрезать четырёхугольник горизонталью по дырке: выше — задняя часть,
## ниже — передняя.
func _split(quad: PackedVector2Array, keep_above: bool) -> Array[PackedVector2Array]:
	const FAR := 8000.0
	var line_y := pierce.y
	var band := PackedVector2Array()
	if keep_above:
		band = PackedVector2Array([
			Vector2(-FAR, line_y - FAR), Vector2(FAR, line_y - FAR),
			Vector2(FAR, line_y), Vector2(-FAR, line_y),
		])
	else:
		band = PackedVector2Array([
			Vector2(-FAR, line_y), Vector2(FAR, line_y),
			Vector2(FAR, line_y + FAR), Vector2(-FAR, line_y + FAR),
		])
	return Geometry2D.intersect_polygons(quad, band)
