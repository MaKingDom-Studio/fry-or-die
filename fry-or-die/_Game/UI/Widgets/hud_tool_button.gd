@tool
## Кнопка хранилища инструментов — три картинки друг на друге:
## 1. подложка кнопки ([member base_texture]);
## 2. выбранный инструмент — его картинка берётся из списка
##    [member tool_icons], куда закидываются все инструменты сразу; пока
##    инструмент не выбран, рисуется пустая картинка ([member empty_texture],
##    её можно и не задавать);
## 3. аксессуар ([member accessory_texture]) — рисуется поверх всего.
##
## Клик по кнопке открывает и закрывает хранилище ([HudToolStorage]): в нём
## видно все инструменты игрока, а выбранный подсвечен. Кликается вся картинка
## целиком — область берётся по подложке ([method get_global_rect]), клики
## раздаёт [CombatHud]. Под курсором картинка подсвечивается, как кнопка
## мешка ([HudBagButton]). Без картинок рисуется рамка-заглушка размером
## [member fallback_size] — по ней сразу видно место кнопки в редакторе.
class_name HudToolButton
extends Node2D

@export_category("Кнопка инструментов")

## Подложка кнопки — по ней считается её размер.
@export var base_texture: Texture2D:
	set(value):
		base_texture = value
		queue_redraw()

## Масштаб подложки; размер кнопки = размер картинки × масштаб.
@export var base_scale := Vector2.ONE:
	set(value):
		base_scale = value
		queue_redraw()

## Насколько кликабельная область шире картинки, px (может быть < 0).
@export var hit_padding := 0.0:
	set(value):
		hit_padding = value
		queue_redraw()

@export_group("Инструменты")
## Все инструменты и их картинки на кнопке ([ToolIcon]): у каждого своя
## картинка, размер, наклон и сдвиг. Кнопка сама показывает тот значок,
## чей инструмент выбран на раунд.
@export var tool_icons: Array[ToolIcon] = []:
	set(value):
		tool_icons = value
		queue_redraw()

## Картинка «инструмент не выбран». Пусто — слой просто не рисуется.
@export var empty_texture: Texture2D:
	set(value):
		empty_texture = value
		queue_redraw()

## Куда на кнопке ложится значок инструмента, px от её центра.
@export var tool_offset := Vector2.ZERO:
	set(value):
		tool_offset = value
		queue_redraw()

## Карман под значок инструмента: картинка вписывается в него, сохраняя
## пропорции. Работает и для значков из [member tool_icons] — их
## [member ToolIcon.icon_scale] домножает этот размер.
@export var tool_box := Vector2(64, 64):
	set(value):
		tool_box = value.max(Vector2.ONE)
		queue_redraw()

@export_group("Аксессуар")
## Картинка поверх всего — рамка, крючок, наклейка и т.п.
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

@export_group("Свечение под курсором")
## Во сколько раз ярче становится кнопка под курсором (1 — не ярче).
@export var glow_tint := Color(1.45, 1.35, 1.15):
	set(value):
		glow_tint = value
		queue_redraw()

## Ореол вокруг подложки: та же картинка чуть крупнее и полупрозрачная.
@export var halo_color := Color(1.0, 0.85, 0.45, 0.4):
	set(value):
		halo_color = value
		queue_redraw()

@export var halo_padding := 8.0:
	set(value):
		halo_padding = maxf(value, 0.0)
		queue_redraw()

## За сколько секунд свечение разгорается и гаснет.
@export var glow_time := 0.12:
	set(value):
		glow_time = maxf(value, 0.01)
		queue_redraw()

@export_group("Заглушка без картинок")
@export var fallback_size := Vector2(96, 96):
	set(value):
		fallback_size = value.max(Vector2.ONE)
		queue_redraw()

@export var fallback_fill := Color(0.16, 0.15, 0.17, 0.9):
	set(value):
		fallback_fill = value
		queue_redraw()

@export var fallback_border := Color(0.85, 0.7, 0.35):
	set(value):
		fallback_border = value
		queue_redraw()

@export_group("Редактор")
## Какой инструмент показывать в превью редактора: номер записи в
## [member tool_icons]; -1 — показывать пустую картинку.
@export var editor_preview_icon := 0:
	set(value):
		editor_preview_icon = value
		queue_redraw()

