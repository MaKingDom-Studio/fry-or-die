@tool
## Чёрно-белый экран: цвет уносит волна, идущая по кадру.
##
## Это эффект водки ([constant IngredientModel.Effect.GRAYSCALE]): осталась
## бутылка на поле игрока — на шаге её подсчёта от самой бутылки кругами
## расходится волна и забирает цвет, а следующий раунд игрок проводит в ЧБ.
## Источник волны ставит режим боя ([method set_origin_global] — по месту
## бутылки на столе), пускает её [method run_wave] (можно дождаться, пока она
## пройдёт) или [method set_active] (пустить и не ждать); идёт она
## [member wave_duration] секунд.
##
## Обратно волна не идёт: цвет возвращается просто угасанием на весь кадр за
## [member fade_duration] — кольца тут были бы лишним событием, раунд в этот
## момент уже кончился.
##
## Как сделано: сам узел — [BackBufferCopy], то есть копия уже нарисованного
## кадра в заднем буфере; поверх него лежит заливка во весь вьюпорт с
## материалом [member overlay_material] (шейдер
## `_Game/Art/Shaders/grayscale.gdshader`), который берёт кадр из буфера и
## смешивает его с обесцвеченной версией. Снаружи фронта волны кадр держит
## прежнее состояние, внутри — новое; размытость фронта, число расходящихся
## колец, их шаг, толщину и цвет настраивает материал.
##
## Обесцвечивается всё, что нарисовано ниже узла по порядку отрисовки:
## z-индекс узла в сцене и решает, что поблекнет, а что останется в цвете.
## В бою узел стоит на 105 — выше HUD (100), но ниже таймера (110): в ЧБ
## уходят стол с ингредиентами, корзины, полка специй, портреты, звёзды и
## окна HUD, а таймер, подписи подсчёта (130) и подсказки (135) — нет.
##
## Заливка создаётся кодом (в сцену не сохраняется) и кроет весь вьюпорт, где
## бы ни стоял узел. Пока эффекта нет, копирование буфера выключено — кадр
## лишний раз не копируется.
class_name GrayscaleOverlay
extends BackBufferCopy

## Параметры шейдера: состояние снаружи фронта, внутри него, прогон волны
## и её источник в экранных UV.
const AMOUNT_FROM_PARAM := "amount_from"
const AMOUNT_TO_PARAM := "amount_to"
const WAVE_PARAM := "wave"
const ORIGIN_PARAM := "wave_origin"

## Материал заливки: шейдер обесцвечивания
## (`_Game/Data/Combat/FX/da_grayscale.tres`). Пусто — эффекта нет, узел
## ничего не рисует.
@export var overlay_material: ShaderMaterial:
	set(value):
		overlay_material = value
		_rebuild_fill()

## Предельная сила эффекта: 1 — полностью чёрно-белый кадр, меньше — кадр
## частично сохраняет цвет.
@export_range(0.0, 1.0, 0.01) var strength := 1.0

## Сколько секунд волна идёт по экрану, унося цвет.
@export_range(0.1, 5.0, 0.05, "or_greater") var wave_duration := 1.8

## За сколько секунд цвет возвращается. Обратно волна не идёт — кадр просто
## светлеет целиком, ровно и без колец.
@export_range(0.0, 3.0, 0.05, "or_greater") var fade_duration := 0.5

## Пауза после того, как волна прошла весь экран: кадр стоит перекрашенным
## целиком, и только потом раунд идёт дальше ([method run_wave] её ждёт).
@export_range(0.0, 2.0, 0.05, "or_greater") var hold_after := 0.4

@export_group("Редактор")
## Превью в редакторе: показать кадр обесцвеченным (в игре не влияет).
@export var editor_preview := false:
	set(value):
		editor_preview = value
		_from = strength if value else 0.0
		_to = _from
		_wave = 1.0
		_apply_shader()

## Заливка с шейдером; создаётся кодом.
var _fill: ColorRect
## Сила эффекта впереди гребня (прежнее состояние) и позади него (новое).
var _from := 0.0
var _to := 0.0
## Прогон волны: 0 — только началась, 1 — прошла весь экран.
var _wave := 1.0
## Идёт возврат цвета: сила эффекта ровно сходит к нулю, без волны.
var _fading := false
## Источник волны в экранных UV; по умолчанию центр экрана.
var _origin := Vector2(0.5, 0.5)


func _ready() -> void:
	_rebuild_fill()
	if Engine.is_editor_hint() and editor_preview:
		_from = strength
		_to = strength
	_apply_shader()
	if not Engine.is_editor_hint():
		get_viewport().size_changed.connect(_resize_fill)


