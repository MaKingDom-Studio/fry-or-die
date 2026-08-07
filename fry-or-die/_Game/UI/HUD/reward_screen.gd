@tool
## Экран итога боя: награда за победу и поражение.
##
## Победа показывается сразу после боя и работает в два шага:
## [br]1. фон затемняется ([member RewardConfig.dim_color] — 85%), на две
##    секунды ([member RewardConfig.victory_seconds]) появляется картинка
##    победы «You're on fire!»;
## [br]2. на её месте выкладывается счёт ([member RewardConfig.check_texture]):
##    в строке «Total» — звёзды за бой, ниже в ряд предметы награды, а слева
##    и справа от них бумажки с описаниями — левая ([member
##    RewardConfig.sheet_left_texture]) рассказывает про левый предмет,
##    правая ([member RewardConfig.sheet_right_texture]) — про правый.
##    Бумажка предмета, которого нет или которого уже забрали, не рисуется.
##    Предметы обведены по контуру своих картинок ([member
##    RewardConfig.item_outline]) — ингредиент, специя и инструмент
##    одинаково.
##
## Ингредиент и специя лежат на бумажке в свою настоящую величину — ровно
## такие, какими они были в бою на столе и на полке ([method _item_size]).
## Ужатие раскладки ([member RewardConfig.layout_scale]) их не касается:
## награда — это тот самый предмет, а не его уменьшенная картинка. Если
## пара крупных предметов не помещается в мокапные места, места сами
## раздвигаются ([method _slot_centers]).
##
## Описания уже написаны на бумажках, поэтому подсказки при наведении на
## время экрана выключаются ([member HoverTooltip.suppressed]) — второй раз
## то же самое показывать незачем.
##
## Клик по предмету забирает его: он улетает туда, где живёт, — ингредиент
## в холодильник, специя на полку специй (там же и приземляется), инструмент
## в сумку инструментов. Забрали всё — экран сам уходит на карту; осталось
## что-то — уйти можно кнопкой «Пропустить».
##
## Звёзды не выбираются: их ровно столько, сколько нужно было набрать для
## победы над врагом, и начисляет их режим боя при открытии экрана.
##
## Проигранный бой открывает тот же экран поражением ([method open_defeat]):
## на том же затемнении и ровно на месте картинки победы проявляется
## `Defeat.png` ([member RewardConfig.defeat_rect]), а под ней чуть погодя —
## кнопка «Fry Again» (`Button_Try_Again.png`). Забирать нечего, поэтому ни
## счёта, ни бумажек, ни предметов на нём нет: кнопка просто уводит игрока
## тем же сигналом [signal finished], что и «Пропустить» на награде.
##
## Раскладка целиком в [RewardConfig] (da_window_reward.tres) и видна в
## редакторе — узел рисует превью со своими картинками.
class_name RewardScreen
extends Node2D

## Игрок ушёл с экрана: забрал всё, нажал «Пропустить» или, на поражении, —
## «Fry Again».
signal finished

enum Phase {
	## Экрана нет — идёт бой.
	HIDDEN,
	## Картинка победы.
	VICTORY,
	## Счёт с наградой: предметы можно забирать.
	REWARD,
	## Картинка поражения с кнопкой «Fry Again»: награды нет.
	DEFEAT,
	## Уже уходим на карту — клики ничего не делают.
	LEAVING,
}


## Место под предмет награды на бумажке: сама модель, где лежит и куда летит.
class Slot extends RefCounted:
	var model: Resource
	## Где предмет нарисован сейчас: место на бумажке, а в полёте — точка
	## по дороге к цели.
	var at := Vector2.ZERO
	## Размер относительно обычного: в полёте предмет ужимается.
	var factor := 1.0
	## Предмет уже улетел — ни его, ни его бумажку не рисуем.
	var taken := false
	## Предмет в полёте: второй клик по нему ничего не делает.
	var flying := false

	## Можно ли забрать предмет прямо сейчас.
	func is_active() -> bool:
		return not taken and not flying


## Контуры силуэтов картинок для обводки значков:
## {Texture2D: [контуры в долях размера картинки]}.
static var _silhouette_cache := {}

@export var config: RewardConfig

