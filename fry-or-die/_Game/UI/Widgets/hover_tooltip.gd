@tool
## Подсказка при наведении: окно с текстом о предмете.
##
## Один узел на сцену — он сам каждый кадр смотрит, что под курсором, и
## рисует подсказку поверх всего (кладётся ребёнком корня сцены с большим
## z-индексом). Подсказки работают на ингредиенты (стол, корзины, мешок,
## витрина магазина), специи (полка, витрина) и инструменты (кнопка и окно
## хранилища).
##
## Что под курсором, узел узнаёт двумя путями:
## [br]— физические тела, у которых есть метод [code]tooltip_model()[/code]:
##   [IngredientNode], [ContainerChip], [SpiceNode], [ShopItemNode];
## [br]— узлы-источники из группы [constant SOURCE_GROUP] с методом
##   [code]tooltip_model_at(global_point)[/code] — окна HUD, которые рисуют
##   свои предметы сами ([HudToolStorage], [HudToolButton]). Они идут первыми:
##   окно лежит поверх сцены, значит и подсказка у него важнее.
##
## Сам текст собирает [TooltipContent]: название, описание или эффект, а у
## ингредиентов без эффекта — доля звезды («звезда, затем значение»).
##
## Окно — одна из двух картинок ([member window_small] и
## [member window_large]): маленькая берётся, пока текст короткий
## ([member large_when_lines] строк и не шире [member large_when_width]),
## иначе большая. Выбранная картинка растягивается ровно под размер текста,
## поэтому окно всегда по нему. Пока картинок нет, рисуется
## прямоугольник-заглушка — систему видно и без арта.
class_name HoverTooltip
extends Node2D

## Группа узлов-источников: HUD-окна, которые сами говорят, какой предмет
## лежит под точкой экрана (метод [code]tooltip_model_at(global_point)[/code]).
const SOURCE_GROUP := &"tooltip_sources"

## Подсказки выключены целиком: экран, который сам расписывает предметы,
## поднимает этот флаг, чтобы не показывать то же самое второй раз
## ([RewardScreen] — описания уже на бумажках). Флаг статический, поэтому
## сцена снимает его на входе.
static var suppressed := false

@export_category("Подсказка при наведении")

@export_group("Окно")
## Картинка маленького окна — для короткого текста.
@export var window_small: Texture2D:
	set(value):
		window_small = value
		queue_redraw()

## Картинка большого окна — берётся, когда текст с картинкой перестают
## помещаться в [member large_when_content].
@export var window_large: Texture2D:
	set(value):
		window_large = value
		queue_redraw()

## Сколько строк текста ещё помещается в маленькое окно; строк больше —
## берётся большое (название считается строкой).
@export_range(1, 12, 1, "or_greater") var large_when_lines := 2:
	set(value):
		large_when_lines = maxi(value, 1)
		queue_redraw()

## Ширина текста, после которой окно тоже меняется на большое, px.
@export var large_when_width := 200.0:
	set(value):
		large_when_width = maxf(value, 0.0)
		queue_redraw()

## Поля окна вокруг содержимого, px.
@export var padding := Vector2(22, 18):
	set(value):
		padding = value.max(Vector2.ZERO)
		queue_redraw()

## Меньше этого размера окна не бывают, px (маленькое и большое).
@export var small_min_size := Vector2(150, 70):
	set(value):
		small_min_size = value.max(Vector2.ZERO)
		queue_redraw()

@export var large_min_size := Vector2(240, 110):
	set(value):
		large_min_size = value.max(Vector2.ZERO)
		queue_redraw()

@export_subgroup("Заглушка без картинок")
@export var fallback_fill := Color(0.11, 0.1, 0.12, 0.94):
	set(value):
		fallback_fill = value
		queue_redraw()

@export var fallback_border := Color(0.85, 0.7, 0.35):
	set(value):
		fallback_border = value
		queue_redraw()

@export_group("Текст")
## Шрифт подсказки. Пусто — шрифт проекта (Grunge Bold V2, см. [UiFont]).
@export var font: Font:
	set(value):
		font = value
		queue_redraw()

@export_range(8, 96, 1, "or_greater") var title_font_size := 20:
	set(value):
		title_font_size = maxi(value, 1)
		queue_redraw()

@export_range(8, 96, 1, "or_greater") var body_font_size := 14:
	set(value):
		body_font_size = maxi(value, 1)
		queue_redraw()

