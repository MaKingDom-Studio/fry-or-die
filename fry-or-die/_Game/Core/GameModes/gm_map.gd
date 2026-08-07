extends Node2D

## Игровой режим карты забега (l_map.tscn) — экран между боями.
##
## Экран поделён на две панели:
##
## - **слева граф маршрутов** — снизу вход в кухню, от него расходятся две
##   линии, наверху они сходятся в общем магазине, за которым стоит босс.
##   Карта выше панели, поэтому панель прокручивается колесом и протяжкой
##   мыши. Точка — нарисованный листок ([MapPointArt]): бой, минибосс,
##   магазин или босс;
## - **справа накалыватель** — игла (`Map_Needle`) со стопкой листков
##   пройденных уровней ([SheetArt]). Игла рассчитана на всю стопку: шаг
##   между листками считается по длине маршрута ([method ActMap.route_length]).
##
## Точка, где игрок стоит, обведена нарисованным овалом ([MapCircle]) —
## он рисуется поверх дорог, а на каком слое графа лежит, выбирается
## в стиле ([member CircleStyle.layer]). Выбор уровня идёт так: обводка
## стирается там, где мы стоим, заново рисуется вокруг выбранной точки,
## и только потом карта уходит в уровень.
##
## После прохождения уровня карта проигрывает связку: листок пройденной
## точки падает вниз и уходит за нижний край панели графа, а на смену ему
## над иглой появляется другой листок — он падает на неё сверху, ровно по
## её оси, накалывается на острие и едет вниз до своего места в стопке
## ([SpikeSlot]).
##
## Наполнение карты — [ActMapConfig] (`_Game/Data/Map/da_map_act1.tres`),
## внешность панелей, точек и обводки — [MapStyle] (`da_map_style.tres`),
## игла и вид листка — [SpikeStyle] (`da_map_spike.tres`). Все три
## назначаются узлу в сцене, поэтому каждый объект карты правится
## в редакторе.
##
## Клик по доступной точке ведёт в её локацию: бой — l_combat.tscn,
## магазин — l_shop.tscn. Состояние забега между сценами держит
## автозагрузка [RunManager] (синглтон `Run`); карта только показывает его
## и просит перейти. Доступны всегда только дети текущей точки, поэтому
## выбранная внизу линия ведёт до самого верха.

@export var map_config: ActMapConfig
@export var style: MapStyle
## Игла, стопка и вид листков стопки.
@export var spike_style: SpikeStyle
## Кем играем, если забег ещё не начат (первый вход на карту).
@export var character: CharacterModel
## Настройки боя, с которыми создаётся игрок забега.
@export var combat_config: CombatConfig

## Позиции точек в координатах содержимого графа: MapNode → Vector2.
var _positions := {}
## Листки точек графа: MapNode → PaperSheet.
var _sheets := {}
## Стопка на игле, в порядке накалывания.
var _stack: Array[PaperSheet] = []
## Листок, который падает сверху на иглу; null — никто не падает.
var _flying: PaperSheet
## Листок пройденной точки, падающий вниз; null — никто не падает.
var _falling: PaperSheet

## Нарисованная обводка точки: стоит там, где игрок, и переезжает
## на выбранный уровень.
var _circle: MapCircle
## Выбранный уровень, который ждёт, пока обводка переедет на него; null —
## никто не выбран.
var _chosen: MapNode

var _hovered: MapNode
var _transition: SceneTransition
var _traveling := false
var _time := 0.0

## Панели экрана и геометрия иглы — считаются в [method _layout].
var _graph_rect := Rect2()
var _spike_rect := Rect2()
## Куда легла картинка иглы вместе с подставкой.
var _needle_rect := Rect2()
var _needle_x := 0.0
var _needle_top := 0.0
var _needle_base := 0.0
## Сколько листков всего соберётся за забег — на столько игла и рассчитана.
var _stack_capacity := 1