## Режим боя (gm_combat). Без типа, чтобы не плодить циклическую зависимость.
var gm = null

## Насколько сейчас разгорелось свечение: 0 — курсора нет, 1 — наведён.
var _glow := 0.0


func attach(game_mode) -> void:
	gm = game_mode


## Кнопка сама говорит подсказке ([HoverTooltip]), что на ней нарисовано.
func _ready() -> void:
	add_to_group(HoverTooltip.SOURCE_GROUP)


## Инструмент под точкой экрана — для подсказки при наведении: на кнопке
## нарисован выбранный инструмент, его подсказка и показывается.
func tooltip_model_at(point: Vector2) -> Resource:
	if not get_global_rect().has_point(point):
		return null
	var active_tool = _active_tool()
	return active_tool.model if active_tool != null else null


## Кликабельная область в экранных координатах.
func get_global_rect() -> Rect2:
	var size := _size() * global_scale.abs()
	return Rect2(global_position - size / 2.0, size).grow(hit_padding)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# Выбранный инструмент меняется по ходу боя — перерисовываем постоянно.
	var target := 1.0 if get_global_rect().has_point(get_global_mouse_position()) else 0.0
	_glow = move_toward(_glow, target, delta / glow_time)
	queue_redraw()


func _draw() -> void:
	var tint := Color.WHITE.lerp(glow_tint, _glow)
	_draw_base(tint)
	_draw_tool(tint)
	if accessory_texture != null:
		IconDraw.draw_scaled(self, accessory_texture, accessory_offset, accessory_scale, tint)


func _draw_base(tint: Color) -> void:
	var rect := Rect2(_size() / -2.0, _size())
	if base_texture == null:
		draw_rect(rect, fallback_fill)
		draw_rect(rect, fallback_border, false, 2.5)
		return
	if _glow > 0.0 and halo_color.a > 0.0 and halo_padding > 0.0:
		var halo := halo_color
		halo.a *= _glow
		draw_texture_rect(base_texture, rect.grow(halo_padding), false, halo)
	draw_texture_rect(base_texture, rect, false, tint)


## Средний слой: значок выбранного инструмента из [member tool_icons]; пока
## он не выбран — пустая картинка. Инструмент, которого в списке нет, рисуется
## своей картинкой ([member ToolModel.texture]) или квадратиком своего цвета —
## значки можно подставлять по одному, ничего не ломая.
func _draw_tool(tint: Color) -> void:
	var icon: ToolIcon = _preview_icon() if Engine.is_editor_hint() \
			else _icon_for(_active_tool())
	if icon != null:
		# Размер значка на кнопке задаёт карман ([member tool_box]), а сдвиг
		# и наклон — сам значок: под кнопку всё подгоняется один раз.
		icon.draw_in_box(self, tool_offset, tool_box, tint)
		return
	if Engine.is_editor_hint():
		_draw_empty(tint)
		return
	var active_tool = _active_tool()
	if active_tool == null:
		_draw_empty(tint)
		return
	if active_tool.model.texture != null:
		IconDraw.draw_fitted(self, active_tool.model.texture, tool_offset, tool_box, tint)
		return
	draw_rect(Rect2(tool_offset - tool_box / 2.0, tool_box), active_tool.model.color * tint)


func _draw_empty(tint: Color) -> void:
	if empty_texture != null:
		IconDraw.draw_fitted(self, empty_texture, tool_offset, tool_box, tint)


## Запись значка для выбранного инструмента; null — инструмент не выбран или
## его нет в списке.
func _icon_for(tool_state) -> ToolIcon:
	if tool_state == null:
		return null
	for icon in tool_icons:
		if icon != null and icon.tool_id() == tool_state.model.id:
			return icon
	return null


## Что показывать в превью редактора: запись под номером
## [member editor_preview_icon].
func _preview_icon() -> ToolIcon:
	if editor_preview_icon < 0 or editor_preview_icon >= tool_icons.size():
		return null
	return tool_icons[editor_preview_icon]


func _active_tool():
	if gm == null or gm.player == null:
		return null
	return gm.player.get_active_tool()


## Размер кнопки: подложка с учётом масштаба, без неё — заглушка.
func _size() -> Vector2:
	if base_texture == null:
		return fallback_size
	return Vector2(base_texture.get_size()) * base_scale.abs()