@export var title_color := Color(1.0, 0.93, 0.75):
	set(value):
		title_color = value
		queue_redraw()

@export var body_color := Color(0.87, 0.87, 0.9):
	set(value):
		body_color = value
		queue_redraw()

## Тёмная обводка букв — текст читается на любой картинке окна.
@export_range(0, 12, 1) var outline_size := 4:
	set(value):
		outline_size = maxi(value, 0)
		queue_redraw()

@export var outline_color := Color(0.08, 0.06, 0.05, 0.85):
	set(value):
		outline_color = value
		queue_redraw()

## Ширина, по которой описание переносится на новую строку, px.
@export_range(60.0, 600.0, 1.0, "or_greater") var max_text_width := 230.0:
	set(value):
		max_text_width = maxf(value, 40.0)
		queue_redraw()

## Расстояние между строками — высота шрифта × это число.
@export_range(0.6, 2.5, 0.01, "or_greater") var line_spacing := 1.05:
	set(value):
		line_spacing = maxf(value, 0.5)
		queue_redraw()

## Отступ описания (или строки со звездой) от названия, px.
@export var title_gap := 6.0:
	set(value):
		title_gap = value
		queue_redraw()

@export_group("Звезда")
## Строка «звезда + значение» у ингредиентов без эффекта.
@export var star_radius := 9.0:
	set(value):
		star_radius = maxf(value, 0.0)
		queue_redraw()

@export var star_color := Color(1.0, 0.85, 0.3):
	set(value):
		star_color = value
		queue_redraw()

## Зазор между звездой и значением, px.
@export var star_gap := 6.0:
	set(value):
		star_gap = value
		queue_redraw()

@export_range(8, 96, 1, "or_greater") var star_font_size := 18:
	set(value):
		star_font_size = maxi(value, 1)
		queue_redraw()

@export_group("Поведение")
## Сколько секунд держать курсор на предмете, прежде чем появится подсказка.
@export_range(0.0, 2.0, 0.01, "or_greater") var hover_delay := 0.15:
	set(value):
		hover_delay = maxf(value, 0.0)

## Сдвиг окна от курсора, px. У края экрана окно само переворачивается
## на другую сторону курсора.
@export var cursor_offset := Vector2(20, 22)

## Насколько близко окно подпускается к краю экрана, px.
@export var screen_margin := 10.0

## Прятать подсказку, пока зажата левая кнопка: перетаскиванию и переносу
## товаров окно не мешает.
@export var hide_while_pressed := true

## Цена звезды: по ней считается доля звезды у ингредиентов без эффекта.
## Если задан [member combat_config], значение берётся из него.
@export var points_per_star := 10.0

## Настройки боя — из них берётся цена звезды (da_combat.tres).
@export var combat_config: CombatConfig

@export_group("Редактор")
## Превью в редакторе: подсказка по этому предмету рисуется в начале узла
## (.tres ингредиента, специи или инструмента).
@export var editor_preview_item: Resource:
	set(value):
		editor_preview_item = value
		queue_redraw()

## Что сейчас показано; null — подсказки нет.
var _content: TooltipContent = null
## Модель под курсором (ещё может ждать своей задержки).
var _model: Resource = null
## Сколько курсор держится на этой модели, с.
var _hover_time := 0.0
## Точка курсора, от которой стоит окно (местные координаты).
var _anchor := Vector2.ZERO


## Подключить настройки боя (цена звезды). Режимы игры зовут это при старте,
## если конфиг не назначен узлу в редакторе.
func setup(config: CombatConfig) -> void:
	if config != null:
		combat_config = config


## Убрать подсказку сейчас же (например, когда началось перетаскивание).
func clear() -> void:
	_model = null
	_hover_time = 0.0
	if _content == null:
		return
	_content = null
	queue_redraw()


## Окно стоит у курсора — пока подсказка на экране, перерисовываем её каждый
## кадр. Что под курсором, считается в физическом кадре ([method
## _physics_process]): опрос тел идёт вместе с остальной физикой.
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_content = TooltipContent.for_model(editor_preview_item, _points_per_star())
		_anchor = Vector2.ZERO
		queue_redraw()
		return
	_anchor = to_local(get_global_mouse_position())
	if _content != null:
		queue_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if suppressed:
		clear()
		return
	var was_shown := _content != null
	if hide_while_pressed and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		clear()
		return
	var model := _model_at(get_global_mouse_position())
	if model != _model:
		_model = model
		_hover_time = 0.0
		_content = null
	elif model != null:
		_hover_time += delta
	if _model != null and _hover_time >= hover_delay and _content == null:
		_content = TooltipContent.for_model(_model, _points_per_star())
	# Подсказку убрали — стираем её с экрана.
	if was_shown and _content == null:
		queue_redraw()