## Прокрутка панели графа: текущая и та, к которой она едет.
var _scroll := 0.0
var _scroll_target := 0.0
var _max_scroll := 0.0
## Протяжка мыши по панели графа.
var _pressed := false
var _press_at := Vector2.ZERO
var _press_scroll := 0.0
var _dragged := false

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if style == null:
		style = MapStyle.new()
	if spike_style == null:
		spike_style = SpikeStyle.new()
	if map_config == null:
		map_config = ActMapConfig.new()
	_rng.randomize()
	# Забег ещё не начат (первый запуск, победа над боссом или поражение)
	# — начинаем новый: свежий игрок и свежая карта.
	if not Run.is_active():
		Run.start_run(character, combat_config, map_config)
	# Овалы обводки идут по очереди: начинаем с того, до которого дошёл
	# забег, чтобы после возвращения на карту овал был не тот же самый.
	# Карта играет ту же музыку, что и меню ([AudioDirector]): возврат
	# с боя или из магазина её не перезапускает.
	Audio.stop_all_loops()
	Audio.play_music(AudioDirector.MUSIC_MENU)
	_circle = MapCircle.create(style.circle, Run.cleared_order.size())
	_transition = get_node_or_null("SceneTransition") as SceneTransition
	var balance := get_node_or_null("Hud/StarBalance") as StarBalance
	if balance != null:
		balance.attach(Run.player)
	_layout()
	_build_stack()
	_show_current_point()
	_circle_current_point()
	get_viewport().size_changed.connect(_layout)
	if _transition != null:
		_transition.play_in()


# --- Раскладка ---

## Посчитать панели, места точек и геометрию иглы. Вызывается на старте
## и при смене размера окна.
func _layout() -> void:
	var view := get_viewport_rect().size
	var inner := Rect2(style.frame_margin, view - style.frame_margin * 2.0)
	var graph_width := (inner.size.x - style.panel_gap) * style.graph_width_frac
	_graph_rect = Rect2(inner.position, Vector2(graph_width, inner.size.y))
	_spike_rect = Rect2(inner.position + Vector2(graph_width + style.panel_gap, 0.0),
			Vector2(inner.size.x - graph_width - style.panel_gap, inner.size.y))
	_stack_capacity = maxi(Run.map.route_length() if Run.map != null else 0, 1)
	_layout_needle()
	_layout_graph()
	_reseat_stack()
	_max_scroll = maxf(style.content_height - _graph_rect.size.y, 0.0)
	_scroll_target = clampf(_scroll_target, 0.0, _max_scroll)
	_scroll = clampf(_scroll, 0.0, _max_scroll)
	queue_redraw()


## Куда встала игла. С картинкой (`Map_Needle`, там же и подставка) вся
## геометрия считается по ней: стержень, острие и верх подставки заданы
## долями картинки, поэтому листки садятся точно на стержень. Без картинки
## игла рисуется линией по долям панели, как раньше.
func _layout_needle() -> void:
	var shaft_x := _spike_rect.position.x + _spike_rect.size.x * spike_style.needle_x_frac
	var texture := spike_style.needle_texture
	if texture == null or texture.get_height() <= 0:
		_needle_rect = Rect2()
		_needle_x = shaft_x
		_needle_top = _spike_rect.position.y + _spike_rect.size.y * spike_style.needle_top_frac
		_needle_base = _spike_rect.position.y + _spike_rect.size.y * spike_style.needle_base_frac
		return
	var height := _spike_rect.size.y * spike_style.needle_height_frac
	var width := height * float(texture.get_width()) / float(texture.get_height())
	var bottom := _spike_rect.position.y + _spike_rect.size.y * spike_style.needle_bottom_frac
	_needle_rect = Rect2(Vector2(shaft_x - width * spike_style.shaft_uv_x, bottom - height),
			Vector2(width, height))
	_needle_x = shaft_x
	_needle_top = _needle_rect.position.y + height * spike_style.tip_uv_y
	_needle_base = _needle_rect.position.y + height * spike_style.base_uv_y


## Место index-го листка в стопке. Свободная длина иглы и число листков
## забега известны только здесь, поэтому шаг стопки считается тут.
func _slot(index: int) -> SpikeSlot:
	return spike_style.slot_for(index, _stack_capacity, _needle_base - _needle_top)


