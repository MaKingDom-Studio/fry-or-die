@tool
## Мешок игрока (холодильник) — отдельный модальный виджет, не связанный
## с корзинами.
##
## Открывается с анимацией: панель выезжает сверху и опускается на своё
## место (группа «Открытие» в инспекторе), одновременно плавно темнеет
## весь фон. Ингредиенты видны всю дорогу — они разложены по секциям ещё
## до старта и едут вместе с панелью, но анимация на них не влияет: пока
## холодильник в пути, физика фишек на паузе, поэтому кучки не
## расползаются и не падают заново; на месте физика включается, и фишки
## просто оседают. Закрыть мешок можно кликом куда угодно мимо
## холодильника; закрытие — тот же выезд вверх, тоже с содержимым.
##
## Картинку холодильника можно положить в [member texture] (группа
## «Изображение»): она рисуется поверх заливки панели, вписывается по
## выбранному правилу [member texture_fit] и дополнительно настраивается
## смещением, масштабом и цветом. Заливку и рамку панели можно выключить
## ([member show_panel_frame]) — тогда холодильник это только картинка.
##
## При открытии затемняет весь экран, поверх рисуется панель с
## фишками-ингредиентами ([ContainerChip]). Панель разбита на секции:
## четыре основные и одна резервная (самая большая). Секции наполняются
## по порядку кучками, которые гарантированно влезают в их границы;
## всё, что не поместилось в основные, принимает резервная.
##
## Каждая секция живёт на собственном физическом слое (3, 4, 5, ...) —
## фишки и стенки разных секций никак не контактируют друг с другом,
## поэтому секции можно свободно накладывать одну поверх другой.
## Фишки и стенки создаются только на время открытия — закрытый мешок
## не оставляет в мире ни тел, ни стен и не влияет на корзины (слой 2)
## и ингредиенты стола (слой 1).
##
## Границы секций настраиваются в инспекторе (группа «Секции», локальные
## координаты панели), в редакторе видны рамки-превью с подписями.
## Перетаскивание фишки ощущается как ингредиент на столе — та же
## пружина за точку захвата с параметрами из [CombatConfig]
## (см. [method set_drag_params]), только с гравитацией: фишка в руке
## висит на точке захвата и по гравитации стремится вниз, не крутясь
## (угловое трение в руке повышено). Рисуется линия тяги, как на столе;
## при отпускании фишка не отталкивается — просто падает. Двигать фишку
## можно только в пределах её секции. Клик мимо холодильника закрывает
## мешок: холодильник — это картинка (её непрозрачные пиксели) и секции,
## а сама панель — только если её видно; пустые поля панели вокруг
## картинки кликам не мешают (см. [method has_point]).
class_name BagPanel
extends Node2D

signal close_requested

## Как картинка холодильника вписывается в панель.
enum TextureFit {
	## Растянуть по панели, пропорции не сохраняются.
	STRETCH,
	## Вписать целиком, пропорции сохраняются (картинка видна полностью).
	FIT,
	## Покрыть панель целиком, пропорции сохраняются (края выходят за неё).
	COVER,
	## Как есть — родной размер картинки.
	ORIGINAL,
}

## Первый физический слой секций — слой 3 (маска 1 << 2); секция i живёт
## на слое 3 + i, отдельном от корзин (слой 2) и ингредиентов стола (слой 1).
const SECTION_LAYER_SHIFT := 2
const WALL_THICKNESS := 60.0

## Маски альфы картинок холодильника: текстура → [BitMap]. Считаются
## один раз на текстуру, как силуэты ингредиентов ([IngredientNode]).
static var _masks := {}

@export var panel_size := Vector2(720, 400):
	set(value):
		panel_size = value.max(Vector2.ZERO)
		queue_redraw()

@export var title := "":
	set(value):
		title = value
		queue_redraw()

@export_group("Секции")
## Основные секции (локальные координаты панели) — заполняются первыми,
## каждая берёт столько фишек, сколько точно влезает в её границы.
@export var main_sections: Array[Rect2] = [
	Rect2(14, 44, 164, 160),
	Rect2(190, 44, 164, 160),
	Rect2(366, 44, 164, 160),
	Rect2(542, 44, 164, 160),
]:
	set(value):
		main_sections = value
		queue_redraw()

## Резервная секция — самая большая; заполняется, когда в основных
## не хватает места.
@export var reserve_section := Rect2(14, 212, 692, 176):
	set(value):
		reserve_section = value
		queue_redraw()