@export_group("Куда улетает забранное")
## Холодильник игрока — туда улетают ингредиенты ([HudBagButton]).
@export var fridge: Node2D
## Полка специй — туда падают специи и там же остаются ([SpiceShelf]).
@export var spice_shelf: SpiceShelf
## Сумка инструментов — туда улетают инструменты ([HudToolButton]).
@export var tool_bag: Node2D

@export_group("Редактор")
## Превью в редакторе: какие предметы разложить по местам (.tres ингредиента,
## специи или инструмента). Пусто — места рисуются пустыми рамками.
@export var editor_preview_items: Array[Resource] = []:
	set(value):
		editor_preview_items = value
		queue_redraw()

## Показать в редакторе не награду, а экран поражения — по нему и
## настраиваются места картинки `Defeat.png` и кнопки «Fry Again».
@export var editor_preview_defeat := false:
	set(value):
		editor_preview_defeat = value
		queue_redraw()

## Режим боя (gm_combat). Без типа, чтобы не плодить циклическую зависимость.
var gm = null

var _phase: Phase = Phase.HIDDEN
var _reward: BattleReward = null
var _slots: Array[Slot] = []
var _view := Vector2(1152, 648)
## Насколько проявился экран: 0 — прозрачный, 1 — на месте.
var _fade := 0.0
## Место под курсором; -1 — курсора на предметах нет.
var _hovered := -1
var _skip_hovered := false
## Экран открыт поражением: награды нет, вместо неё картинка Defeat.png
## и кнопка «Fry Again».
var _defeat := false
## Кнопка «Fry Again» на поражении уже появилась — до этого по её месту
## не кликают.
var _try_again_shown := false
var _try_again_hovered := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if config == null:
		config = RewardConfig.new()
	visible = false


## Показать награду. game_mode — режим боя (нужен цена звезды для описаний),
## battle_reward — что разложить по местам. Вызывающий может не ждать: экран
## сам проведёт игрока от картинки победы до ухода на карту.
func open(game_mode, battle_reward: BattleReward) -> void:
	gm = game_mode
	_reward = battle_reward
	_view = get_viewport_rect().size
	_build_slots(battle_reward.items)
	visible = true
	_phase = Phase.VICTORY
	_defeat = false
	_fade = 0.0
	# Описания уже написаны на бумажках — подсказки при наведении не нужны.
	HoverTooltip.suppressed = true
	queue_redraw()
	var tween := create_tween()
	tween.tween_method(_set_fade, 0.0, 1.0, maxf(config.fade_seconds, 0.01))
	await get_tree().create_timer(maxf(config.victory_seconds, 0.05)).timeout
	# Экран могли закрыть, пока шла картинка победы.
	if _phase != Phase.VICTORY:
		return
	# Картинка победы отыграла со своим звуком — теперь на стол ложится чек,
	# и его слышно ([AudioDirector]).
	Audio.play(AudioDirector.CASH)
	_phase = Phase.REWARD
	queue_redraw()


## Показать поражение: на том же затемнении и на том же месте, где после
## победы висит `Victory.png`, проявляется `Defeat.png`, а под ней чуть
## погодя ([member RewardConfig.try_again_delay]) — кнопка «Fry Again».
## Награды на этом экране нет: бой проигран, забирать нечего. Кнопка уводит
## игрока тем же сигналом [signal finished], что и «Пропустить» на награде.
## Вызывающий может не ждать: экран сам проявится и сам выложит кнопку.
func open_defeat(game_mode) -> void:
	gm = game_mode
	_reward = null
	_slots.clear()
	_view = get_viewport_rect().size
	visible = true
	_phase = Phase.DEFEAT
	_defeat = true
	_fade = 0.0
	_try_again_shown = false
	_try_again_hovered = false
	# Подсказки при наведении на экране поражения ни к чему.
	HoverTooltip.suppressed = true
	queue_redraw()
	var tween := create_tween()
	tween.tween_method(_set_fade, 0.0, 1.0, maxf(config.fade_seconds, 0.01))
	await get_tree().create_timer(maxf(config.try_again_delay, 0.05)).timeout
	# Экран могли закрыть, пока проявлялась картинка.
	if _phase != Phase.DEFEAT:
		return
	_try_again_shown = true
	queue_redraw()


