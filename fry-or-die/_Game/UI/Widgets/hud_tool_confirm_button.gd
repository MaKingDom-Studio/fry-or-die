@tool
## Кнопка под хранилищем инструментов: закрывает выбор и пускает раунд
## дальше — к кнопке «Обратный отсчёт».
##
## У кнопки два состояния, и картинка сама и есть кнопка:
## [br]— инструмент не выбран — «Пропустить» ([member skip_texture]): раунд
##   можно играть и без инструмента, кнопка спокойная;
## [br]— инструмент выбран — «Продолжить» ([member continue_texture]), и
##   картинка пульсирует: видно, что выбор сделан и пора продолжать.
##
## Кнопка живёт только на время выбора и прячется вместе с окном
## ([HudToolToggleButton]). Клики раздаёт [CombatHud].
class_name HudToolConfirmButton
extends Node2D

@export_category("Кнопка продолжить/пропустить")

## Картинка «Пропустить» — инструмент не выбран.
@export var skip_texture: Texture2D:
	set(value):
		skip_texture = value
		queue_redraw()

## Картинка «Продолжить» — инструмент выбран; она же пульсирует.
@export var continue_texture: Texture2D:
	set(value):
		continue_texture = value
		queue_redraw()

## Масштаб картинки; размер кнопки = размер картинки × масштаб.
@export var texture_scale := Vector2.ONE:
	set(value):
		texture_scale = value
		queue_redraw()

## Насколько кликабельная область шире картинки, px (может быть < 0).
@export var hit_padding := 0.0:
	set(value):
		hit_padding = value
		queue_redraw()

@export_group("Пульсация с выбранным инструментом")
## Насколько кнопка раздувается на пике пульса (0.1 — на 10%).
@export_range(0.0, 1.0) var pulse_scale := 0.09:
	set(value):
		pulse_scale = clampf(value, 0.0, 1.0)
		queue_redraw()

## Как быстро идёт пульсация (радиан в секунду).
@export var pulse_speed := 3.4:
	set(value):
		pulse_speed = maxf(value, 0.0)
		queue_redraw()

## Свечение на пике пульса (1 — не ярче).
@export var pulse_tint := Color(1.25, 1.18, 1.05):
	set(value):
		pulse_tint = value
		queue_redraw()

@export_group("Заглушка без картинок")
@export var fallback_size := Vector2(240, 56):
	set(value):
		fallback_size = value.max(Vector2.ONE)
		queue_redraw()

@export var skip_fill := Color(0.26, 0.26, 0.29, 0.95):
	set(value):
		skip_fill = value
		queue_redraw()

@export var continue_fill := Color(0.2, 0.62, 0.28, 0.97):
	set(value):
		continue_fill = value
		queue_redraw()

@export var border_color := Color(0.92, 0.88, 0.75):
	set(value):
		border_color = value
		queue_redraw()

@export var skip_label := "SKIP":
	set(value):
		skip_label = value
		queue_redraw()

@export var continue_label := "CONTINUE":
	set(value):
		continue_label = value
		queue_redraw()

@export_range(6, 200, 1, "or_greater") var font_size := 22:
	set(value):
		font_size = maxi(value, 6)
		queue_redraw()

## Режим боя (gm_combat) — по нему видно, выбран ли инструмент.
var gm = null
## HUD боя ([CombatHud]) — у него состояние окна выбора.
var hud = null

var _time := 0.0


func attach(game_mode) -> void:
	gm = game_mode


## Кнопка на экране: идёт выбор инструмента и окно не спрятано.
func is_active() -> bool:
	return hud != null and hud.is_tool_select_shown()


## Инструмент на раунд уже выбран — кнопка «Продолжить» и пульсирует.
func is_ready() -> bool:
	return gm != null and gm.player != null and gm.player.get_active_tool() != null


## Кликабельная область в экранных координатах. Пульсация её не трогает —
## кнопка не должна «убегать» из-под курсора.
func get_global_rect() -> Rect2:
	var size := _size() * global_scale.abs()
	return Rect2(global_position - size / 2.0, size).grow(hit_padding)


func _process(delta: float) -> void:
	_time += delta
	# Перерисовываем всегда, а не только пока кнопка на экране: иначе кадр, на
	# котором выбор закончился, остаётся нарисованным и кнопка «застревает».
	queue_redraw()


func _draw() -> void:
	# В редакторе кнопка видна всегда — иначе её не разместить.
	if not is_active() and not Engine.is_editor_hint():
		return
	var ready := is_ready() or (Engine.is_editor_hint() and continue_texture != null)
	# Пульс — только с выбранным инструментом.
	var pulse := (0.5 + 0.5 * sin(_time * pulse_speed)) if ready else 0.0
	var swell := 1.0 + pulse_scale * pulse
	var tint := Color.WHITE.lerp(pulse_tint, pulse)
	var texture := continue_texture if ready else skip_texture
	if texture == null:
		_draw_fallback(ready, swell, tint)
		return
	var size := _size() * swell
	draw_texture_rect(texture, Rect2(-size / 2.0, size), false, tint)


func _draw_fallback(ready: bool, swell: float, tint: Color) -> void:
	var size := fallback_size * swell
	var rect := Rect2(-size / 2.0, size)
	draw_rect(rect, (continue_fill if ready else skip_fill) * tint)
	draw_rect(rect, border_color, false, 2.5)
	draw_string(UiFont.resolve(), Vector2(rect.position.x, font_size * 0.36),
			continue_label if ready else skip_label, HORIZONTAL_ALIGNMENT_CENTER, size.x,
			font_size, border_color)


## Размер кнопки без пульсации: по текущей картинке, а без неё — заглушка.
func _size() -> Vector2:
	var texture := continue_texture if is_ready() else skip_texture
	if texture == null:
		texture = skip_texture if skip_texture != null else continue_texture
	if texture == null:
		return fallback_size
	return Vector2(texture.get_size()) * texture_scale.abs()