## Пересадить уже стоящие листки — игла могла переехать вместе с окном.
func _reseat_stack() -> void:
	for i in _stack.size():
		_stack[i].seat(_slot(i), _needle_x, _needle_base)


## Разложить точки внутри содержимого панели: колонка даёт сдвиг от центра,
## доля высоты ([member MapNode.row_frac]) — место по вертикали, «дрожь»
## точки сбивает листки с идеальной сетки.
func _layout_graph() -> void:
	_positions.clear()
	_sheets.clear()
	var map := Run.map
	if map == null:
		return
	var center_x := _graph_rect.size.x * 0.5
	var bottom := style.content_height - style.content_margin_bottom
	var top := style.content_margin_top
	var index := 0
	for node: MapNode in map.nodes:
		var x := center_x + node.column * style.column_width \
				+ node.wobble.x * style.wobble_pixels.x
		var y := lerpf(bottom, top, node.row_frac) + node.wobble.y * style.wobble_pixels.y
		_positions[node] = Vector2(x, y)
		# Листок есть только у непройденной точки: с пройденной он улетел
		# на иглу, и на его месте остался след от прокола. Вход в кухню —
		# исключение: он пройден сразу, но никуда не улетал.
		if not node.cleared or node == map.start:
			_sheets[node] = _make_point(node, index)
		index += 1
	_reseat_circle()


## Листок точки графа: картинка, размер и наклон — из её [MapPointArt].
## У минибосса и босса листок свой ([member EnemyModel.map_art]).
func _make_point(node: MapNode, index: int) -> PaperSheet:
	var art := style.art_for_node(node)
	var sheet := PaperSheet.create_point(spike_style, art, node.letter())
	var tilt_sign := 1.0
	if style.alternate_tilt and index % 2 == 1:
		tilt_sign = -1.0
	var tilt_degrees := style.sheet_tilt
	if art != null:
		tilt_degrees += art.tilt_degrees
	sheet.place(_positions[node], deg_to_rad(tilt_degrees) * tilt_sign, style.point_scale)
	return sheet


## Собрать стопку на игле по пройденным точкам забега. Точка, пройденная
## только что, не садится сразу — для неё играется связка «падение вниз →
## влёт справа → накалывание → спуск по игле».
func _build_stack() -> void:
	_stack.clear()
	_flying = null
	_falling = null
	var pending := Run.pending_spike
	for i in Run.cleared_order.size():
		var node: MapNode = Run.cleared_order[i]
		if node == pending:
			continue
		var seated := _make_stack_sheet(node, i)
		seated.seat(_slot(i), _needle_x, _needle_base)
		_stack.append(seated)
	if pending == null:
		return
	var slot_index := Run.cleared_order.size() - 1
	# 1. Листок пройденной точки падает вниз и уходит за край панели.
	if _positions.has(pending):
		_falling = PaperSheet.create_point(spike_style, style.art_for_node(pending),
				pending.letter())
		_falling.place(_positions[pending], 0.0, style.point_scale)
		_falling.fall_away(_positions[pending], style.content_height + 400.0, _rng)
	# 2. На смену ему над иглой появляется другой листок и падает на неё
	#    сверху — он и садится в стопку.
	_flying = _make_stack_sheet(pending, slot_index)
	_flying.drop_on_needle(_slot(slot_index), _needle_x, _needle_top, _needle_base)
	Run.pending_spike = null


## Листок стопки: за магазин накалывается всегда один и тот же листок
## (список покупок), за остальные уровни — листок со своим номером.
## Номер на картинке напечатан, поэтому магазины в счёте не участвуют:
## пройденные уровни идут 1, 2, 3… подряд, сколько бы магазинов между ними
## ни попалось.
func _make_stack_sheet(node: MapNode, index: int) -> PaperSheet:
	var is_shop := node.kind == MapNode.Kind.SHOP
	var number := _numbered_before(index)
	var art := spike_style.sheet_art(number, is_shop)
	var label := "" if is_shop else str(number + 1)
	return PaperSheet.create(spike_style, art, node.letter(), label)


