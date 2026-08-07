@tool
## Хранилище инструментов: окно со всеми инструментами игрока.
##
## Одно и то же окно работает в двух режимах — их задаёт [method show_window]:
## [br]— просмотр: открывается кнопкой хранилища ([HudToolButton]), выбранный
##   инструмент подсвечен, но поменять его нельзя, и надписи в окне нет;
## [br]— выбор: окно раскрывает сама игра, как только ингредиенты легли на
##   стол. Только в этом режиме появляется надпись ([member select_title]),
##   а клик по инструменту выбирает его — он начинает светиться. Инструмент
##   на кулдауне затемнён, на нём написано, сколько раундов он ещё пропустит,
##   и выбрать его нельзя.
##
## Места инструментов — список [member slots] (4 штуки, по одному на
## инструмент): у каждого своя картинка, своё место в окне, размер и наклон.
## Рисуются только те, что есть у игрока. Пока список пуст, инструменты
## игрока раскладываются рядом сами — по запасной раскладке.
##
## Поверх инструментов ложатся аксессуары: свой у каждого места
## ([member slot_accessory_texture]) и один на всё окно
## ([member accessory_texture]). Пока окно на экране, фон затемняется
## ([member dim]).
##
## Рядом с окном живут ещё две кнопки-узла: [HudToolToggleButton] слева
## прячет и показывает окно, [HudToolConfirmButton] снизу продолжает раунд.
## Клики раздаёт [CombatHud] — он же держит режим окна.
class_name HudToolStorage
extends Node2D

## Готовое к отрисовке место инструмента: где рисовать, чем и чей это
## инструмент. Собирается каждый кадр из [member slots] (или из запасной
## раскладки) и инструментов игрока.
class SlotView extends RefCounted:
	## Значок из [member HudToolStorage.slots]; null — запасная раскладка.
	var icon: ToolIcon = null
	## Инструмент игрока в этом месте; null — превью в редакторе.
	var state = null
	## Место значка в местных координатах — по нему идут клик, затемнение
	## кулдауна и свечение.
	var rect := Rect2()
	## Центр места: вокруг него рисуется значок со своим сдвигом и наклоном.
	var center := Vector2.ZERO

@export_category("Хранилище инструментов")

@export_group("Окно")
## Размер окна, px. По нему считается место фона-заглушки и запасная раскладка.
@export var panel_size := Vector2(560, 250):
	set(value):
		panel_size = value.max(Vector2.ONE)
		queue_redraw()

## Картинка окна; вписывается в [member panel_size].
@export var background_texture: Texture2D:
	set(value):
		background_texture = value
		queue_redraw()

## Заливка и рамка окна, пока картинки нет.
@export var panel_fill := Color(0.13, 0.12, 0.14, 0.94):
	set(value):
		panel_fill = value
		queue_redraw()

@export var panel_border := Color(0.85, 0.7, 0.35):
	set(value):
		panel_border = value
		queue_redraw()

## Затемнение всего экрана, пока окно открыто; прозрачный — без затемнения.
## В редакторе не рисуется, чтобы не мешать вёрстке.
@export var dim := Color(0.0, 0.0, 0.0, 0.55):
	set(value):
		dim = value
		queue_redraw()

@export_group("Инструменты")
## Места инструментов: 4 штуки, по одному на инструмент ([ToolIcon]).
## У каждого — свой инструмент, картинка, место в окне, размер и наклон.
## Рисуются только те инструменты, что есть у игрока. Пусто — работает
## запасная раскладка.
@export var slots: Array[ToolIcon] = []:
	set(value):
		slots = value
		queue_redraw()

@export_subgroup("Запасная раскладка")
## Размер места, пока места не настроены, px.
@export var slot_size := Vector2(104, 104):
	set(value):
		slot_size = value.max(Vector2.ONE)
		queue_redraw()

## Сколько мест в строке; дальше идёт перенос.
@export_range(1, 12) var columns := 4:
	set(value):
		columns = maxi(value, 1)
		queue_redraw()

## Промежуток между местами, px.
@export var slot_spacing := Vector2(22, 18):
	set(value):
		slot_spacing = value
		queue_redraw()

## Сдвиг всей запасной раскладки относительно центра окна, px.
@export var grid_offset := Vector2(0, 16):
	set(value):
		grid_offset = value
		queue_redraw()

