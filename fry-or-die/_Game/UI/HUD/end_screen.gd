@tool
## Финальный экран: открывается после победы над последним боссом
## ([member EnemyModel.is_final_boss] / точка карты [constant MapNode.Kind.BOSS]).
##
## Устроен просто и стоит выше всего в сцене боя: сплошной чёрный фон во весь
## вьюпорт гасит бой под собой, по центру — картинка концовки
## `_Game/Art/Victory_Defeat/END.png`, а снизу, чуть погодя
## ([member EndScreenConfig.button_delay]), появляется кнопка перезапуска
## `Button_Try_Again.png`. Клик по ней — сигнал [signal restart_pressed];
## режим боя по нему уводит игрока с экрана и начинает новый забег.
##
## Пока экран на месте, он модальный: ни бой, ни HUD под ним кликов не
## получают. Раскладка целиком в [EndScreenConfig] (da_window_end.tres) и
## задана долями вьюпорта, поэтому экран одинаково собирается в любом окне;
## в редакторе узел рисует превью со своими картинками.
class_name EndScreen
extends Node2D

## Нажата кнопка перезапуска.
signal restart_pressed

## Откуда берётся картинка концовки, если её не положили в
## [member EndScreenConfig.texture].
const END_TEXTURE_PATH := "res://_Game/Art/Victory_Defeat/END.png"

@export var config: EndScreenConfig

## Насколько проявился экран: 0 — прозрачный, 1 — на месте.
var _fade := 0.0
var _view := Vector2(1152, 648)
## Экран открыт: клики до боя под ним не доходят.
var _open := false
## Кнопка уже появилась — до этого по её месту не кликают.
var _button_shown := false
var _button_hovered := false
## Перезапуск уже запрошен: второй клик ничего не делает.
var _pressed := false
## Картинка концовки, подгруженная по пути (когда её нет в настройках).
var _fallback_texture: Texture2D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if config == null:
		config = EndScreenConfig.new()
	visible = false


## Показать концовку. Вызывающий может не ждать: экран сам проявится и сам
## выложит кнопку.
func open() -> void:
	_view = get_viewport_rect().size
	_open = true
	_pressed = false
	_button_shown = false
	_button_hovered = false
	visible = true
	_fade = 0.0
	# Подсказки при наведении на концовке ни к чему.
	HoverTooltip.suppressed = true
	queue_redraw()
	var tween := create_tween()
	tween.tween_method(_set_fade, 0.0, 1.0, maxf(config.fade_seconds, 0.01))
	await get_tree().create_timer(maxf(config.button_delay, 0.05)).timeout
	if not _open:
		return
	_button_shown = true
	queue_redraw()


func _set_fade(value: float) -> void:
	_fade = clampf(value, 0.0, 1.0)
	queue_redraw()


# --- Ввод ---

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	if not _open or not _button_shown or _pressed:
		return
	# Кнопка под курсором подрастает — видно, что по ней кликают.
	var hovered := _button_base_rect().has_point(get_global_mouse_position())
	if hovered == _button_hovered:
		return
	_button_hovered = hovered
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not _open:
		return
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	# Экран модальный: пока он на месте, до боя под ним клики не доходят.
	get_viewport().set_input_as_handled()
	if not button.pressed or _pressed or not _button_shown:
		return
	if not _button_base_rect().has_point(get_global_mouse_position()):
		return
	_pressed = true
	_button_hovered = false
	Audio.play(AudioDirector.CLICK)
	# Экран уходит — подсказки следующей локации должны работать.
	HoverTooltip.suppressed = false
	queue_redraw()
	restart_pressed.emit()


# --- Отрисовка ---

func _draw() -> void:
	if Engine.is_editor_hint():
		_view = get_viewport_rect().size
		_draw_screen(1.0, true)
		return
	if not _open:
		return
	_draw_screen(_fade, _button_shown)


func _draw_screen(alpha: float, with_button: bool) -> void:
	if config == null:
		return
	# Сплошной фон: он и гасит бой под экраном.
	draw_rect(Rect2(Vector2.ZERO, _view),
			Color(config.background, config.background.a * alpha))
	var picture := end_texture()
	if picture != null:
		draw_texture_rect(picture, _fitted(picture, _box(config.rect)), false,
				Color(1.0, 1.0, 1.0, alpha))
	if with_button:
		_draw_button(alpha)


func _draw_button(alpha: float) -> void:
	var rect := _button_rect()
	if config.button_texture != null:
		draw_texture_rect(config.button_texture, rect, false,
				Color(1.0, 1.0, 1.0, alpha))
		return
	draw_rect(rect, Color(config.button_fill, config.button_fill.a * alpha))
	draw_rect(rect, Color(config.button_border, config.button_border.a * alpha), false, 2.0)
	var font := UiFont.resolve(config.font)
	var size := config.button_font_size
	draw_string(font, Vector2(rect.position.x, rect.get_center().y + size * 0.36),
			config.button_text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size,
			Color(config.button_text_color, config.button_text_color.a * alpha))


## Картинка концовки: из настроек, а если её там нет — END.png по пути
## [constant END_TEXTURE_PATH]. Так свежий END.png достаточно положить
## в `_Game/Art/Victory_Defeat/`, ничего не настраивая.
func end_texture() -> Texture2D:
	if config != null and config.texture != null:
		return config.texture
	if _fallback_texture == null and ResourceLoader.exists(END_TEXTURE_PATH):
		_fallback_texture = load(END_TEXTURE_PATH) as Texture2D
	return _fallback_texture


## Прямоугольник из долей вьюпорта в пиксели.
func _box(rect: Rect2) -> Rect2:
	return Rect2(rect.position * _view, rect.size * _view)


## По этому прямоугольнику кнопка кликается; он же не меняется под курсором —
## иначе на самой кромке кнопка бы дрожала.
func _button_base_rect() -> Rect2:
	return _fitted(config.button_texture, _box(config.button_rect))


## Кнопка, как она нарисована: под курсором чуть крупнее.
func _button_rect() -> Rect2:
	var rect := _button_base_rect()
	if not _button_hovered:
		return rect
	var grown := rect.size * (config.button_hover_scale - 1.0) / 2.0
	return rect.grow_individual(grown.x, grown.y, grown.x, grown.y)


## Картинка, вписанная в прямоугольник с сохранением пропорций и по его
## центру. Без картинки — сам прямоугольник.
static func _fitted(texture: Texture2D, rect: Rect2) -> Rect2:
	if texture == null:
		return rect
	var tex := texture.get_size()
	if tex.x <= 0.0 or tex.y <= 0.0:
		return rect
	var size := tex * minf(rect.size.x / tex.x, rect.size.y / tex.y)
	return Rect2(rect.get_center() - size / 2.0, size)