## Сколько уровней (не магазинов) пройдено до index-й точки стопки — это и
## есть номер её листка, считая с 0.
func _numbered_before(index: int) -> int:
	var count := 0
	for i in mini(index, Run.cleared_order.size()):
		if (Run.cleared_order[i] as MapNode).kind != MapNode.Kind.SHOP:
			count += 1
	return count


## Подвести панель так, чтобы точка, на которой стоит игрок, была видна.
func _show_current_point() -> void:
	var node := Run.current_node()
	if node == null or not _positions.has(node):
		return
	var at: Vector2 = _positions[node]
	_scroll_target = clampf(at.y - _graph_rect.size.y * 0.62, 0.0, _max_scroll)
	_scroll = _scroll_target


# --- Обводка точки ---

## Обвести точку, на которой игрок стоит: с неё и начинается выбор.
func _circle_current_point() -> void:
	var node := Run.current_node()
	if node != null:
		_circle_at(node)


func _circle_at(node: MapNode) -> bool:
	if not _positions.has(node):
		return false
	var art := style.art_for_node(node)
	var grow := art.circle_scale if art != null else 1.0
	_circle.draw_at(_positions[node], node, grow * style.point_scale)
	return true


## Обводка держится за точку, а точки переезжают вместе с окном.
func _reseat_circle() -> void:
	if _circle == null or _circle.node == null:
		return
	if _positions.has(_circle.node):
		_circle.center = _positions[_circle.node]
	else:
		_circle.clear()


## Довести выбор уровня до конца: сначала обводка стирается там, где мы
## стоим, потом рисуется на выбранной точке, и только после этого карта
## уходит в уровень.
func _advance_choice() -> void:
	if _chosen == null or _traveling:
		return
	if _circle.is_hidden():
		# Обводку стёрли — рисуем её вокруг выбранного уровня. Если рисовать
		# не на чем (точки нет на панели), уходим сразу.
		if _circle_at(_chosen):
			return
	elif _circle.node != _chosen or not _circle.is_ready():
		return
	var node := _chosen
	_chosen = null
	_travel_to(node)


# --- Ход времени ---

func _process(delta: float) -> void:
	_time += delta
	_scroll = lerpf(_scroll, _scroll_target, minf(style.scroll_follow * delta, 1.0))
	if _falling != null:
		_falling.update(delta)
		if _falling.is_gone():
			_falling = null
	if _flying != null:
		_flying.update(delta)
		# Листок доехал до своего места — он теперь часть стопки.
		if _flying.phase == PaperSheet.Phase.SEATED:
			_stack.append(_flying)
			_flying = null
	_circle.update(delta)
	_advance_choice()
	_hovered = _point_at(get_global_mouse_position()) if not _is_busy() else null
	queue_redraw()


## Карта занята: пока летят листки, переезжает обводка или идёт переход,
## клики не проходят.
func _is_busy() -> bool:
	return _traveling or _chosen != null or _flying != null or _falling != null


# --- Ввод: прокрутка панели и выбор точки ---

func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null:
		_handle_button(button)
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _pressed:
		# Протяжка: панель едет за мышью.
		var shift := _press_at.y - motion.position.y
		if absf(shift) > style.drag_threshold:
			_dragged = true
		_scroll_target = clampf(_press_scroll + shift, 0.0, _max_scroll)
		_scroll = _scroll_target


func _handle_button(button: InputEventMouseButton) -> void:
	var point := get_global_mouse_position()
	# Колесо шлёт пару событий «нажали/отпустили» — крутим только по нажатию.
	if button.pressed and _graph_rect.has_point(point):
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_target = clampf(_scroll_target - style.scroll_step, 0.0, _max_scroll)
			get_viewport().set_input_as_handled()
			return
		if button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_target = clampf(_scroll_target + style.scroll_step, 0.0, _max_scroll)
			get_viewport().set_input_as_handled()
			return
	if button.button_index != MOUSE_BUTTON_LEFT:
		return
	if button.pressed:
		if not _graph_rect.has_point(point):
			return
		_pressed = true
		_dragged = false
		_press_at = point
		_press_scroll = _scroll_target
		get_viewport().set_input_as_handled()
		return
	if not _pressed:
		return
	_pressed = false
	# Отпустили после протяжки — это была прокрутка, а не выбор точки.
	if _dragged or _is_busy() or not Run.is_active():
		return
	var node := _point_at(point)
	if node == null:
		return
	if not Run.map.can_enter(node):
		# По точке кликнули, а хода туда нет — отказ слышно.
		Audio.play(AudioDirector.BLOCK)
		get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	_choose(node)