## Разложить предметы по местам: два предмета встают в левое и правое место,
## один — посередине между ними (его бумажка всё равно левая).
func _build_slots(items: Array[Resource]) -> void:
	_slots.clear()
	# Мест на бумажке два — столько предметов экран и раскладывает.
	var count := mini(items.size(), 2)
	var models: Array[Resource] = []
	for i in count:
		models.append(items[i])
	var centers := _slot_centers(models)
	for i in count:
		var slot := Slot.new()
		slot.model = models[i]
		slot.at = centers[i]
		_slots.append(slot)


## Где стоят предметы. Один — посередине между точками раскладки. Два — по
## своим точкам, но значки рисуются в настоящую величину (крупнее мокапа),
## и на мокапных местах крупные предметы налезали бы друг на друга — поэтому
## места раздвигаются симметрично, пока между значками не останется
## [member RewardConfig.item_gap].
func _slot_centers(models: Array[Resource]) -> Array[Vector2]:
	var centers: Array[Vector2] = []
	var left := _at(config.slot_left)
	var right := _at(config.slot_right)
	if models.size() <= 1:
		centers.append((left + right) / 2.0)
		return centers
	var need := (_item_size(models[0]).x + _item_size(models[1]).x) / 2.0 \
			+ config.item_gap
	var push := (need - (right.x - left.x)) / 2.0
	if push > 0.0:
		left.x -= push
		right.x += push
	centers.append(left)
	centers.append(right)
	return centers


# --- Раскладка с общим масштабом ---

## Точка раскладки на экране: вся награда ужимается к центру вьюпорта
## в [member RewardConfig.layout_scale] раз.
func _at(point: Vector2) -> Vector2:
	var center := _view / 2.0
	return center + (point - center) * config.layout_scale


## Прямоугольник раскладки с тем же масштабом.
func _box(rect: Rect2) -> Rect2:
	return Rect2(_at(rect.position), rect.size * config.layout_scale)


## Кегль надписи с тем же масштабом: не меньше единицы.
func _font_size(size: int) -> int:
	return maxi(int(round(size * config.layout_scale)), 1)


func _set_fade(value: float) -> void:
	_fade = clampf(value, 0.0, 1.0)
	queue_redraw()


# --- Ввод ---

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	if _phase == Phase.DEFEAT:
		_process_defeat()
		return
	if _phase != Phase.REWARD:
		return
	# Предмет и кнопка под курсором подрастают — видно, что по ним кликают.
	var point := get_global_mouse_position()
	var hovered := _slot_at(point)
	var skip := _skip_base_rect().has_point(point)
	if hovered == _hovered and skip == _skip_hovered:
		return
	_hovered = hovered
	_skip_hovered = skip
	queue_redraw()


## Кнопка «Fry Again» под курсором подрастает — видно, что по ней кликают.
## Пока кнопка не появилась, наводить не на что.
func _process_defeat() -> void:
	if not _try_again_shown:
		return
	var hovered := _try_again_base_rect().has_point(get_global_mouse_position())
	if hovered == _try_again_hovered:
		return
	_try_again_hovered = hovered
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _phase == Phase.HIDDEN:
		return
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	# Экран модальный: пока он на месте, до боя под ним клики не доходят.
	get_viewport().set_input_as_handled()
	if not button.pressed:
		return
	if _phase == Phase.DEFEAT:
		if _try_again_shown \
				and _try_again_base_rect().has_point(get_global_mouse_position()):
			Audio.play(AudioDirector.CLICK)
			_try_again_hovered = false
			_leave()
		return
	if _phase != Phase.REWARD:
		return
	var point := get_global_mouse_position()
	var index := _slot_at(point)
	if index >= 0:
		Audio.play(AudioDirector.CLICK)
		_take(_slots[index])
		return
	if _skip_base_rect().has_point(point):
		Audio.play(AudioDirector.CLICK)
		_leave()


## Место под точкой экрана; -1 — там ничего нет. Забранные и летящие
## предметы не кликаются.
func _slot_at(point: Vector2) -> int:
	for i in _slots.size():
		var slot := _slots[i]
		if slot.is_active() and _item_rect(slot, 1.0).has_point(point):
			return i
	return -1


# --- Забрать предмет ---