## Показывать границы секций в игре (в редакторе превью видно всегда).
@export var show_section_borders := false:
	set(value):
		show_section_borders = value
		queue_redraw()

@export_group("Изображение")
## Картинка холодильника: рисуется поверх заливки панели, под фишками.
@export var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()

## Как картинка вписывается в панель до применения [member texture_scale].
@export var texture_fit: TextureFit = TextureFit.FIT:
	set(value):
		texture_fit = value
		queue_redraw()

## Дополнительный масштаб картинки: 1 — как вписалась, больше — крупнее.
@export_range(0.05, 5.0, 0.01, "or_greater") var texture_scale := 1.0:
	set(value):
		texture_scale = maxf(value, 0.01)
		queue_redraw()

## Сдвиг картинки относительно центра панели (локальные пиксели).
@export var texture_offset := Vector2.ZERO:
	set(value):
		texture_offset = value
		queue_redraw()

## Цвет-множитель картинки (прозрачность — альфа).
@export var texture_modulate := Color.WHITE:
	set(value):
		texture_modulate = value
		queue_redraw()

## Считать клик по прозрачному месту картинки кликом мимо холодильника
## (мешок закроется). Выключено — холодильник это весь прямоугольник
## картинки, вместе с прозрачными углами.
@export var texture_alpha_hit := true

@export_group("Открытие")
## Сколько длится выезд панели сверху, секунды. 0 — появляться сразу.
@export_range(0.0, 3.0, 0.01) var open_duration := 0.45:
	set(value):
		open_duration = maxf(value, 0.0)

## Откуда панель начинает выезд — сдвиг от её места в сцене. По умолчанию
## далеко вверх, чтобы холодильник выезжал из-за верхнего края экрана.
@export var open_offset := Vector2(0.0, -900.0)

@export var open_transition: Tween.TransitionType = Tween.TRANS_BACK
@export var open_ease: Tween.EaseType = Tween.EASE_OUT

## Сколько длится уезд панели вверх при закрытии, секунды. 0 — закрывать
## сразу.
@export_range(0.0, 3.0, 0.01) var close_duration := 0.18:
	set(value):
		close_duration = maxf(value, 0.0)

@export_group("Вид")
## Рисовать заливку и рамку панели. Выключено — холодильник это только
## картинка из [member texture].
@export var show_panel_frame := true:
	set(value):
		show_panel_frame = value
		queue_redraw()

## Крестик в углу панели. Мешок и так закрывается кликом мимо
## холодильника, поэтому по умолчанию крестика нет.
@export var show_close_button := false:
	set(value):
		show_close_button = value
		queue_redraw()

@export var fill_color := Color(0.32, 0.3, 0.28):
	set(value):
		fill_color = value
		queue_redraw()

@export var border_color := Color(0.85, 0.65, 0.35):
	set(value):
		border_color = value
		queue_redraw()

@export var title_color := Color(0.96, 0.93, 0.88):
	set(value):
		title_color = value
		queue_redraw()

@export var title_font_size := 16:
	set(value):
		title_font_size = maxi(value, 1)
		queue_redraw()

## Затемнение всего фона при открытом мешке: нарастает и спадает вместе
## с выездом панели. Альфа — насколько густо; сцена под холодильником
## должна лишь угадываться.
@export var dim_color := Color(0.0, 0.0, 0.0, 0.8):
	set(value):
		dim_color = value
		queue_redraw()

## Масштаб фишек относительно радиуса ингредиента (1 — размер как на поле).
@export var chip_scale := 1.0

var _chips: Array[ContainerChip] = []
var _walls: Array[StaticBody2D] = []
## Общая пружина перетаскивания фишек ([ChipDragger]) — как у корзин.
var _dragger := ChipDragger.new()
var _drag_bounds := Rect2()
var _line_overlay: Node2D
## Затемнение фона: отдельный неподвижный слой под панелью.
var _dim_overlay: Node2D
## Место панели из сцены — точка, куда она приезжает при открытии.
var _home_position := Vector2.ZERO
## Мешок открыт (не закрывается): пока идёт уезд вверх — уже false.
var _open := false
## Ход анимации: 0 — панель за верхним краем и фон не затемнён, 1 —
## панель на месте и фон затемнён полностью. Значение ведёт анимация
## открытия и закрытия.
var _open_t := 0.0
var _tween: Tween
## Панель едет, а фишки заморожены и едут вместе с ней.
var _riding := false
## Места фишек на момент начала поездки (глобальные координаты).
var _chip_home: Array[Vector2] = []
## Где была панель, когда поездка началась, — от этой точки считается,
## насколько сдвинуть фишки.
var _ride_origin := Vector2.ZERO