## Подложка места; прозрачная — подложки не рисуются.
@export var slot_fill := Color(0.2, 0.19, 0.22, 0.85):
	set(value):
		slot_fill = value
		queue_redraw()

@export var slot_border := Color(0.45, 0.4, 0.35, 0.9):
	set(value):
		slot_border = value
		queue_redraw()

@export_group("Аксессуары")
## Картинка поверх каждого инструмента (держатель, стекло, крючок).
@export var slot_accessory_texture: Texture2D:
	set(value):
		slot_accessory_texture = value
		queue_redraw()

@export var slot_accessory_scale := Vector2.ONE:
	set(value):
		slot_accessory_scale = value
		queue_redraw()

@export var slot_accessory_offset := Vector2.ZERO:
	set(value):
		slot_accessory_offset = value
		queue_redraw()

## Картинка поверх всего окна — рисуется последней, над инструментами.
@export var accessory_texture: Texture2D:
	set(value):
		accessory_texture = value
		queue_redraw()

@export var accessory_scale := Vector2.ONE:
	set(value):
		accessory_scale = value
		queue_redraw()

@export var accessory_offset := Vector2.ZERO:
	set(value):
		accessory_offset = value
		queue_redraw()

@export_group("Надпись выбора")
## Надпись появляется, только когда окно открывает сама игра — чтобы выбрать
## инструмент на раунд. Кнопкой хранилища окно открывается без неё.
## Перенос строки — обычный Enter в поле: каждая строка центрируется сама.
@export_multiline var select_title := "Choose a tool\nfor this battle":
	set(value):
		select_title = value
		queue_redraw()

## Место надписи относительно центра окна, px.
@export var title_offset := Vector2(0, -92):
	set(value):
		title_offset = value
		queue_redraw()

## Шрифт надписи. Пусто — шрифт проекта (Grunge Bold V2, см. [UiFont]).
@export var font: Font:
	set(value):
		font = value
		queue_redraw()

@export_range(6, 200, 1, "or_greater") var title_font_size := 30:
	set(value):
		title_font_size = maxi(value, 6)
		queue_redraw()

@export var title_color := Color(0.97, 0.93, 0.82):
	set(value):
		title_color = value
		queue_redraw()

@export var title_outline_size := 6:
	set(value):
		title_outline_size = maxi(value, 0)
		queue_redraw()

@export var title_outline_color := Color(0.12, 0.09, 0.06, 0.85):
	set(value):
		title_outline_color = value
		queue_redraw()

## Расстояние между строками: высота шрифта × это число.
@export_range(0.5, 3.0, 0.05, "or_greater") var title_line_spacing := 1.0:
	set(value):
		title_line_spacing = maxf(value, 0.1)
		queue_redraw()

@export_subgroup("Дрожь букв")
## Как у имён сторон ([HudNameLabel]): 0 — буквы не трясёт.
@export var jitter_amount := 1.2:
	set(value):
		jitter_amount = maxf(value, 0.0)
		queue_redraw()

@export var jitter_speed := 7.0:
	set(value):
		jitter_speed = maxf(value, 0.0)
		queue_redraw()

@export var jitter_rotation := 2.5:
	set(value):
		jitter_rotation = value
		queue_redraw()

@export_group("Кулдаун")
## Затемнение инструмента, который пропускает раунды.
@export var cooldown_overlay := Color(0.04, 0.04, 0.05, 0.72):
	set(value):
		cooldown_overlay = value
		queue_redraw()

## Цифра — сколько раундов инструмент ещё пропустит.
@export var cooldown_text_color := Color(0.97, 0.95, 0.9):
	set(value):
		cooldown_text_color = value
		queue_redraw()

@export_range(6, 200, 1, "or_greater") var cooldown_font_size := 40:
	set(value):
		cooldown_font_size = maxi(value, 6)
		queue_redraw()

@export var cooldown_outline_size := 6:
	set(value):
		cooldown_outline_size = maxi(value, 0)
		queue_redraw()

@export_group("Выбранный инструмент")
## Свечение вокруг выбранного инструмента.
@export var glow_color := Color(1.0, 0.85, 0.4, 0.55):
	set(value):
		glow_color = value
		queue_redraw()

## Насколько свечение вылезает за инструмент, px.
@export var glow_padding := 14.0:
	set(value):
		glow_padding = maxf(value, 0.0)
		queue_redraw()

