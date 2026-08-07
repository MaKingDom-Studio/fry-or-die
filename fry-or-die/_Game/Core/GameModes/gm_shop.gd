extends Node2D

## Игровой режим магазина — отдельный уровень (l_shop.tscn), на который
## в будущем игрок будет попадать с карты забега.
##
## Витрина — девять позиций ([ShopSlot] под $Slots, настраиваются в
## редакторе): три ряда по три товара — большие и средние ингредиенты,
## средние и маленькие (минимум один с эффектом), специи. Наполнение и
## правила выпадения — [ShopInventory] по пулам из [ShopConfig]
## (da_shop.tres); цена и вес каждого товара — в конфиге самого товара.
##
## Покупка: игрок берёт товар (коллизия товара отключается) и переносит
## его в холодильник ([ShopFridge] — область). Пока товар в руке, область
## подсвечена и в ней слово «Купить». Отпустил в области — звёзды
## списываются, товар уходит игроку; отпустил мимо — товар возвращается
## в свой слот. Ценники ([PriceTag]) — отдельные узлы сцены на спрайтах-
## ценниках, слот только ссылается на свой ([member ShopSlot.price_tag]):
## цена жёлтая, когда звёзд хватает, красная — когда нет.
##
## Холодильник работает как мешок в бою: клик по нему открывает модальный
## [BagPanel] со всеми ингредиентами игрока — купленные появляются там же.
##
## Уйти на карту — кнопка «Leave» ([member leave_texture]). Магазин от
## этого не закрывается навсегда: пока игрок стоит на его точке, туда
## можно вернуться, и витрина будет та же — она живёт в самой точке карты
## ([method RunManager.shop_inventory]). Новый товар не роллится, а
## купленное так и остаётся проданным: его нет ни на полке, ни в ценнике.

const NOTICE_SECONDS := 2.2

## Слой круга захвата под курсором: над мешком (120), под подсказками (135).
const GRAB_CIRCLE_Z := 134

@export var shop_config: ShopConfig
## Параметры мешка и пружины перетаскивания — те же, что в бою.
@export var combat_config: CombatConfig
## Визуальная тема (цвет теней и подписи фишек — как в бою).
@export var theme: CombatTheme
@export var character: CharacterModel

@export_group("Кнопка «Leave»")
## Картинка кнопки «уйти на карту» (`Button_Leave.png`). Кнопка видна
## только в забеге с карты ([RunManager]); при самостоятельном запуске
## сцены уходить некуда, и её нет.
@export var leave_texture: Texture2D
## Куда вписана кнопка (пропорции картинки сохраняются). Стоит внизу
## справа — между холодильником и правой полкой.
@export var map_button_rect := Rect2(806, 540, 176, 86)
## Во сколько раз крупнее кнопка под курсором.
@export_range(1.0, 2.0, 0.01) var leave_hover_scale := 1.06
@export_subgroup("Заглушка без картинки")
@export var map_button_text := "Leave"
@export var map_button_fill := Color(0.45, 0.16, 0.07)
@export var map_button_border := Color(0.95, 0.6, 0.15)
@export var map_button_text_color := Color(0.98, 0.88, 0.7)
@export var map_button_font_size := 24

var player: Player
var inventory: ShopInventory

var _rng := RandomNumberGenerator.new()
var _fridge: ShopFridge
var _bag_ui: BagPanel
var _spice_shelf: SpiceShelf
var _entries: Array[ShopEntry] = []
var _items: Array[ShopItemNode] = []
var _tags: Array[PriceTag] = []
var _carried: ShopItemNode = null
var _carry_offset := Vector2.ZERO
var _notice := ""
var _notice_left := 0.0
## Уход на карту уже идёт: второй клик по кнопке не должен грузить сцену ещё раз.
var _leaving := false
## На чём рисуется кнопка возврата: узел $Hud лежит поверх полок и облаков,
## а сам режим — под ними (родитель рисуется раньше детей).
var _button_canvas: CanvasItem
## Курсор на кнопке «Leave» — она подрастает.
var _leave_hovered := false