func _ready() -> void:
	# Место из сцены запоминается до анимаций: панель всегда приезжает
	# именно туда, куда её поставили в редакторе.
	_home_position = position
	if Engine.is_editor_hint():
		return
	# Затемнение фона — отдельный слой под панелью (z 120 - 1): он
	# top_level, поэтому стоит на месте, пока панель едет сверху вниз.
	_dim_overlay = Node2D.new()
	_dim_overlay.top_level = true
	_dim_overlay.z_index = z_index - 1
	_dim_overlay.draw.connect(_draw_dim)
	add_child(_dim_overlay)
	# Линия тяги — отдельный слой поверх фишек: фишки (top_level) рисуются
	# с z панели + 1, слой линии — обычный ребёнок с относительным z 2.
	_line_overlay = Node2D.new()
	_line_overlay.z_index = 2
	_line_overlay.draw.connect(_draw_drag_line)
	add_child(_line_overlay)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not visible:
		return
	# И фишка, и курсор постоянно движутся — перерисовываем каждый кадр.
	_line_overlay.queue_redraw()
	# Затемнение живёт по всему экрану и меняется во время анимации —
	# перерисовываем его тем же кадром.
	_dim_overlay.queue_redraw()


## Перенять параметры пружины и линии тяги из конфига боя — перетаскивание
## фишек ощущается и выглядит так же, как перетаскивание на столе.
func set_drag_params(config: CombatConfig) -> void:
	_dragger.set_params(config)


## Панель в локальных координатах узла (для отрисовки).
func panel_rect() -> Rect2:
	return Rect2(Vector2.ZERO, panel_size)


## Панель в глобальных координатах (учитывает масштаб узла из редактора).
func panel_global_rect() -> Rect2:
	return Rect2(global_position, panel_size * global_scale)


## Место картинки холодильника в локальных координатах панели: сначала
## по правилу [member texture_fit], затем масштаб и сдвиг из инспектора.
## Пустой прямоугольник — картинки нет.
func texture_rect() -> Rect2:
	if texture == null:
		return Rect2()
	var tex_size := texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return Rect2()
	var rect := panel_rect()
	var fitted := tex_size
	match texture_fit:
		TextureFit.STRETCH:
			fitted = rect.size
		TextureFit.FIT:
			fitted = tex_size * minf(rect.size.x / tex_size.x, rect.size.y / tex_size.y)
		TextureFit.COVER:
			fitted = tex_size * maxf(rect.size.x / tex_size.x, rect.size.y / tex_size.y)
	fitted *= texture_scale
	return Rect2(rect.position + (rect.size - fitted) / 2.0 + texture_offset, fitted)


## Холодильник в локальных координатах — то, по чему клик мешок не
## закрывает. Есть картинка — холодильник это она: панель может быть
## заметно шире (картинка вписывается в неё с полями) и невидима, а
## закрывать мешок кликом рядом с картинкой должно получаться. Панель
## добавляется, только когда её видно: заливка или рамка непрозрачны.
## Секции — всегда: у их края фишку ещё берут, а не закрывают мешок.
func content_rect() -> Rect2:
	var rect := texture_rect()
	var has_rect := rect.size.x > 0.0 and rect.size.y > 0.0
	if _frame_visible() or not has_rect:
		rect = rect.merge(panel_rect()) if has_rect else panel_rect()
	for section in section_rects():
		rect = rect.merge(section)
	return rect


## Холодильник в глобальных координатах ([method content_rect] с учётом
## положения и масштаба узла).
func content_global_rect() -> Rect2:
	var rect := content_rect()
	return Rect2(to_global(rect.position), rect.size * global_scale)


## Видно ли саму панель: непрозрачна заливка или рамка. Невидимую панель
## (её прячут, когда холодильник — только картинка) в область клика не
## берём, иначе мешок не закрывался бы кликом рядом с картинкой.
func _frame_visible() -> bool:
	return show_panel_frame and (fill_color.a > 0.0 or border_color.a > 0.0)