## Из скольких положений собирается контур: больше — ровнее обводка.
## Считается один раз на инструмент, на кадры не влияет.
@export_range(8, 48) var glow_steps := 24:
	set(value):
		glow_steps = maxi(value, 3)
		queue_redraw()

## Обводка выбранного места — только для запасной раскладки (там место
## прямоугольное). У настроенных мест подсветка идёт строго по контуру
## инструмента, рамки нет.
@export var glow_border := Color(1.0, 0.82, 0.3):
	set(value):
		glow_border = value
		queue_redraw()

@export var glow_border_width := 3.0:
	set(value):
		glow_border_width = maxf(value, 0.0)
		queue_redraw()

## Насколько свечение пульсирует (0 — ровное) и как быстро.
@export_range(0.0, 1.0) var glow_pulse := 0.35:
	set(value):
		glow_pulse = clampf(value, 0.0, 1.0)
		queue_redraw()

@export var glow_pulse_speed := 3.2:
	set(value):
		glow_pulse_speed = maxf(value, 0.0)
		queue_redraw()

@export_group("Редактор")
## Сколько мест рисовать в превью редактора, пока [member slots] пуст.
@export_range(0, 12) var editor_preview_slots := 4:
	set(value):
		editor_preview_slots = maxi(value, 0)
		queue_redraw()

## Показывать в редакторе надпись выбора, даже когда окно «просто открыто».
@export var editor_preview_title := true:
	set(value):
		editor_preview_title = value
		queue_redraw()

## Обводить в редакторе места инструментов и подписывать их — по рамкам
## сразу видно раскладку, даже если картинка инструмента ещё не задана.
## В игре рамки не рисуются.
@export var editor_show_slots := true:
	set(value):
		editor_show_slots = value
		queue_redraw()

@export var editor_slot_color := Color(0.35, 0.85, 1.0, 0.9):
	set(value):
		editor_slot_color = value
		queue_redraw()

## Режим боя (gm_combat). Без типа, чтобы не плодить циклическую зависимость.
var gm = null

## Окно на экране.
var _shown := false
## Режим выбора: клик по инструменту его выбирает, и видна надпись.
var _selection := false
var _time := 0.0


func attach(game_mode) -> void:
	gm = game_mode


## Показать окно. selection = true — режим выбора инструмента на раунд.
func show_window(selection := false) -> void:
	_shown = true
	_selection = selection
	queue_redraw()


func hide_window() -> void:
	_shown = false
	queue_redraw()


func is_shown() -> bool:
	return _shown


func is_selection() -> bool:
	return _selection


## Прямоугольник окна в экранных координатах — по нему [CombatHud] понимает,
## что клик пришёлся в окно, а не мимо.
func get_global_rect() -> Rect2:
	var size := panel_size * global_scale.abs()
	return Rect2(global_position - size / 2.0, size)


## Окно само говорит подсказке ([HoverTooltip]), какой инструмент под
## курсором: своих физических тел у него нет.
func _ready() -> void:
	add_to_group(HoverTooltip.SOURCE_GROUP)


## Инструмент под точкой экрана — для подсказки при наведении; null — мимо.
func tooltip_model_at(point: Vector2) -> Resource:
	var state = tool_at(point)
	return state.model if state != null else null


## Инструмент игрока под точкой экрана; null — мимо инструментов.
func tool_at(point: Vector2):
	if not _shown:
		return null
	var local := to_local(point)
	for view in _slot_views():
		if view.state != null and view.rect.has_point(local):
			return view.state
	return null


func _process(delta: float) -> void:
	_time += delta
	if _shown or Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	if not _shown and not Engine.is_editor_hint():
		return
	_draw_dim()
	_draw_panel()
	_draw_title()
	var views := _slot_views()
	for view in views:
		_draw_slot(view)
	if accessory_texture != null:
		IconDraw.draw_scaled(self, accessory_texture, accessory_offset, accessory_scale)
	if Engine.is_editor_hint() and editor_show_slots:
		_draw_slot_marks(views)


## Затемнение всего экрана под окном: сцену видно, но она уходит на второй
## план. В редакторе не рисуется — иначе закрывало бы вёрстку.
func _draw_dim() -> void:
	if Engine.is_editor_hint() or dim.a <= 0.0:
		return
	var view_scale := global_scale.abs()
	if view_scale.x <= 0.0 or view_scale.y <= 0.0:
		return
	draw_rect(Rect2(to_local(Vector2.ZERO), get_viewport_rect().size / view_scale), dim)