## Предмет улетает туда, где живёт, и по прилёте достаётся игроку. Его
## бумажка с описанием пропадает вместе с ним. Забрали последний — экран
## уходит на карту сам.
func _take(slot: Slot) -> void:
	slot.flying = true
	_hovered = -1
	var seconds := maxf(config.fly_seconds, 0.01)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(_fly_to.bind(slot), slot.at, _target_for(slot.model), seconds) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_method(_shrink_to.bind(slot), 1.0, config.fly_scale, seconds)
	tween.set_parallel(false)
	tween.tween_callback(_land.bind(slot))


func _fly_to(point: Vector2, slot: Slot) -> void:
	slot.at = point
	queue_redraw()


func _shrink_to(factor: float, slot: Slot) -> void:
	slot.factor = factor
	queue_redraw()


## Предмет долетел: он уходит игроку, а специя вдобавок падает на полку —
## бутылочка появляется там же, где появляются купленные.
func _land(slot: Slot) -> void:
	slot.taken = true
	slot.flying = false
	if gm != null and gm.player != null:
		BattleReward.give(gm.player, slot.model)
	var spice := slot.model as SpiceModel
	if spice != null and spice_shelf != null:
		spice_shelf.drop_in(spice)
	queue_redraw()
	_leave_if_empty()


## Всё забрали — задерживаться не на чем, уходим на карту.
func _leave_if_empty() -> void:
	for slot in _slots:
		if not slot.taken:
			return
	await get_tree().create_timer(maxf(config.leave_delay, 0.05)).timeout
	if _phase == Phase.REWARD:
		_leave()


func _leave() -> void:
	if _phase == Phase.LEAVING or _phase == Phase.HIDDEN:
		return
	_phase = Phase.LEAVING
	HoverTooltip.suppressed = false
	finished.emit()


## Куда летит забранный предмет: ингредиент — в холодильник, специя — в
## точку появления на полке специй, инструмент — в сумку инструментов.
## Узла нет — предмет улетает за нижний край экрана.
func _target_for(model: Resource) -> Vector2:
	if model is SpiceModel and spice_shelf != null:
		return spice_shelf.to_global(spice_shelf.drop_point)
	var button := tool_bag if model is ToolModel else fridge
	if button == null:
		return Vector2(_view.x / 2.0, _view.y + 120.0)
	# Кнопки холодильника и сумки знают свою кликабельную область — предмет
	# летит ровно в её середину, а не в точку узла.
	if button.has_method("get_global_rect"):
		var rect: Rect2 = button.call("get_global_rect")
		return rect.get_center()
	return button.global_position


# --- Отрисовка ---

func _draw() -> void:
	if Engine.is_editor_hint():
		_draw_editor_preview()
		return
	if _phase == Phase.HIDDEN:
		return
	draw_rect(Rect2(Vector2.ZERO, _view), Color(config.dim_color,
			config.dim_color.a * _fade))
	if _phase == Phase.VICTORY:
		_draw_fitted(config.victory_texture, config.victory_rect, _fade)
		return
	# Флаг, а не фаза: экран уже ушёл (Phase.LEAVING), но пока грузится
	# локация, на месте должно остаться поражение, а не чек награды.
	if _defeat:
		_draw_defeat()
		return
	_draw_check()
	_draw_sheets()
	_draw_items()
	_draw_skip()


## Счёт со строкой «Total»: сама надпись нарисована на картинке, здесь —
## только звезда и число за бой.
func _draw_check() -> void:
	_draw_fitted(config.check_texture, _box(config.check_rect), 1.0)
	if _reward == null:
		return
	StarIcon.draw(self, _at(config.total_star_pos),
			config.total_star_radius * config.layout_scale, config.total_star_color)
	var font := UiFont.resolve(config.font)
	var size := _font_size(config.total_font_size)
	var baseline := (font.get_ascent(size) - font.get_descent(size)) / 2.0
	draw_string(font, _at(config.total_number_pos) + Vector2(0.0, baseline),
			str(_reward.stars), HORIZONTAL_ALIGNMENT_LEFT, -1, size, config.total_color)


## Бумажки с описаниями: левая — про левый предмет, правая — про правый.
## Предмета нет или его уже забрали — бумажки тоже нет.
func _draw_sheets() -> void:
	_draw_sheet(0, config.sheet_left_texture, config.sheet_left_rect)
	_draw_sheet(1, config.sheet_right_texture, config.sheet_right_rect)