## Попала ли точка в холодильник. Грубо — прямоугольник картинки (или
## панели) и границы секций; точно — по непрозрачным пикселям картинки,
## как коллизия ингредиентов на столе: клик по прозрачному углу картинки
## это клик мимо, и мешок закроется.
func has_point(global_point: Vector2) -> bool:
	var local := to_local(global_point)
	for section in section_rects():
		if section.has_point(local):
			return true
	var tex := texture_rect()
	if tex.size.x <= 0.0 or tex.size.y <= 0.0:
		return panel_rect().has_point(local)
	if not tex.has_point(local):
		# Мимо картинки, но по видимой панели — всё ещё холодильник.
		return _frame_visible() and panel_rect().has_point(local)
	return not texture_alpha_hit or _texture_opaque_at(local, tex)


## Непрозрачен ли пиксель картинки под точкой. Маска альфы считается
## один раз на текстуру и кэшируется — как силуэты ингредиентов.
func _texture_opaque_at(local: Vector2, rect: Rect2) -> bool:
	var bitmap := _alpha_mask()
	if bitmap == null:
		return true
	var size := bitmap.get_size()
	var uv := (local - rect.position) / rect.size
	return bitmap.get_bitv(Vector2i(
			clampi(int(uv.x * size.x), 0, size.x - 1),
			clampi(int(uv.y * size.y), 0, size.y - 1)))


func _alpha_mask() -> BitMap:
	if _masks.has(texture):
		return _masks[texture]
	var bitmap: BitMap = null
	var image := texture.get_image()
	if image != null and not image.is_empty():
		if image.is_compressed():
			image.decompress()
		bitmap = BitMap.new()
		bitmap.create_from_image_alpha(image)
	_masks[texture] = bitmap
	return bitmap


## Все секции по порядку заполнения: основные, затем резервная (последняя).
func section_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	rects.append_array(main_sections)
	rects.append(reserve_section)
	return rects


func set_title(text: String) -> void:
	title = text


## Открыт ли мешок. Пока идёт закрывающая анимация, мешок уже считается
## закрытым — режим (магазин, бой) снова живёт своей жизнью.
func is_open() -> bool:
	return _open