func _draw_panel() -> void:
	if background_texture != null:
		IconDraw.draw_fitted(self, background_texture, Vector2.ZERO, panel_size)
		return
	var rect := Rect2(-panel_size / 2.0, panel_size)
	draw_rect(rect, panel_fill)
	draw_rect(rect, panel_border, false, 2.5)


## Надпись — только когда окно открыла сама игра под выбор инструмента.
func _draw_title() -> void:
	if not _selection and not (Engine.is_editor_hint() and editor_preview_title):
		return
	JitterText.draw_centered(self, UiFont.resolve(font), title_offset, select_title,
			title_font_size, title_color, _time, jitter_amount, jitter_speed,
			jitter_rotation, title_outline_size, title_outline_color, title_line_spacing)


func _draw_slot(view: SlotView) -> void:
	# Тип пишем явно: инструмент в месте без типа (ToolState тянул бы за собой
	# цикл зависимостей), и вывести его из сравнения GDScript не может.
	var selected: bool = view.state != null and view.state == _active_tool()
	if selected:
		_draw_glow(view)
	# Подложка — только у запасной раскладки: у настроенных мест фоном
	# работает картинка окна.
	if view.icon == null:
		if slot_fill.a > 0.0:
			draw_rect(view.rect, slot_fill)
		if slot_border.a > 0.0:
			draw_rect(view.rect, slot_border, false, 2.0)
	_draw_tool_icon(view)
	if slot_accessory_texture != null:
		IconDraw.draw_scaled(self, slot_accessory_texture,
				view.rect.get_center() + slot_accessory_offset, slot_accessory_scale)
	if selected and view.icon == null and glow_border.a > 0.0 and glow_border_width > 0.0:
		draw_rect(view.rect, glow_border, false, glow_border_width)
	if view.state != null and not view.state.is_ready():
		_draw_cooldown(view)


## Значок инструмента: настроенный ([ToolIcon] со своим размером и наклоном),
## иначе картинка самого инструмента, а без неё — квадратик его цвета.
func _draw_tool_icon(view: SlotView) -> void:
	if view.icon != null:
		view.icon.draw(self, view.center)
		return
	if view.state == null:
		draw_rect(view.rect, Color(0.5, 0.5, 0.55, 0.55))
		return
	if view.state.model.texture != null:
		IconDraw.draw_fitted(self, view.state.model.texture, view.rect.get_center(),
				view.rect.size * 0.78)
		return
	draw_rect(view.rect.grow(-view.rect.size.x * 0.11), view.state.model.color)


## Инструмент на кулдауне: затемнён, поверх — сколько раундов он пропустит.
func _draw_cooldown(view: SlotView) -> void:
	# Темнеет ровно инструмент: затемнение кладётся по его силуэту. В запасной
	# раскладке место прямоугольное — там и затемнение прямоугольное.
	if view.icon != null:
		view.icon.draw_shade(self, view.center, cooldown_overlay)
	else:
		draw_rect(view.rect, cooldown_overlay)
	var text := str(view.state.cooldown_remaining)
	var text_font := UiFont.resolve(font)
	var baseline := view.rect.get_center() \
			+ Vector2(-view.rect.size.x / 2.0, cooldown_font_size * 0.36)
	if cooldown_outline_size > 0:
		draw_string_outline(text_font, baseline, text, HORIZONTAL_ALIGNMENT_CENTER,
				view.rect.size.x, cooldown_font_size, cooldown_outline_size,
				title_outline_color)
	draw_string(text_font, baseline, text, HORIZONTAL_ALIGNMENT_CENTER, view.rect.size.x,
			cooldown_font_size, cooldown_text_color)