func _ready() -> void:
	if shop_config == null:
		shop_config = ShopConfig.new()
	if combat_config == null:
		combat_config = CombatConfig.new()
	if theme == null:
		theme = CombatTheme.new()
	# Затвор мирового ввода и запрет подсказок — статические флаги боя: их
	# поднимают окно инструментов и экран награды, с которого игрок и уходит
	# на карту. В магазине их поднимать некому, поэтому он снимает их на
	# входе — иначе специи не брались бы с полки, а предметы молчали бы без
	# описаний.
	CombatInputGate.blocked = false
	HoverTooltip.suppressed = false
	# Музыка магазина и гомон супермаркета под ней ([AudioDirector]).
	Audio.stop_all_loops()
	Audio.play_music(AudioDirector.MUSIC_SHOP)
	Audio.start_loop(AudioDirector.SHOP_AMBIENT)
	_rng.randomize()
	# Магазин из забега: тот же игрок, что и в боях ([RunManager] — синглтон
	# `Run`), поэтому покупки остаются с ним, а платит он звёздами, добытыми
	# на карте. Вне забега (сцена запущена сама по себе) — свежий игрок
	# со стартовым запасом звёзд из конфига, как раньше.
	if Run.is_active():
		player = Run.player
	else:
		player = Player.create_for_new_run(character, combat_config, _rng)
		player.add_stars(shop_config.starting_stars)
	player.stars_changed.connect(func(_stars: int) -> void: _refresh_tags())
	# В забеге витрина живёт в точке карты: вернувшись в тот же магазин,
	# игрок застаёт тот же товар. Вне забега она собирается заново.
	inventory = Run.shop_inventory(shop_config, _rng) if Run.is_active() \
			else ShopInventory.create(player, shop_config, _rng)
	_fridge = $Fridge
	# Фишки мешка выглядят как в бою: те же тень и подписи из темы.
	ContainerChip.shadow_color = theme.ingredient_shadow
	ContainerChip.show_labels = theme.show_ingredient_labels
	_bag_ui = $Bag
	_bag_ui.set_drag_params(combat_config)
	_bag_ui.close_requested.connect(close_bag)
	# Полка специй игрока — как в бою; купленные специи падают на неё
	# из точки [member SpiceShelf.drop_point].
	_spice_shelf = get_node_or_null("SpiceShelf") as SpiceShelf
	if _spice_shelf != null:
		_spice_shelf.setup(player.spices, combat_config)
	# Подсказки при наведении: цена звезды нужна ингредиентам без эффекта.
	var tooltip := get_node_or_null("Tooltip") as HoverTooltip
	if tooltip != null:
		tooltip.setup(combat_config)
	# Видимый круг захвата под курсором — область, которой хватают предметы.
	GrabCircleOverlay.attach_to(self, combat_config, GRAB_CIRCLE_Z)
	var balance := get_node_or_null("Hud/StarBalance") as StarBalance
	if balance != null:
		balance.attach(player)
	_setup_map_button()
	# Фигурка персонажа в магазине — внешность берётся из модели того, кем
	# играют: в забеге это персонаж игрока, вне забега — модель из сцены.
	var figure := get_node_or_null("Chef") as CharacterFigure
	if figure != null:
		figure.apply(player.character if player.character != null else character)
	_populate_slots()


## Разложить товары по слотам: слоты собираются по рядам
## ([member ShopSlot.kind]) в порядке следования детей $Slots, ряды
## наполняются записями витрины по порядку. Товар ужимается под площадку
## слота и кладётся в неё, цену показывает ценник, на который слот
## ссылается.
func _populate_slots() -> void:
	var by_kind := {
		ShopSlot.Kind.LARGE_MEDIUM: inventory.large_medium_entries.duplicate(),
		ShopSlot.Kind.SMALL_MEDIUM: inventory.small_medium_entries.duplicate(),
		ShopSlot.Kind.SPICE: inventory.spice_entries.duplicate(),
	}
	for child in $Slots.get_children():
		var slot := child as ShopSlot
		if slot == null:
			continue
		var entries: Array = by_kind[slot.kind]
		if entries.is_empty():
			continue
		var entry: ShopEntry = entries.pop_front()
		_entries.append(entry)
		var tag := slot.price_tag
		if tag != null:
			# Ценник помнит покупку с прошлого захода: проданный он бледный
			# и без цены.
			tag.price = entry.price
			tag.sold = entry.sold
		_tags.append(tag)
		# Купленного товара на полке больше нет — при возврате в магазин
		# место остаётся пустым.
		if entry.sold:
			_items.append(null)
			continue
		var item := ShopItemNode.create(entry, theme.ingredient_shadow,
				slot.item_fit_size(), slot.max_item_scale)
		item.set_shadow_params(shop_config)
		# Товар — top_level: масштаб слота не искажает физику и картинку.
		item.top_level = true
		slot.add_child(item)
		item.global_position = slot.item_position(item.box_size())
		item.home_position = item.global_position
		_items.append(item)
		if tag != null:
			entry.purchase_completed.connect(func() -> void: tag.sold = true)
	_refresh_tags()