## Открыть мешок: секции сразу наполняются кучками по порядку — сначала
## основные (каждая берёт столько фишек, сколько гарантированно влезает
## в её границы), остаток принимает резервная, — и полный холодильник
## выезжает сверху и опускается на своё место, затемняя фон. Фишки едут
## вместе с панелью, но анимация на них не влияет: пока панель в пути,
## их физика на паузе и кучки не расползаются.
func open(models: Array[IngredientModel]) -> void:
	_open = true
	visible = true
	_kill_tween()
	# Наполняем панель на её месте — фишки сразу встают туда, где
	# останутся после приезда, и трястись по дороге им незачем.
	position = _home_position
	_fill(models)
	if Engine.is_editor_hint() or open_duration <= 0.0:
		_open_t = 1.0
		return
	_open_t = 0.0
	_begin_ride()
	_apply_slide(open_offset)
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_method(_apply_slide, open_offset, Vector2.ZERO, open_duration) \
			.set_trans(open_transition).set_ease(open_ease)
	_tween.tween_property(self, "_open_t", 1.0, open_duration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_callback(_end_ride)


## Закрыть мешок: полный холодильник уезжает вверх (фишки едут с ним, их
## физика снова на паузе), затемнение спадает, и уже за краем экрана
## фишки со стенками удаляются — в мире ничего не остаётся.
func close() -> void:
	_open = false
	_dragger.release()
	_kill_tween()
	if Engine.is_editor_hint() or close_duration <= 0.0 or not visible:
		_finish_close()
		return
	var from := position - _home_position
	_begin_ride()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_method(_apply_slide, from, open_offset, close_duration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "_open_t", 0.0, close_duration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(_finish_close)


## Панель едет: сдвиг от её места в сцене задаётся анимацией, фишки
## сдвигаются ровно на столько же — тем же кадром, поэтому содержимое
## не отстаёт от холодильника.
func _apply_slide(offset: Vector2) -> void:
	position = _home_position + offset
	if not _riding:
		return
	var moved := global_position - _ride_origin
	for i in _chips.size():
		_chips[i].global_position = _chip_home[i] + moved


## Панель тронулась: фишки запоминают свои места и замирают — движение
## холодильника их не расшвыривает, кучки едут как есть.
func _begin_ride() -> void:
	_chip_home.clear()
	for chip in _chips:
		chip.freeze = true
		_chip_home.append(chip.global_position)
	_ride_origin = global_position
	_riding = true


## Панель приехала: фишкам возвращается обычная физика — они стоят там
## же, где ехали, поэтому кучки просто оседают, а не падают заново.
func _end_ride() -> void:
	if not _riding:
		return
	_riding = false
	for chip in _chips:
		chip.freeze = false


func _finish_close() -> void:
	_riding = false
	visible = false
	_open_t = 0.0
	position = _home_position
	_clear_physics()


func _kill_tween() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null


## Наполнить панель, стоящую на своём месте: секции берут кучки по
## порядку. Места фишек считаются от границ секций, поэтому наполнять
## можно только неедущую панель.
func _fill(models: Array[IngredientModel]) -> void:
	_clear_physics()
	# Шаг укладки — от самой крупной фишки, чтобы кучки точно влезали.
	var max_chip_radius := 8.0
	for model in models:
		max_chip_radius = maxf(max_chip_radius, maxf(model.radius * chip_scale, 8.0))
	var step := max_chip_radius * 2.0 + 4.0
	var rects := section_rects()
	var cursor := 0
	for i in rects.size():
		if cursor >= models.size():
			break
		var rect := _to_global_rect(rects[i])
		var layer := _section_layer(i)
		var left := models.size() - cursor
		# Резервная секция — последняя: принимает всё, что не поместилось.
		var count := left if i == rects.size() - 1 else mini(_capacity(rect, step), left)
		if count <= 0:
			continue
		_build_section_walls(rect, layer)
		_spawn_pile(models, cursor, count, rect, layer, max_chip_radius, step)
		cursor += count
	queue_redraw()


func _clear_physics() -> void:
	for chip in _chips:
		chip.queue_free()
	_chips.clear()
	for wall in _walls:
		wall.queue_free()
	_walls.clear()
	_chip_home.clear()
	_riding = false
	_dragger.release()


func _section_layer(index: int) -> int:
	return 1 << (SECTION_LAYER_SHIFT + index)


func _all_sections_mask() -> int:
	var mask := 0
	for i in section_rects().size():
		mask |= _section_layer(i)
	return mask


func _to_global_rect(local: Rect2) -> Rect2:
	return Rect2(to_global(local.position), local.size * global_scale)


## Сколько фишек гарантированно влезает в секцию при укладке кучкой:
## пирамидка от дна — каждый ряд выше на одну фишку уже предыдущего.
func _capacity(rect: Rect2, step: float) -> int:
	var columns := floori((rect.size.x - 4.0) / step)
	var rows := floori((rect.size.y - 4.0) / step)
	var total := 0
	for row in maxi(rows, 0):
		total += maxi(columns - row, 0)
	return total


## Кучка из count фишек, начиная с models[from]: пирамидка от дна секции
## (общая укладка [method ContainerChip.pile_position]) — нижний ряд
## самый широкий; под гравитацией фишки оседают естественной горкой.
## Переполненный резерв досыпает поверх верхнего ряда — лишние фишки
## скатятся по склону кучки, но границы секции не покинут.
func _spawn_pile(models: Array[IngredientModel], from: int, count: int,
		rect: Rect2, layer: int, max_chip_radius: float, step: float) -> void:
	for n in count:
		var chip := ContainerChip.create(models[from + n], chip_scale, layer)
		# Фишки не наследуют масштаб панели — физика без искажений.
		chip.top_level = true
		# Фишки — top_level и рисуются от корня холста: подняться над
		# заливкой панели им помогает собственный z поверх панельного.
		chip.z_index = z_index + 1
		add_child(chip)
		chip.global_position = ContainerChip.pile_position(n, rect, max_chip_radius, step) \
				+ Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
		# Случайный поворот при спавне — кучка оседает неровной.
		chip.rotation = randf_range(0.0, TAU)
		_chips.append(chip)


## Четыре стенки по периметру секции — фишки не покидают её границы.
func _build_section_walls(rect: Rect2, layer: int) -> void:
	var half := WALL_THICKNESS / 2.0
	var horizontal := Vector2(rect.size.x + WALL_THICKNESS * 2.0, WALL_THICKNESS)
	var vertical := Vector2(WALL_THICKNESS, rect.size.y + WALL_THICKNESS * 2.0)
	var walls := [
		[Vector2(rect.get_center().x, rect.position.y - half), horizontal],
		[Vector2(rect.get_center().x, rect.end.y + half), horizontal],
		[Vector2(rect.position.x - half, rect.get_center().y), vertical],
		[Vector2(rect.end.x + half, rect.get_center().y), vertical],
	]
	for wall_data in walls:
		var wall := StaticBody2D.new()
		wall.top_level = true
		wall.collision_layer = layer
		wall.collision_mask = layer
		var shape := RectangleShape2D.new()
		shape.size = wall_data[1]
		var collision := CollisionShape2D.new()
		collision.shape = shape
		wall.add_child(collision)
		add_child(wall)
		wall.global_position = wall_data[0]
		_walls.append(wall)


# --- Ввод: мешок модальный, клики дальше не проходят ---

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not visible:
		return
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	get_viewport().set_input_as_handled()
	# Панель ещё уезжает вверх — мешок уже закрыт, клики просто гасим,
	# чтобы они не доставались сцене под затемнением.
	if not _open:
		return
	var point := get_global_mouse_position()
	if button.pressed:
		# Клик куда угодно мимо холодильника (или по крестику, если он
		# включён) закрывает мешок.
		if not has_point(point) \
				or (show_close_button and _close_global_rect().has_point(point)):
			Audio.play(AudioDirector.CLICK)
			close_requested.emit()
			return
		# Пока холодильник едет, фишки замерли — брать их не за что.
		if _riding:
			return
		var chip := _chip_at(point)
		if chip != null:
			_dragger.grab(chip, point)
			_drag_bounds = _section_global_rect_of(chip.collision_layer)
	else:
		_dragger.release()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_dragger.release()


## Цель пружины: курсор, зажатый границами секции фишки. Отступ
## минимальный — цель остаётся под мышкой даже у края секции, а наружу
## фишку всё равно не выпустят стенки.
func _drag_target() -> Vector2:
	var inner := _drag_bounds.grow(-2.0)
	inner.size = inner.size.max(Vector2.ZERO)
	return get_global_mouse_position().clamp(inner.position, inner.end)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or not _dragger.is_dragging():
		return
	_dragger.process(_drag_target())


func _draw_drag_line() -> void:
	if _dragger.is_dragging():
		_dragger.draw_drag_line(_line_overlay, _drag_target())


## Глобальные границы секции, которой принадлежит фишка (по её слою).
func _section_global_rect_of(layer: int) -> Rect2:
	var rects := section_rects()
	for i in rects.size():
		if _section_layer(i) == layer:
			return _to_global_rect(rects[i])
	return panel_global_rect()


func _chip_at(global_point: Vector2) -> ContainerChip:
	for body in GrabArea.bodies_at(get_world_2d(), global_point,
			_dragger.grab_radius, _all_sections_mask()):
		var chip := body as ContainerChip
		if chip != null:
			return chip
	return null


func _close_rect() -> Rect2:
	return Rect2(panel_size.x - 40.0, 10.0, 30.0, 30.0)


func _close_global_rect() -> Rect2:
	var local := _close_rect()
	return Rect2(to_global(local.position), local.size * global_scale)


## Затемнение всего экрана: слой неподвижен (top_level), поэтому рисуется
## прямо по размеру вьюпорта; плотность растёт вместе с выездом панели.
func _draw_dim() -> void:
	_dim_overlay.draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size),
			Color(dim_color, dim_color.a * _open_t))