func _draw_sheet(index: int, texture: Texture2D, rect: Rect2) -> void:
	if index >= _slots.size() or _slots[index].taken:
		return
	var content := TooltipContent.for_model(_slots[index].model, _points_per_star())
	if content == null:
		return
	_draw_sheet_content(texture, rect, content)


## Название и описание на бумажке: обе строки по центру, текст переносится
## по её ширине.
func _draw_sheet_content(texture: Texture2D, rect: Rect2,
		content: TooltipContent) -> void:
	var scaled := _box(rect)
	var sheet := _fitted_rect(texture, scaled)
	_draw_fitted(texture, scaled, 1.0)
	var font := UiFont.resolve(config.font)
	var padding := config.sheet_padding * config.layout_scale
	var title_font := _font_size(config.sheet_title_font_size)
	var body_font := _font_size(config.sheet_body_font_size)
	var width := maxf(sheet.size.x - padding.x * 2.0, 20.0)
	var body := content.body if content.body != "" else content.star_value
	var title_size := font.get_multiline_string_size(content.title,
			HORIZONTAL_ALIGNMENT_CENTER, width, title_font)
	var body_size := Vector2.ZERO
	if body != "":
		body_size = font.get_multiline_string_size(body, HORIZONTAL_ALIGNMENT_CENTER,
				width, body_font)
	var gap := config.sheet_title_gap * config.layout_scale if body != "" else 0.0
	var total := title_size.y + gap + body_size.y
	var x := sheet.position.x + (sheet.size.x - width) / 2.0
	var y := sheet.position.y + maxf((sheet.size.y - total) / 2.0, padding.y)
	draw_multiline_string(font, Vector2(x, y + font.get_ascent(title_font)),
			content.title, HORIZONTAL_ALIGNMENT_CENTER, width,
			title_font, -1, config.sheet_title_color)
	if body == "":
		return
	draw_multiline_string(font, Vector2(x,
			y + title_size.y + gap + font.get_ascent(body_font)),
			body, HORIZONTAL_ALIGNMENT_CENTER, width,
			body_font, -1, config.sheet_body_color)


func _draw_items() -> void:
	for i in _slots.size():
		var slot := _slots[i]
		if slot.taken:
			continue
		var factor := slot.factor
		if slot.is_active() and i == _hovered:
			factor *= config.hover_scale
		var rect := _item_rect(slot, factor)
		var texture := _texture_of(slot.model)
		if texture != null:
			draw_texture_rect(texture, rect, false)
		else:
			draw_rect(rect, _color_of(slot.model))
		_draw_item_outline(texture, rect)
		if i == _hovered and slot.is_active() and config.hover_outline.a > 0.0:
			draw_rect(rect, config.hover_outline, false, 3.0)


## Обводка значка: по контуру непрозрачных пикселей картинки — ингредиент,
## специя и инструмент обводятся одинаково, и на тёмном фоне все трое видны
## как предметы, а не как пятна. Картинки нет — обводится рамка значка,
## которой предмет и нарисован.
func _draw_item_outline(texture: Texture2D, rect: Rect2) -> void:
	var width := config.item_outline_width
	if config.item_outline.a <= 0.0 or width <= 0.0:
		return
	var polys := _silhouette_of(texture)
	if polys.is_empty():
		draw_rect(rect, config.item_outline, false, width)
		return
	for poly in polys:
		var points := PackedVector2Array()
		for point in poly:
			points.append(rect.position + point * rect.size)
		points.append(points[0])
		draw_polyline(points, config.item_outline, width)


## Контуры силуэта картинки в долях её размера: (0.5, 0.5) — середина значка,
## какого бы размера он ни был. Поэтому один и тот же контур годится значку
## и в покое, и подросшему под курсором, и ужатому в полёте. Считается один
## раз на картинку.
static func _silhouette_of(texture: Texture2D) -> Array:
	if texture == null:
		return []
	if _silhouette_cache.has(texture):
		return _silhouette_cache[texture]
	var polys := []
	var image := texture.get_image()
	if image != null and not image.is_empty():
		if image.is_compressed():
			image.decompress()
		var bitmap := BitMap.new()
		bitmap.create_from_image_alpha(image)
		var size := bitmap.get_size()
		if size.x > 0 and size.y > 0:
			# Упрощение контура: сотая доля длинной стороны — обводка следует
			# картинке без лишних вершин.
			var epsilon := maxf(2.0, float(maxi(size.x, size.y)) * 0.01)
			for source in bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, size), epsilon):
				if source.size() < 3:
					continue
				var poly := PackedVector2Array()
				for point in source:
					poly.append(point / Vector2(size))
				polys.append(poly)
	_silhouette_cache[texture] = polys
	return polys