## Перекрасить цены: жёлтая — звёзд хватает, красная — нет.
func _refresh_tags() -> void:
	for i in _tags.size():
		if _tags[i] != null:
			_tags[i].affordable = _entries[i].can_afford()


# --- Мешок (холодильник) — как в бою ---

func toggle_bag() -> void:
	if _bag_ui.is_open():
		close_bag()
	else:
		open_bag()


func open_bag() -> void:
	_bag_ui.set_title("Player bag — %d ingredients" % player.ingredients.size())
	_bag_ui.open(player.ingredients)


func close_bag() -> void:
	_bag_ui.close()


func is_bag_open() -> bool:
	return _bag_ui != null and _bag_ui.is_open()


# --- Ввод: взять товар, перенести в холодильник, отпустить ---

func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if is_bag_open():
		return
	var point := get_global_mouse_position()
	if button.pressed:
		# Кнопка возврата идёт первой: под ней товаров нет, и клик по ней
		# не должен ничего хватать.
		if _carried == null and _shows_map_button() and map_button_rect.has_point(point):
			_leave_to_map()
			get_viewport().set_input_as_handled()
			return
		if _carried == null and _fridge.has_point(point):
			Audio.play(AudioDirector.CLICK)
			toggle_bag()
			get_viewport().set_input_as_handled()
			return
		_try_grab(point)
	else:
		_release(point)


func _notification(what: int) -> void:
	# В браузере mouseup может потеряться при потере фокуса вкладки.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _carried != null:
		_carried.return_home(shop_config.return_duration)
		_stop_carry()


func _try_grab(point: Vector2) -> void:
	var item := _item_at(point)
	if item == null:
		return
	if not item.can_be_grabbed():
		# По товару кликнули, а взять его нельзя (он уже улетает
		# в холодильник или возвращается в слот) — отказ слышно.
		Audio.play(AudioDirector.BLOCK)
		return
	_carried = item
	_carry_offset = item.global_position - point
	# У взятого товара отключается коллизия; область покупки подсвечивается,
	# в ней появляется слово «Купить».
	item.affordable = item.entry.can_afford()
	item.set_carried(true)
	_fridge.set_active(true, item.affordable)
	get_viewport().set_input_as_handled()


func _release(point: Vector2) -> void:
	if _carried == null:
		return
	var item := _carried
	_stop_carry()
	if _over_fridge(item, point):
		if item.entry.try_purchase():
			# Купленная специя падает на полку специй, когда товар долетел
			# до холодильника.
			var bought_spice := item.entry.spice
			if bought_spice != null and _spice_shelf != null:
				item.consumed.connect(func() -> void:
					_spice_shelf.drop_in(bought_spice))
			item.consume_into(_fridge.consume_point(), shop_config.consume_duration)
			_notify("Bought: %s" % item.entry.display_name())
			return
		# Звёзд не хватило — покупки не будет, и это слышно.
		Audio.play(AudioDirector.BLOCK)
		_flash_tag_of(item)
		_notify("Not enough stars: %s costs %d" %
				[item.entry.display_name(), item.entry.price])
	# Отпущенный мимо холодильника (или неоплаченный) товар возвращается
	# в свой слот.
	item.return_home(shop_config.return_duration)


## Товар считается над зоной покупки, если там он сам или курсор. Это же
## правило решает, состоится ли покупка при отпускании, — подсветка зоны
## всегда обещает ровно то, что произойдёт.
func _over_fridge(item: ShopItemNode, point: Vector2) -> bool:
	return _fridge.has_point(item.global_position) or _fridge.has_point(point)


func _stop_carry() -> void:
	_carried = null
	_fridge.set_active(false)


func _flash_tag_of(item: ShopItemNode) -> void:
	var index := _items.find(item)
	if index >= 0 and index < _tags.size() and _tags[index] != null:
		_tags[index].flash_blocked()


func _physics_process(_delta: float) -> void:
	if _carried == null:
		return
	if not is_instance_valid(_carried):
		_stop_carry()
		return
	# Товар в руке догоняет курсор (следует с небольшой инерцией) и не
	# покидает экран.
	var view := get_viewport_rect()
	var target := (get_global_mouse_position() + _carry_offset).clamp(
			view.position + Vector2.ONE * 8.0, view.end - Vector2.ONE * 8.0)
	_carried.global_position = _carried.global_position.lerp(
			target, shop_config.carry_follow)
	# Подсветка «Купить» и обводка товара следят за балансом:
	# жёлтые — звёзд хватает, красные — нет. Как только товар попадает
	# в зону покупки, она подсвечивается заметно сильнее.
	var afford := _carried.entry.can_afford()
	if _carried.affordable != afford:
		_carried.affordable = afford
		_carried.queue_redraw()
	_fridge.set_active(true, afford, _over_fridge(_carried, get_global_mouse_position()))