## Откуда пойдёт волна: точка мира (в бою — бутылка водки на столе).
## Держится до следующего вызова, поэтому обратная волна собирает цвет
## в ту же точку. Точка за краем экрана — не беда: волна просто придёт
## оттуда.
func set_origin_global(point: Vector2) -> void:
	var view := get_viewport_rect().size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	# Считаем в единицах вьюпорта, а не в пикселях окна: у CanvasItem
	# get_viewport_transform() включает растяжку под размер окна (режим
	# canvas_items), и тогда на окне крупнее базового центр волны уезжал
	# вниз-вправо, мимо бутылки. Канвас-трансформ растяжки не несёт.
	_origin = (get_viewport().get_canvas_transform() * point) / view
	_apply_shader()


## Навести или снять ЧБ. Наведение идёт волной из [method set_origin_global]
## (ждать не нужно, волна идёт сама; дождаться прохода — [method run_wave]),
## снятие — просто угасанием на весь кадр, без колец.
func set_active(on: bool) -> void:
	if on:
		if is_equal_approx(_to, strength) and not _fading:
			return
		# Прошлая волна, если ещё идёт, считается дошедшей: иначе на экране
		# осталось бы два гребня, а шейдер знает только про один.
		_fading = false
		_from = _to
		_to = strength
		_wave = 0.0
	else:
		if _to <= 0.0 and not _fading:
			return
		# Волну на месте останавливать нельзя (полкадра осталось бы серым),
		# поэтому считаем её дошедшей и гасим уже весь кадр разом.
		_wave = 1.0
		_from = _to
		_fading = true
	_apply_shader()


## Пустить волну и дождаться её — [method set_active] плюс [method await_wave].
func run_wave(on: bool) -> void:
	set_active(on)
	await await_wave()


## Дождаться, пока волна пройдёт весь экран, и выдержать [member hold_after] на
## полностью перекрашенном кадре. Волны нет — возвращается сразу.
func await_wave() -> void:
	if _wave >= 1.0:
		return
	var elapsed := 0.0
	# Страховка по времени: без неё пауза дерева подвесила бы раунд.
	while _wave < 1.0 and elapsed < wave_duration + 1.0:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if hold_after > 0.0:
		await get_tree().create_timer(hold_after).timeout


## Держится ли ЧБ (или уже идёт волна, которая его наведёт).
func is_active() -> bool:
	return _to > 0.0 and not _fading


## Волна ещё в пути.
func is_wave_running() -> bool:
	return _wave < 1.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_resize_fill()
		return
	if _wave < 1.0:
		_wave = minf(_wave + delta / maxf(wave_duration, 0.001), 1.0)
		if _wave >= 1.0:
			# Волна прошла: впереди гребня теперь то же, что позади.
			_from = _to
		_apply_shader()
		return
	if _fading:
		# Волна дошла, кольца не рисуем — гаснет ровно весь кадр.
		_to = maxf(_to - delta / maxf(fade_duration, 0.001) * strength, 0.0)
		_from = _to
		if _to <= 0.0:
			_fading = false
		_apply_shader()


## Проставить состояние в шейдер. Когда цвета не касаемся вовсе (волна прошла
## и эффекта нет), копирование заднего буфера и заливка выключаются — кадр не
## копируется зря.
func _apply_shader() -> void:
	_set_running(_to > 0.0 or _from > 0.0 or _wave < 1.0)
	if _fill == null or not (_fill.material is ShaderMaterial):
		return
	var material := _fill.material as ShaderMaterial
	material.set_shader_parameter(AMOUNT_FROM_PARAM, _from)
	material.set_shader_parameter(AMOUNT_TO_PARAM, _to)
	material.set_shader_parameter(WAVE_PARAM, _wave)
	material.set_shader_parameter(ORIGIN_PARAM, _origin)


func _set_running(on: bool) -> void:
	copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT if on else BackBufferCopy.COPY_MODE_DISABLED
	if _fill != null:
		_fill.visible = on


## Пересобрать заливку: материал свой на узел (копия ресурса), чтобы прогон
## волны не писался в общий .tres. Материала нет — заливки тоже нет: белый
## прямоугольник на весь экран был бы хуже отсутствия эффекта.
func _rebuild_fill() -> void:
	if not is_inside_tree():
		return
	if _fill != null:
		_fill.queue_free()
		_fill = null
	if overlay_material == null:
		return
	_fill = ColorRect.new()
	_fill.name = "Fill"
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill.color = Color.WHITE
	_fill.material = overlay_material.duplicate()
	_fill.visible = false
	add_child(_fill)
	_resize_fill()
	_apply_shader()


## Растянуть заливку на весь вьюпорт. Узел — Node2D, поэтому якоря Control
## тут не работают (см. [BackBufferCopy]): размер считается руками, как у
## затемнения подсчёта ([ScoringDim]).
func _resize_fill() -> void:
	if _fill == null:
		return
	var view := get_viewport_rect().size
	var top_left := to_local(Vector2.ZERO)
	_fill.position = top_left
	_fill.size = to_local(view) - top_left