## Поражение: картинка на месте картинки победы и под ней кнопка «Fry Again».
## Кнопки может ещё не быть — сперва дают прочесть картинку
## ([member RewardConfig.try_again_delay]).
func _draw_defeat() -> void:
	_draw_fitted(config.defeat_texture, config.defeat_rect, _fade)
	if not _try_again_shown:
		return
	var rect := _try_again_rect()
	if config.try_again_texture != null:
		draw_texture_rect(config.try_again_texture, rect, false,
				Color(1.0, 1.0, 1.0, _fade))
		return
	draw_rect(rect, Color(config.try_again_fill, config.try_again_fill.a * _fade))
	draw_rect(rect, Color(config.try_again_border, config.try_again_border.a * _fade),
			false, 2.0)
	var font := UiFont.resolve(config.font)
	var size := config.try_again_font_size
	draw_string(font, Vector2(rect.position.x, rect.get_center().y + size * 0.36),
			config.try_again_text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size,
			Color(config.try_again_text_color, config.try_again_text_color.a * _fade))


## По этому прямоугольнику кнопка «Fry Again» кликается; он же не меняется
## под курсором — иначе на самой кромке кнопка бы дрожала.
func _try_again_base_rect() -> Rect2:
	return _fitted_rect(config.try_again_texture, config.try_again_rect)


## Кнопка «Fry Again», как она нарисована: под курсором чуть крупнее.
func _try_again_rect() -> Rect2:
	var rect := _try_again_base_rect()
	if not _try_again_hovered:
		return rect
	var grown := rect.size * (config.try_again_hover_scale - 1.0) / 2.0
	return rect.grow_individual(grown.x, grown.y, grown.x, grown.y)


func _draw_skip() -> void:
	var rect := _skip_rect()
	if config.skip_texture != null:
		draw_texture_rect(config.skip_texture, rect, false)
		return
	draw_rect(rect, config.skip_fill)
	draw_rect(rect, config.skip_border, false, 2.0)
	var font := UiFont.resolve(config.font)
	var size := _font_size(config.skip_font_size)
	draw_string(font, Vector2(rect.position.x, rect.get_center().y + size * 0.36),
			config.skip_text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size,
			config.skip_text_color)


## Кнопка «Пропустить»: по этому прямоугольнику она кликается, и он же не
## меняется под курсором — иначе на самой кромке кнопка бы дрожала.
func _skip_base_rect() -> Rect2:
	return _fitted_rect(config.skip_texture, _box(config.skip_rect))


## Кнопка, как она нарисована: под курсором чуть крупнее.
func _skip_rect() -> Rect2:
	var rect := _skip_base_rect()
	if not _skip_hovered:
		return rect
	var grown := rect.size * (config.skip_hover_scale - 1.0) / 2.0
	return rect.grow_individual(grown.x, grown.y, grown.x, grown.y)


## Куда нарисован предмет: его величина на экране, увеличенная в factor раз
## (наведение), центром в текущей точке.
func _item_rect(slot: Slot, factor: float) -> Rect2:
	var box := _item_size(slot.model) * factor
	return Rect2(slot.at - box / 2.0, box)


## Величина значка на экране. Ингредиент и специя рисуются один в один с боем:
## ингредиент по своему радиусу (как на столе), специя — по своему (как на
## полке). Раскладка ужимается ([member RewardConfig.layout_scale]), а они —
## нет: иначе на бумажке лежала бы уменьшенная копия того, что игрок только
## что держал в руках. Своей величины у инструмента нет, поэтому он
## вписывается в [member RewardConfig.tool_box] раскладки и ужимается вместе
## с ней. Пустое место (превью в редакторе) — тоже бокс инструмента.
func _item_size(model: Resource) -> Vector2:
	var box: Vector2
	var ingredient := model as IngredientModel
	var spice := model as SpiceModel
	if ingredient != null:
		box = IngredientNode.texture_box(ingredient).size
	elif spice != null:
		box = SpiceNode.texture_box(spice).size
	else:
		box = _fitted_rect(_texture_of(model),
				Rect2(Vector2.ZERO, config.tool_box * config.layout_scale)).size
	return box * config.item_scale