# --- Что под курсором ---

## Модель предмета под точкой экрана; null — под курсором ничего нет.
func _model_at(point: Vector2) -> Resource:
	# Окна HUD рисуются поверх сцены — их предметы важнее.
	var sources := get_tree().get_nodes_in_group(SOURCE_GROUP)
	for i in range(sources.size() - 1, -1, -1):
		var source := sources[i] as Node
		if source == null or not source.has_method("tooltip_model_at"):
			continue
		var model := source.call("tooltip_model_at", point) as Resource
		if model != null:
			return model
	# Пока на экране модальное окно инструментов, сцена под ним не отвечает.
	if CombatInputGate.blocked:
		return null
	return _body_model_at(point)


## Модель физического тела под точкой: берётся то, что нарисовано поверх
## других (фишки открытого мешка — над ингредиентами стола). Спрятанные тела
## (закрытый мешок) пропускаются.
func _body_model_at(point: Vector2) -> Resource:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collide_with_bodies = true
	query.collide_with_areas = false
	# Маска по умолчанию покрывает только первые слои — подсказки нужны и на
	# специях (слой 10), и на товарах магазина (слой 12).
	query.collision_mask = 0x7FFFFFFF
	var hits := get_world_2d().direct_space_state.intersect_point(query, 32)
	var best: Resource = null
	var best_z := -0x7FFFFFFF
	for hit in hits:
		var node := hit.collider as CanvasItem
		if node == null or not node.has_method("tooltip_model") \
				or not node.is_visible_in_tree():
			continue
		var model := node.call("tooltip_model") as Resource
		if model == null:
			continue
		var z := _drawing_z(node)
		if best == null or z >= best_z:
			best = model
			best_z = z
	return best


## Слой отрисовки узла с учётом относительных z-индексов родителей: по нему
## видно, кто нарисован поверх кого.
func _drawing_z(node: CanvasItem) -> int:
	var total := 0
	var current := node
	while current != null:
		total += current.z_index
		if not current.z_as_relative:
			break
		current = current.get_parent() as CanvasItem
	return total


func _points_per_star() -> float:
	if combat_config != null:
		return combat_config.points_per_star
	return points_per_star


# --- Отрисовка ---

func _draw() -> void:
	if _content == null:
		return
	var layout := _layout(_content)
	var size: Vector2 = layout["window_size"]
	var origin := _window_origin(size)
	_draw_window(layout["window"] as Texture2D, Rect2(origin, size))
	_draw_content(layout, origin)


## Где встанет окно: у курсора со сдвигом, не вылезая за экран. Если справа
## снизу места нет, окно переворачивается на другую сторону курсора.
func _window_origin(size: Vector2) -> Vector2:
	var view_scale := global_scale.abs()
	var view := get_viewport_rect().size
	if view_scale.x > 0.0 and view_scale.y > 0.0:
		view /= view_scale
	var view_origin := to_local(Vector2.ZERO)
	var origin := _anchor + cursor_offset
	if origin.x + size.x > view_origin.x + view.x - screen_margin:
		origin.x = _anchor.x - cursor_offset.x - size.x
	if origin.y + size.y > view_origin.y + view.y - screen_margin:
		origin.y = _anchor.y - cursor_offset.y - size.y
	var limit := view_origin + view - size - Vector2.ONE * screen_margin
	limit = limit.max(view_origin + Vector2.ONE * screen_margin)
	return origin.clamp(view_origin + Vector2.ONE * screen_margin, limit)


func _draw_window(texture: Texture2D, rect: Rect2) -> void:
	if texture != null:
		draw_texture_rect(texture, rect, false)
		return
	draw_rect(rect, fallback_fill)
	draw_rect(rect, fallback_border, false, 2.0)


