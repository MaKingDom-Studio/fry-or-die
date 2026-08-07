## Обводка точки карты: рисуется карандашом по кругу и так же стирается.
##
## Вид обводки — [CircleStyle]: `Circle_01`…`Circle_03` это три разных
## овала, и каждая новая обводка берёт следующий по очереди
## ([member variant]). Здесь только её жизнь ([enum Phase]):
##
## [codeblock]
## HIDDEN    обводки нет
## DRAWING   карандаш обводит точку: показан кусок овала от начала до руки
## HELD      обвели — держим паузу, чтобы игрок увидел, что выбрал
## IDLE      обводка стоит целиком
## ERASING   карандаш стирает обводку обратным ходом
## [/codeblock]
##
## Недорисованная обводка получается угловым срезом: картинка овала
## обрезается веером от центра, раскрытым на пройденный карандашом угол.
## Поэтому линия открывается вдоль себя, как будто её ведут.
class_name MapCircle
extends RefCounted

enum Phase {
	## Обводки нет.
	HIDDEN,
	## Карандаш обводит точку.
	DRAWING,
	## Обвели: держим паузу перед запуском уровня.
	HELD,
	## Стоит целиком.
	IDLE,
	## Карандаш стирает обводку.
	ERASING,
}

var style: CircleStyle
var phase: Phase = Phase.HIDDEN

## Точка карты, которую обводим; null — обводка ничью точку не держит.
var node: MapNode

## Центр обводки в координатах содержимого панели графа.
var center := Vector2.ZERO
## Размер обводки, px — обычно [member CircleStyle.size] с поправкой
## на размер листка точки.
var size := Vector2.ZERO

## Сколько овала уже проведено, 0..1.
var progress := 0.0

## Какой овал из [member CircleStyle.variants] рисуем сейчас. Каждая новая
## обводка берёт следующий, поэтому две подряд не выглядят одинаково.
var variant := 0

var _held := 0.0


## `first_variant` — с какого овала начать очередь: карта передаёт сюда
## число пройденных точек, поэтому за забег овалы идут по кругу подряд,
## а не начинаются заново с каждым входом на карту.
static func create(circle_style: CircleStyle, first_variant := 0) -> MapCircle:
	var circle := MapCircle.new()
	circle.style = circle_style if circle_style != null else CircleStyle.new()
	circle.size = circle.style.size
	# Очередь сдвинута на один назад: первая же обводка возьмёт овал под
	# номером first_variant.
	circle.variant = first_variant - 1
	return circle


# --- Жизнь обводки ---

## Начать обводить точку с нуля — следующим по очереди овалом.
## `scale_value` — поправка на размер листка точки
## ([member MapPointArt.circle_scale]): у босса овал крупнее.
func draw_at(at: Vector2, target: MapNode = null, scale_value := 1.0) -> void:
	center = at
	size = style.size * maxf(scale_value, 0.01)
	node = target
	progress = 0.0
	_held = 0.0
	variant += 1
	phase = Phase.DRAWING


## Начать стирать обводку. Если её и не было — сразу считаем стёртой.
func erase() -> void:
	if phase == Phase.HIDDEN:
		return
	phase = Phase.ERASING


## Убрать обводку без анимации.
func clear() -> void:
	phase = Phase.HIDDEN
	progress = 0.0
	node = null


func is_hidden() -> bool:
	return phase == Phase.HIDDEN


## Обводка стоит целиком: карандаш свою работу кончил.
func is_idle() -> bool:
	return phase == Phase.IDLE


## Обвели и выдержали паузу — можно запускать уровень.
func is_ready() -> bool:
	return phase == Phase.IDLE or (phase == Phase.HELD and _held >= style.hold_time)


## Идёт ли анимация — на это время карта запрещает новые клики.
func is_busy() -> bool:
	return phase == Phase.DRAWING or phase == Phase.HELD or phase == Phase.ERASING


func update(delta: float) -> void:
	match phase:
		Phase.DRAWING:
			progress = minf(progress + delta / maxf(style.draw_time, 0.001), 1.0)
			if progress >= 1.0:
				phase = Phase.HELD
				_held = 0.0
		Phase.HELD:
			_held += delta
			if _held >= style.hold_time:
				phase = Phase.IDLE
		Phase.ERASING:
			progress = maxf(progress - delta / maxf(style.erase_time, 0.001), 0.0)
			if progress <= 0.0:
				phase = Phase.HIDDEN
				node = null


# --- Отрисовка ---

func draw(canvas: CanvasItem) -> void:
	if phase == Phase.HIDDEN or progress <= 0.0:
		return
	var rect := Rect2(center + style.offset - size * 0.5, size)
	var texture := style.variant(variant)
	if texture == null:
		_draw_arc(canvas, rect)
		return
	if progress >= 1.0:
		canvas.draw_texture_rect(texture, rect, false, style.color)
		return
	# Недорисованная обводка: картинку обрезаем веером от центра, раскрытым
	# на пройденный карандашом угол.
	for piece: PackedVector2Array in Geometry2D.intersect_polygons(_wedge(rect), _quad(rect)):
		if piece.size() < 3:
			continue
		canvas.draw_colored_polygon(piece, style.color, _uvs(piece, rect), texture)


## Заглушка без картинок: обводка рисуется дугой.
func _draw_arc(canvas: CanvasItem, rect: Rect2) -> void:
	var start := deg_to_rad(style.start_angle_degrees)
	var end := start + TAU * progress * style.direction()
	var radius := maxf(rect.size.x, rect.size.y) * 0.5
	canvas.draw_arc(rect.get_center(), radius, start, end, style.segments,
			style.color, style.stroke_width, true)


## Веер от центра обводки, раскрытый на пройденный карандашом угол.
## Радиус берётся с запасом, чтобы веер накрывал углы картинки.
func _wedge(rect: Rect2) -> PackedVector2Array:
	var pivot := rect.get_center()
	var radius := rect.size.length()
	var start := deg_to_rad(style.start_angle_degrees)
	var span := TAU * progress * style.direction()
	var steps: int = maxi(style.segments, 3)
	var points := PackedVector2Array([pivot])
	for i in steps + 1:
		var angle := start + span * float(i) / float(steps)
		points.append(pivot + Vector2(cos(angle), sin(angle)) * radius)
	return points


func _quad(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])


func _uvs(piece: PackedVector2Array, rect: Rect2) -> PackedVector2Array:
	var uvs := PackedVector2Array()
	for point: Vector2 in piece:
		uvs.append((point - rect.position) / rect.size)
	return uvs