## Картинка предмета — у ингредиента, специи и инструмента она своя.
static func _texture_of(model: Resource) -> Texture2D:
	var ingredient := model as IngredientModel
	if ingredient != null:
		return ingredient.texture
	var spice := model as SpiceModel
	if spice != null:
		return spice.texture
	var tool_model := model as ToolModel
	if tool_model != null:
		return tool_model.texture
	return null


## Цвет-заглушка: им предмет рисуется, пока картинки нет.
static func _color_of(model: Resource) -> Color:
	var ingredient := model as IngredientModel
	if ingredient != null:
		return ingredient.color
	var spice := model as SpiceModel
	if spice != null:
		return spice.color
	var tool_model := model as ToolModel
	if tool_model != null:
		return tool_model.color
	return Color.WHITE


## Картинка, вписанная в прямоугольник с сохранением пропорций и по его
## центру. Без картинки — сам прямоугольник.
static func _fitted_rect(texture: Texture2D, rect: Rect2) -> Rect2:
	if texture == null:
		return rect
	var tex := texture.get_size()
	if tex.x <= 0.0 or tex.y <= 0.0:
		return rect
	var size := tex * minf(rect.size.x / tex.x, rect.size.y / tex.y)
	return Rect2(rect.get_center() - size / 2.0, size)


func _draw_fitted(texture: Texture2D, rect: Rect2, alpha: float) -> void:
	if texture == null:
		return
	draw_texture_rect(texture, _fitted_rect(texture, rect), false,
			Color(1.0, 1.0, 1.0, alpha))


func _points_per_star() -> float:
	if gm != null and gm.config != null:
		return gm.config.points_per_star
	return 10.0


# --- Превью в редакторе ---

## В редакторе экран виден целиком: затемнение, счёт, бумажки, места под
## предметы и кнопка — по ним и настраивается раскладка.
func _draw_editor_preview() -> void:
	if config == null:
		return
	# Масштаб раскладки считается от центра вьюпорта — в редакторе его размер
	# берётся тут же, чтобы превью совпадало с игрой.
	_view = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, _view), config.dim_color)
	# Поражение: картинка и кнопка, обе на своих местах и в полную силу.
	if editor_preview_defeat:
		_fade = 1.0
		_try_again_shown = true
		_draw_defeat()
		return
	_draw_fitted(config.check_texture, _box(config.check_rect), 1.0)
	StarIcon.draw(self, _at(config.total_star_pos),
			config.total_star_radius * config.layout_scale, config.total_star_color)
	var font := UiFont.resolve(config.font)
	var total_font := _font_size(config.total_font_size)
	draw_string(font, _at(config.total_number_pos) + Vector2(0.0, total_font * 0.36),
			"4", HORIZONTAL_ALIGNMENT_LEFT, -1, total_font, config.total_color)
	# Мест всегда два: пустое рисуется рамкой размером с инструмент.
	var models: Array[Resource] = []
	for i in maxi(editor_preview_items.size(), 2):
		var preview: Resource = editor_preview_items[i] \
				if i < editor_preview_items.size() else null
		models.append(preview)
	var centers := _slot_centers(models)
	for i in centers.size():
		var model: Resource = models[i]
		var size := _item_size(model)
		var box := Rect2(centers[i] - size / 2.0, size)
		var texture := _texture_of(model)
		if texture != null:
			draw_texture_rect(texture, box, false)
			_draw_item_outline(texture, box)
		else:
			draw_rect(box, Color(1.0, 0.85, 0.3, 0.15))
			draw_rect(box, Color(1.0, 0.85, 0.3, 0.6), false, 1.5)
		var content := TooltipContent.for_model(model, _points_per_star())
		if content == null:
			content = TooltipContent.new()
			content.title = "Item %d" % (i + 1)
			content.body = "Description"
		if i == 0:
			_draw_sheet_content(config.sheet_left_texture, config.sheet_left_rect, content)
		else:
			_draw_sheet_content(config.sheet_right_texture, config.sheet_right_rect, content)
	_draw_skip()