func _draw() -> void:
	var font := ThemeDB.fallback_font
	if show_panel_frame:
		draw_rect(panel_rect(), fill_color)
	var tex_rect := texture_rect()
	if texture != null and tex_rect.size.x > 0.0 and tex_rect.size.y > 0.0:
		draw_texture_rect(texture, tex_rect, false, texture_modulate)
	if show_panel_frame:
		draw_rect(panel_rect(), border_color, false, 2.0)
	var rects := section_rects()
	if Engine.is_editor_hint() or show_section_borders:
		for rect in rects:
			draw_rect(rect, Color(border_color, 0.45), false, 1.0)
	if Engine.is_editor_hint():
		for i in rects.size():
			var caption := "Reserve" if i == rects.size() - 1 else str(i + 1)
			draw_string(font, rects[i].position + Vector2(5.0, 14.0), caption,
					HORIZONTAL_ALIGNMENT_LEFT, maxf(rects[i].size.x - 10.0, 10.0), 10,
					Color(title_color, 0.7))
	draw_string(font, Vector2(0.0, 18.0), title,
			HORIZONTAL_ALIGNMENT_CENTER, panel_size.x, title_font_size, title_color)
	if show_close_button:
		var close := _close_rect()
		draw_rect(close, Color(0.6, 0.25, 0.2))
		draw_string(font, Vector2(close.position.x, close.position.y + 21.0), "×",
				HORIZONTAL_ALIGNMENT_CENTER, close.size.x, 16, Color(0.98, 0.95, 0.92))