## Игрок выбрал уровень: сначала стираем обводку там, где стоим,
## — уходить будем, только когда она нарисуется на выбранной точке.
func _choose(node: MapNode) -> void:
	Audio.play(AudioDirector.CLICK)
	_chosen = node
	_hovered = null
	_circle.erase()


## Уйти в локацию точки: экран сначала закрывается переходом.
func _travel_to(node: MapNode) -> void:
	_traveling = true
	if _transition != null:
		await _transition.play_out()
	if not Run.travel_to(node):
		_traveling = false


## Точка под экранной позицией; null — мимо всех или мимо панели графа.
func _point_at(screen_point: Vector2) -> MapNode:
	if not _graph_rect.has_point(screen_point):
		return null
	var at := _to_content(screen_point)
	for node: MapNode in _sheets:
		if node.cleared:
			continue
		if (_sheets[node] as PaperSheet).bounds().has_point(at):
			return node
	return null


## Экранная точка → координаты содержимого панели графа.
func _to_content(screen_point: Vector2) -> Vector2:
	return screen_point - _graph_rect.position + Vector2(0.0, _scroll)


# --- Отрисовка ---
#
# Порядок один и тот же на обеих панелях: сначала задние части листков,
# затем игла, затем передние части. Так игла видна выше
# дырки и скрыта листком ниже — как будто она листок проткнула.

func _draw() -> void:
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), style.frame_color)
	_draw_graph_panel()
	_draw_spike_panel()
	# Рамка идёт последней: она же обрезает обе панели по краям — и листки,
	# выехавшие за верх и низ при прокрутке, и листок, который ещё летит
	# сверху над иглой.
	_draw_frame(view)
	_draw_header()


func _draw_graph_panel() -> void:
	draw_rect(_graph_rect, style.graph_bg)
	if style.graph_bg_texture != null:
		draw_texture_rect(style.graph_bg_texture, _graph_rect, false)
	var map := Run.map
	if map == null:
		return
	# Дальше рисуем в координатах содержимого: панель просто сдвинута
	# на величину прокрутки.
	draw_set_transform(_graph_rect.position - Vector2(0.0, _scroll))
	_draw_circle_layer(CircleStyle.Layer.UNDER_LINES)
	for node: MapNode in map.nodes:
		for child: MapNode in node.children:
			_draw_link(node, child)
	_draw_circle_layer(CircleStyle.Layer.OVER_LINES)
	for node: MapNode in map.nodes:
		if node.cleared and node != map.start:
			_draw_pin(node)
	var travelable := map.travelable()
	for sheet: PaperSheet in _sheets.values():
		sheet.draw_shadow(self)
	if _falling != null:
		_falling.draw_shadow(self)
	for node: MapNode in map.nodes:
		if _sheets.has(node):
			_shade_point(node, travelable)
			(_sheets[node] as PaperSheet).draw_back(self)
	if _falling != null:
		_falling.draw_back(self)
	if not style.spine_over_points:
		_draw_spine()
	for node: MapNode in map.nodes:
		if _sheets.has(node):
			(_sheets[node] as PaperSheet).draw_front(self)
	if _falling != null:
		_falling.draw_front(self)
	if style.spine_over_points:
		_draw_spine()
	_draw_circle_layer(CircleStyle.Layer.OVER_POINTS)
	_draw_title()
	draw_set_transform(Vector2.ZERO)