## Содержимое окна: строки текста, каждая по центру окна.
func _draw_content(layout: Dictionary, origin: Vector2) -> void:
	var text_font: Font = UiFont.resolve(font)
	var window_size: Vector2 = layout["window_size"]
	var content_size: Vector2 = layout["content_size"]
	var center_x := origin.x + window_size.x / 2.0
	# В окно минимального размера содержимое встаёт серединой, а не прижимается
	# к верхнему полю.
	var y := origin.y + maxf((window_size.y - content_size.y) / 2.0, padding.y)
	for line in layout["lines"]:
		var height: float = line["height"]
		if line["star"]:
			_draw_star_line(Vector2(center_x, y + height / 2.0), text_font, line)
		else:
			_draw_text_line(Vector2(center_x, y + height / 2.0), text_font, line)
		y += height + line["gap"]


## Строка текста, центрированная по точке center (center.y — середина строки).
func _draw_text_line(center: Vector2, text_font: Font, line: Dictionary) -> void:
	var text: String = line["text"]
	var size: int = line["size"]
	var width: float = line["width"]
	var baseline := (text_font.get_ascent(size) - text_font.get_descent(size)) / 2.0
	var at := Vector2(center.x - width / 2.0, center.y + baseline)
	if outline_size > 0:
		draw_string_outline(text_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
				outline_size, outline_color)
	draw_string(text_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, line["color"])


## Строка со звездой: сначала звёздочка, затем значение.
func _draw_star_line(center: Vector2, text_font: Font, line: Dictionary) -> void:
	var width: float = line["width"]
	var star_center := Vector2(center.x - width / 2.0 + star_radius, center.y)
	StarIcon.draw(self, star_center, star_radius, star_color, outline_color)
	var text_line := line.duplicate()
	text_line["width"] = line["text_width"]
	_draw_text_line(Vector2(
			star_center.x + star_radius + star_gap + line["text_width"] / 2.0,
			center.y), text_font, text_line)


# --- Раскладка ---

## Всё, что нужно для отрисовки: строки текста, их общий размер, размер окна
## и его картинка. Размер окна считается по тексту — подсказка всегда по нему.
func _layout(content: TooltipContent) -> Dictionary:
	var text_font := UiFont.resolve(font)
	var lines: Array[Dictionary] = []
	if content.title != "":
		lines.append(_text_line(content.title, title_font_size, title_color, text_font))
	if content.body != "":
		for text in _wrap(content.body, text_font, body_font_size, max_text_width):
			lines.append(_text_line(text, body_font_size, body_color, text_font))
	if content.star_value != "":
		lines.append(_star_line(content.star_value, text_font))
	# Отступ от названия до остальных строк.
	if lines.size() > 1:
		lines[0]["gap"] = title_gap
	var text_size := Vector2.ZERO
	for i in lines.size():
		text_size.x = maxf(text_size.x, lines[i]["width"])
		text_size.y += lines[i]["height"]
		if i < lines.size() - 1:
			text_size.y += lines[i]["gap"]
	# Окно подбирается под текст: пока строк немного и они узкие, хватает
	# маленькой картинки, дальше берётся большая.
	var big := lines.size() > large_when_lines or text_size.x > large_when_width
	var window_texture := window_large if big else window_small
	var min_size := large_min_size if big else small_min_size
	var window_size := (text_size + padding * 2.0).max(min_size)
	return {
		"lines": lines,
		"content_size": text_size,
		"window_size": window_size,
		"window": window_texture,
	}


func _text_line(text: String, size: int, color: Color, text_font: Font) -> Dictionary:
	return {
		"text": text,
		"size": size,
		"color": color,
		"width": text_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x,
		"height": text_font.get_height(size) * line_spacing,
		"gap": 0.0,
		"star": false,
		"text_width": 0.0,
	}


func _star_line(text: String, text_font: Font) -> Dictionary:
	var line := _text_line(text, star_font_size, star_color, text_font)
	line["star"] = true
	line["text_width"] = line["width"]
	line["width"] = star_radius * 2.0 + star_gap + line["width"]
	line["height"] = maxf(line["height"], star_radius * 2.0)
	return line


## Перенос описания по словам: строки не шире width. Слово длиннее строки
## переносить некуда — оно остаётся как есть.
func _wrap(text: String, text_font: Font, size: int, width: float) -> PackedStringArray:
	var result := PackedStringArray()
	for paragraph in text.split("\n"):
		var line := ""
		for word in paragraph.split(" ", false):
			var candidate: String = word if line == "" else line + " " + word
			if line != "" and text_font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT,
					-1, size).x > width:
				result.append(line)
				line = word
			else:
				line = candidate
		if line != "":
			result.append(line)
	return result