## Рамки мест инструментов — только в редакторе: видно, где стоит каждый
## инструмент, даже под аксессуаром и без картинки. Рядом — имя инструмента
## из его .tres, чтобы не путать места местами.
func _draw_slot_marks(views: Array) -> void:
	var font := ThemeDB.fallback_font
	for view in views:
		# Место берём в свою переменную с типом: в цикле по нетипизированному
		# массиву поля вида — Variant, и вывести из них тип GDScript не может.
		var rect: Rect2 = view.rect
		draw_rect(rect, editor_slot_color, false, 1.5)
		var center := rect.get_center()
		draw_line(center - Vector2(6.0, 0.0), center + Vector2(6.0, 0.0), editor_slot_color, 1.0)
		draw_line(center - Vector2(0.0, 6.0), center + Vector2(0.0, 6.0), editor_slot_color, 1.0)
		var label := _slot_label(view)
		if label != "":
			draw_string(font, Vector2(rect.position.x, rect.position.y - 5.0), label,
					HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 12, editor_slot_color)


## Подпись места в редакторе: имя инструмента, а если оно не задано — id.
func _slot_label(view: SlotView) -> String:
	if view.icon == null or view.icon.tool_model == null:
		return "—"
	var model := view.icon.tool_model
	return model.display_name if model.display_name != "" else str(model.id)


## Свечение выбранного инструмента, слегка пульсирующее. У настроенного места
## обводка идёт строго по контуру инструмента ([method ToolIcon.draw_outline]);
## в запасной раскладке инструмент рисуется в прямоугольном месте, и ореол
## тоже прямоугольный.
func _draw_glow(view: SlotView) -> void:
	if glow_color.a <= 0.0 or glow_padding <= 0.0:
		return
	var pulse := 1.0 - glow_pulse * (0.5 + 0.5 * sin(_time * glow_pulse_speed))
	var halo := glow_color
	halo.a *= pulse
	if view.icon != null:
		# Толщина от пульса не зависит: контур считается заранее и запоминается,
		# поэтому пульсирует только прозрачность — обводка не «дышит» рывками.
		view.icon.draw_outline(self, view.center, halo, glow_padding, glow_steps)
		return
	var rect: Rect2 = view.rect
	draw_rect(rect.grow(glow_padding * pulse), halo)


## Что рисовать в окне: настроенные места ([member slots]) с инструментами
## игрока, а пока их нет — запасная раскладка по инструментам игрока.
## В редакторе места видно и без игрока — по ним и настраивается окно.
func _slot_views() -> Array:
	if not slots.is_empty():
		return _configured_views()
	return _fallback_views()


## Настроенные места: каждое рисуется, только если такой инструмент есть у
## игрока (в редакторе — все, чтобы было что двигать).
func _configured_views() -> Array:
	var views := []
	for icon in slots:
		if icon == null:
			continue
		var state = _tool_by_id(icon.tool_id())
		if state == null and not Engine.is_editor_hint():
			continue
		var view := SlotView.new()
		view.icon = icon
		view.state = state
		view.center = Vector2.ZERO
		view.rect = icon.rect(Vector2.ZERO)
		views.append(view)
	return views


## Запасная раскладка: инструменты игрока ровным рядом по центру окна.
func _fallback_views() -> Array:
	var views := []
	var count := _tool_count() if gm != null else editor_preview_slots
	for i in count:
		var view := SlotView.new()
		view.state = _tool_at_index(i)
		view.center = _grid_center(i, count)
		view.rect = Rect2(view.center - slot_size / 2.0, slot_size)
		views.append(view)
	return views


## Инструмент игрока с таким id; null — такого у игрока нет.
func _tool_by_id(id: StringName):
	if id == &"" or gm == null or gm.player == null:
		return null
	for state in gm.player.tools:
		if state.model != null and state.model.id == id:
			return state
	return null


func _tool_count() -> int:
	if gm == null or gm.player == null:
		return 0
	return gm.player.tools.size()


func _tool_at_index(index: int):
	if gm == null or gm.player == null or index < 0 or index >= gm.player.tools.size():
		return null
	return gm.player.tools[index]


func _active_tool():
	if gm == null or gm.player == null:
		return null
	return gm.player.get_active_tool()


## Центр места в запасной раскладке. Сетка целиком центрируется по окну,
## поэтому один инструмент стоит посередине, а четыре — ровным рядом.
func _grid_center(index: int, count: int) -> Vector2:
	var total := maxi(count, 1)
	var cols := mini(columns, total)
	var rows := ceili(float(total) / float(cols))
	var step := slot_size + slot_spacing
	var origin := grid_offset - Vector2(float(cols - 1) * step.x, float(rows - 1) * step.y) / 2.0
	return origin + Vector2(float(index % cols) * step.x, float(index / cols) * step.y)