## Обводка — на своём слое ([member CircleStyle.layer]): под дорогами,
## поверх дорог или поверх всего графа.
func _draw_circle_layer(layer: CircleStyle.Layer) -> void:
	if _circle.style.layer == layer:
		_circle.draw(self)


## Точка под курсором чуть подрастает, точка, куда шагнуть нельзя, —
## притухает.
func _shade_point(node: MapNode, travelable: Array[MapNode]) -> void:
	var sheet := _sheets[node] as PaperSheet
	sheet.grow = style.hover_grow if node == _hovered else 1.0
	var lit := node.cleared or travelable.has(node)
	if lit or style.locked_dim <= 0.0:
		sheet.modulate = Color.WHITE
		return
	var shade := 1.0 - style.locked_dim
	sheet.modulate = Color(shade, shade, shade)


## Нить, на которой висит карта: идёт по центру панели сверху вниз.
func _draw_spine() -> void:
	if style.spine_width <= 0.0:
		return
	var x := _graph_rect.size.x * 0.5
	draw_line(Vector2(x, 0.0), Vector2(x, style.content_height),
			style.spine_color, style.spine_width, true)


## Ребро между точками: линия проведена от руки, поэтому идёт не по
## линейке, а виляет ([member MapStyle.line_wobble]). Пройденный участок
## пути гаснет.
func _draw_link(from: MapNode, to: MapNode) -> void:
	var a: Vector2 = _positions[from]
	var b: Vector2 = _positions[to]
	var walked := from.cleared and to.cleared
	var color := style.line_cleared_color if walked else style.line_color
	var line := _link_points(a, b)
	if style.dash_length <= 0.0:
		draw_polyline(line, color, style.line_width, true)
		return
	_draw_dashed(line, color)


## Точки ломаной, из которой собрана линия маршрута. Она отходит от прямой
## то в одну, то в другую сторону; сдвиг считается от самих концов линии,
## поэтому одна и та же линия виляет всегда одинаково и не дрожит по кадрам.
func _link_points(a: Vector2, b: Vector2) -> PackedVector2Array:
	var steps: int = maxi(style.line_segments, 1)
	if style.line_wobble <= 0.0 or steps < 2:
		return PackedVector2Array([a, b])
	var normal := (b - a).orthogonal().normalized()
	var seed := a.x * 0.71 + a.y * 1.37 + b.x * 0.29 + b.y * 0.53
	var points := PackedVector2Array()
	for i in steps + 1:
		var along := float(i) / float(steps)
		var point := a.lerp(b, along)
		# По концам линия приходит точно в точку, а гуляет — в середине.
		var fade := sin(along * PI)
		var shift := sin(seed + along * (3.4 + fmod(absf(seed), 2.3)))
		points.append(point + normal * shift * fade * style.line_wobble)
	return points


## Пунктир по ломаной: штрихи ставятся по её длине, поэтому изломы линии
## пунктир не сбивают.
func _draw_dashed(line: PackedVector2Array, color: Color) -> void:
	var step := style.dash_length + maxf(style.dash_gap, 0.0)
	var total := 0.0
	for i in line.size() - 1:
		total += line[i].distance_to(line[i + 1])
	var at := 0.0
	while at < total:
		var end := minf(at + style.dash_length, total)
		draw_line(_along(line, at), _along(line, end), color, style.line_width, true)
		at += step


## Точка на ломаной в `distance` пикселях от её начала.
func _along(line: PackedVector2Array, distance: float) -> Vector2:
	var left := distance
	for i in line.size() - 1:
		var length := line[i].distance_to(line[i + 1])
		if left <= length or i == line.size() - 2:
			return line[i].lerp(line[i + 1], left / maxf(length, 0.001))
		left -= length
	return line[line.size() - 1]


## След от прокола на месте пройденной точки: её листок улетел на иглу.
func _draw_pin(node: MapNode) -> void:
	draw_circle(_positions[node], style.pin_radius, style.pin_color)