func _item_at(global_point: Vector2) -> ShopItemNode:
	for body in GrabArea.bodies_at(get_world_2d(), global_point,
			combat_config.grab_radius, ShopItemNode.SHOP_ITEM_LAYER):
		var item := body as ShopItemNode
		if item != null:
			return item
	return null


# --- Сообщения ---

func _notify(text: String) -> void:
	_notice = text
	_notice_left = NOTICE_SECONDS
	queue_redraw()


func _process(delta: float) -> void:
	if _notice_left > 0.0:
		_notice_left -= delta
		if _notice_left <= 0.0:
			_notice = ""
		queue_redraw()
	# Кнопка «Leave» подрастает под курсором — видно, что по ней кликают.
	if not _shows_map_button() or _button_canvas == null:
		return
	var hovered := _carried == null \
			and _leave_hit_rect().has_point(get_global_mouse_position())
	if hovered != _leave_hovered:
		_leave_hovered = hovered
		_button_canvas.queue_redraw()


func _draw() -> void:
	if _notice == "":
		return
	var view := get_viewport_rect().size
	var alpha := clampf(_notice_left / 0.6, 0.0, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(0.0, 40.0), _notice,
			HORIZONTAL_ALIGNMENT_CENTER, view.x, 18,
			Color(0.96, 0.93, 0.88, alpha))


# --- Возврат на карту забега ---

## Кнопка нужна только в забеге: сам по себе магазин уходить некуда.
func _shows_map_button() -> bool:
	return Run.is_active()


## Кнопку рисует слой HUD: он лежит поверх полок и облаков, а сам режим —
## под ними, потому что родитель рисуется раньше детей. Рисование
## подвешивается к сигналу [signal CanvasItem.draw] этого слоя, поэтому
## отдельный узел в сцене заводить не нужно.
func _setup_map_button() -> void:
	if not _shows_map_button():
		return
	_button_canvas = get_node_or_null("Hud") as CanvasItem
	if _button_canvas == null:
		_button_canvas = self
	_button_canvas.draw.connect(_draw_map_button)
	_button_canvas.queue_redraw()


func _draw_map_button() -> void:
	if _button_canvas == null or not _shows_map_button():
		return
	var rect := _leave_rect()
	if leave_texture != null:
		_button_canvas.draw_texture_rect(leave_texture, rect, false)
		return
	_button_canvas.draw_rect(rect, map_button_fill)
	_button_canvas.draw_rect(rect, map_button_border, false, 2.0)
	var font := UiFont.resolve()
	_button_canvas.draw_string(font, Vector2(rect.position.x,
			rect.get_center().y + map_button_font_size * 0.35),
			map_button_text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x,
			map_button_font_size, map_button_text_color)


## Кнопка, как она нарисована: под курсором чуть крупнее. Кликается она по
## своему обычному прямоугольнику ([method _leave_hit_rect]) — иначе на
## самой кромке кнопка дрожала бы.
func _leave_rect() -> Rect2:
	var rect := _leave_hit_rect()
	if not _leave_hovered:
		return rect
	var grown := rect.size * (leave_hover_scale - 1.0) / 2.0
	return rect.grow_individual(grown.x, grown.y, grown.x, grown.y)


## Кликабельная область кнопки: картинка, вписанная в [member map_button_rect]
## с сохранением пропорций.
func _leave_hit_rect() -> Rect2:
	if leave_texture == null:
		return map_button_rect
	var tex := leave_texture.get_size()
	if tex.x <= 0.0 or tex.y <= 0.0:
		return map_button_rect
	var size := tex * minf(map_button_rect.size.x / tex.x, map_button_rect.size.y / tex.y)
	return Rect2(map_button_rect.get_center() - size / 2.0, size)


## Уйти из магазина на карту. Точка магазина при этом НЕ помечается
## пройденной: пока игрок стоит на ней, он может вернуться за покупками, и
## витрина будет та же. Пройденным магазин станет, когда игрок шагнёт
## дальше ([method RunManager.travel_to]).
func _leave_to_map() -> void:
	if _leaving:
		return
	_leaving = true
	Audio.play(AudioDirector.CLICK)
	var transition := get_node_or_null("SceneTransition") as SceneTransition
	if transition != null:
		await transition.play_out()
	Run.return_to_map()