## Имя врага или магазина под курсором — над самим листком.
func _draw_title() -> void:
	if _hovered == null or not _sheets.has(_hovered):
		return
	var font := UiFont.resolve(style.font)
	var text := _hovered.title()
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1.0,
			style.title_font_size)
	var bounds := (_sheets[_hovered] as PaperSheet).bounds()
	var anchor := Vector2(bounds.get_center().x - size.x * 0.5, bounds.position.y) \
			+ style.title_offset
	if style.title_outline_size > 0:
		draw_string_outline(font, anchor, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
				style.title_font_size, style.title_outline_size, style.title_outline_color)
	draw_string(font, anchor, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			style.title_font_size, style.title_color)


## Рамка поверх содержимого: закрашивает всё, что не попало ни в одну
## панель, — поля по краям экрана и зазор между панелями. Ею же обе панели
## и обрезаются, поэтому вылезшее содержимое уходит под рамку.
func _draw_frame(view: Vector2) -> void:
	var color := style.frame_color
	var top := _graph_rect.position.y
	var bottom := _graph_rect.end.y
	draw_rect(Rect2(0.0, 0.0, view.x, top), color)
	draw_rect(Rect2(0.0, bottom, view.x, view.y - bottom), color)
	draw_rect(Rect2(0.0, top, _graph_rect.position.x, bottom - top), color)
	draw_rect(Rect2(_spike_rect.end.x, top, view.x - _spike_rect.end.x, bottom - top), color)
	draw_rect(Rect2(_graph_rect.end.x, top, _spike_rect.position.x - _graph_rect.end.x,
			bottom - top), color)


# --- Панель накалывателя ---

func _draw_spike_panel() -> void:
	draw_rect(_spike_rect, style.spike_bg)
	if style.spike_bg_texture != null:
		draw_texture_rect(style.spike_bg_texture, _spike_rect, false)
	if spike_style.needle_texture == null:
		_draw_spike_base()
	for sheet: PaperSheet in _stack:
		sheet.draw_shadow(self)
	if _flying != null:
		_flying.draw_shadow(self)
	for sheet: PaperSheet in _stack:
		sheet.draw_back(self)
	if _flying != null:
		_flying.draw_back(self)
	_draw_needle()
	for sheet: PaperSheet in _stack:
		sheet.draw_front(self)
	if _flying != null:
		_flying.draw_front(self)
	_draw_legend()


## Игла с подставкой (`Map_Needle`) рисуется между задними и передними
## частями листков: сверху острие открыто, ниже дырок его закрывают сами
## листки.
func _draw_needle() -> void:
	if spike_style.needle_texture != null:
		draw_texture_rect(spike_style.needle_texture, _needle_rect, false)
		return
	draw_line(Vector2(_needle_x, _needle_top), Vector2(_needle_x, _needle_base),
			spike_style.needle_color, spike_style.needle_width, true)


## Подставка накалывателя — только для иглы без картинки: у `Map_Needle`
## подставка уже нарисована.
func _draw_spike_base() -> void:
	var size := spike_style.base_size
	var rect := Rect2(Vector2(_needle_x - size.x * 0.5, _needle_base - size.y * 0.35), size)
	if spike_style.base_texture != null:
		draw_texture_rect(spike_style.base_texture, rect, false)
		return
	draw_rect(rect, spike_style.base_color)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.28)),
			spike_style.base_top_color)


## Легенда под иглой: что означают буквы на листках-заглушках.
func _draw_legend() -> void:
	if not style.show_legend:
		return
	var font := UiFont.resolve(style.font)
	var at := _spike_rect.position + _spike_rect.size * style.legend_position
	for text in [style.legend_shop_text, style.legend_miniboss_text, style.legend_boss_text]:
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
				style.legend_font_size, style.legend_color)
		at.y += style.legend_row_height


func _draw_header() -> void:
	if style.header_text == "":
		return
	var font := UiFont.resolve(style.font)
	var size := font.get_string_size(style.header_text, HORIZONTAL_ALIGNMENT_CENTER, -1.0,
			style.header_font_size)
	var at := _graph_rect.position + _graph_rect.size * style.header_position
	draw_string(font, at - Vector2(size.x * 0.5, 0.0), style.header_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, style.header_font_size, style.header_color)
