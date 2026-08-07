## HUD боя: верхняя панель, оверлеи (горелка, вспышка, победа/поражение) и
## обработка кликов по элементам HUD.
##
## Сами элементы — виджеты-узлы под этим узлом, их позиции и вид
## настраиваются в редакторе: HudPortrait (в т.ч. позиция врага),
## HudStarRow, таймер [HudTimer] (узел Timer — общий родитель круга
## [HudTimerRing], цифр [HudTimerDigits] и кнопок секундомера; он же
## кнопка «Обратный отсчёт»), HudBagButton, а также окно инструментов — кнопка
## хранилища [HudToolButton], само хранилище [HudToolStorage] и две его
## кнопки: [HudToolToggleButton] (спрятать/показать) и
## [HudToolConfirmButton] (продолжить). При setup всем детям с методом
## attach передаётся режим боя. Специи вынесены из HUD на физическую
## полку ([SpiceShelf]) — отдельный узел сцены.
##
## Цвета панели и оверлеев — из [CombatTheme] (gm.theme). Клики,
## попавшие в элементы HUD, помечаются обработанными — до режима боя
## не доходят (HUD стоит в сцене после Arena и получает ввод первым);
## объекты, стоящие в сцене после HUD (полка специй, корзины), пока окно
## инструментов на экране, ввод не берут — их держит [CombatInputGate].
class_name CombatHud
extends Node2D

## Клик по инструменту в окне выбора; null — выбор снят (раунд без инструмента).
signal tool_selected(tool_state: ToolState)
## Нажата кнопка «Продолжить» — выбор инструмента закончен.
signal tool_confirmed
signal burn_skipped
## Нажат таймер в фазе READY (он же кнопка «Обратный отсчёт») — режим
## боя запускает раунд.
signal start_pressed

## Настройки окон — отдельные файлы в _Game/Data/Combat/UI/.
@export var burn_banner_config: BurnBannerConfig
@export var messages_config: MessagesConfig
@export var game_over_config: GameOverConfig

## Режим боя (gm_combat). Без типа, чтобы не плодить циклическую зависимость.
var gm = null
## Идёт фаза горелки без узла [BurnOverlay] в сцене: рисуется запасной
## баннер с кнопкой «Пропустить».
var burn_active := false
## Поверх боя стоит чужое модальное окно ([RewardScreen] — экран награды):
## мир под ним мышь не ловит, как под окном инструментов. Флаг ставит режим
## боя — само окно живёт вне HUD.
var modal_overlay := false
## Подпись текущего этапа подсчёта («Подсчёт: поле игрока»).
var scoring_label := ""

var _theme: CombatTheme
var _view := Vector2(1152, 648)
var _bag_button: HudBagButton
var _timer: HudTimer
var _countdown: HudStartCountdown
var _tool_button: HudToolButton
var _tool_storage: HudToolStorage
var _tool_toggle: HudToolToggleButton
var _tool_confirm: HudToolConfirmButton
## Номер раунда — настраиваемый узел RoundLabel; null — узла нет, надпись
## рисует сам HUD ([method _draw_round_label]).
var _round_label: HudRoundLabel
## Идёт выбор инструмента на раунд: окно можно прятать и показывать, но
## раунд не двинется, пока не нажата кнопка «Продолжить».
var _tool_select_active := false
var _game_over := 0                         # 0 — идёт бой, 1 — победа, 2 — поражение
## Инструмент, полученный за победу; null — награды не было.
var _reward_tool: ToolModel = null
## Надпись на кнопке экрана победы/поражения; пусто — из [GameOverConfig].
var _button_label := ""
var _flash_alpha := 0.0
var _notice := ""
var _notice_time := 0.0
## Цвет текущего уведомления; полностью прозрачный — из [MessagesConfig].
var _notice_color := Color(0.0, 0.0, 0.0, 0.0)
var _buttons: Dictionary = {}               # id -> Rect2, пересобирается каждый кадр


func setup(game_mode) -> void:
	gm = game_mode
	_theme = gm.theme
	_view = get_viewport_rect().size
	_bag_button = get_node_or_null("BagButton") as HudBagButton
	_timer = get_node_or_null("Timer") as HudTimer
	_countdown = get_node_or_null("StartCountdown") as HudStartCountdown
	_tool_button = get_node_or_null("ToolButton") as HudToolButton
	_tool_storage = get_node_or_null("ToolStorage") as HudToolStorage
	_tool_toggle = get_node_or_null("ToolStorageToggle") as HudToolToggleButton
	_tool_confirm = get_node_or_null("ToolConfirm") as HudToolConfirmButton
	_round_label = get_node_or_null("RoundLabel") as HudRoundLabel
	# Кнопкам окна нужен сам HUD: состояние окна живёт здесь.
	if _tool_toggle != null:
		_tool_toggle.hud = self
	if _tool_confirm != null:
		_tool_confirm.hud = self
	CombatInputGate.blocked = false
	if burn_banner_config == null:
		burn_banner_config = BurnBannerConfig.new()
	if messages_config == null:
		messages_config = MessagesConfig.new()
	if game_over_config == null:
		game_over_config = GameOverConfig.new()
	for child in get_children():
		if child.has_method("attach"):
			child.attach(gm)


## Бой кончился и сцена уходит: затвор ввода поднят самим HUD, снять его
## тоже ему. Флаг статический — оставленный поднятым (бой уходит на карту
## с экрана награды, а он модальный), он унёс бы с собой и следующую
## сцену: в магазине не двигались бы специи и не было бы подсказок.
func _exit_tree() -> void:
	CombatInputGate.blocked = false


# --- Окно инструментов ---

## Начать выбор инструмента на раунд: хранилище раскрывается само, рядом
## появляются кнопки «спрятать/показать» и «Продолжить». Режим боя ждёт
## сигнала [signal tool_confirmed].
func open_tool_select() -> void:
	_tool_select_active = true
	if _tool_storage != null:
		_tool_storage.show_window(true)


## Выбор закончен: окно закрывается, кнопки уходят с экрана.
func close_tool_select() -> void:
	_tool_select_active = false
	if _tool_storage != null:
		_tool_storage.hide_window()


## Есть ли сейчас окно, которое можно прятать и показывать (для кнопки
## [HudToolToggleButton]): идёт выбор или открыто хранилище.
func is_tool_window_available() -> bool:
	return _tool_select_active or is_tool_storage_shown()


## Окно инструментов на экране.
func is_tool_storage_shown() -> bool:
	return _tool_storage != null and _tool_storage.is_shown()


## Окно на экране именно в режиме выбора — только тогда есть кнопка
## «Продолжить» ([HudToolConfirmButton]).
func is_tool_select_shown() -> bool:
	return _tool_select_active and is_tool_storage_shown()


## Спрятать или вернуть окно. В режиме просмотра «спрятать» — это просто
## закрыть хранилище; выбор инструмента от этого не прерывается.
func toggle_tool_storage() -> void:
	if _tool_storage == null:
		return
	if _tool_storage.is_shown():
		_tool_storage.hide_window()
		return
	_tool_storage.show_window(_tool_select_active)
	# Холодильник накрыл бы окно собой — закрываем его.
	if gm != null:
		gm.close_bag()


## Обратный отсчёт «3 2 1» на весь экран после нажатия кнопки: фон
## затемняется, цифры идут по центру ([HudStartCountdown] — узел
## StartCountdown под Hud). Режим боя ждёт конца отсчёта и только потом
## пускает таймер раунда. Без узла отсчёта бой идёт как раньше.
func run_start_countdown() -> void:
	if _countdown == null:
		# Кадр всё равно пропускаем — вызывающий ждёт нас в любом случае.
		await get_tree().process_frame
		return
	await _countdown.run()


## Идёт ли обратный отсчёт перед началом раунда.
func is_countdown_running() -> bool:
	return _countdown != null and _countdown.is_running()


## Небольшая вспышка на нуле таймера; вызывающий её пережидает.
func flash() -> void:
	_flash_alpha = _theme.flash_strength
	await get_tree().create_timer(0.45).timeout


## Уведомление под строкой подсчёта. color подменяет цвет строки; полностью
## прозрачный — обычный цвет из [MessagesConfig].
func notify(text: String, color := Color(0.0, 0.0, 0.0, 0.0)) -> void:
	_notice = text
	_notice_color = color
	_notice_time = messages_config.notice_duration if messages_config != null else 2.4


## Сообщение о сгоревшем ингредиенте: то же уведомление, но бордово-красным
## ([member MessagesConfig.burn_color]).
func notify_burned(text: String) -> void:
	notify(text, messages_config.burn_color if messages_config != null
			else Color(0.65, 0.1, 0.15))


## Спрятать или вернуть имена сторон ([HudNameLabel]). Фаза горелки гасит их:
## имена стоят у верхней кромки стола и попадают в светлое окно оверлея
## ([BurnOverlay]) — рядом с надписью «Burn one ingredient!» они лишние.
func set_names_hidden(hidden: bool) -> void:
	for child in get_children():
		if child is HudNameLabel:
			child.visible = not hidden


## Экран победы/поражения. reward_tool — инструмент, доставшийся игроку за
## победу над врагом (см. [member EnemyModel.reward_tool]); null — награды нет.
## button_label подменяет надпись на кнопке: в забеге она возвращает на карту,
## а не перезапускает бой. Пусто — надпись из [GameOverConfig].
func show_game_over(player_won: bool, reward_tool: ToolModel = null,
		button_label := "") -> void:
	_game_over = 1 if player_won else 2
	_reward_tool = reward_tool
	_button_label = button_label
	# Окно инструментов рисуется поверх HUD (это узел-ребёнок) — закрываем,
	# иначе оно накрыло бы экран победы собой.
	close_tool_select()


## Занята ли точка экрана элементом HUD — режим боя не начинает
## перетаскивание под кнопками и оверлеями.
func blocks_point(point: Vector2) -> bool:
	if is_tool_storage_shown() or _game_over != 0 or modal_overlay \
			or is_countdown_running():
		return true
	if _bag_button != null and _bag_button.get_global_rect().has_point(point):
		return true
	if _tool_button != null and _tool_button.get_global_rect().has_point(point):
		return true
	if _tool_toggle != null and _tool_toggle.is_active() \
			and _tool_toggle.get_global_rect().has_point(point):
		return true
	if _timer != null and _timer.is_active() \
			and _timer.get_global_rect().has_point(point):
		return true
	for rect in _buttons.values():
		if (rect as Rect2).has_point(point):
			return true
	return false


func _process(delta: float) -> void:
	if _theme != null:
		_flash_alpha = maxf(_flash_alpha - delta * _theme.flash_fade_speed, 0.0)
	if _notice_time > 0.0:
		_notice_time -= delta
	# Пока на экране окно инструментов или экран награды, полка специй и
	# корзины ввод не берут.
	CombatInputGate.blocked = is_tool_storage_shown() or modal_overlay
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
		return
	var point := get_global_mouse_position()
	# Пока идёт обратный отсчёт, экран затемнён и клики никуда не идут.
	if is_countdown_running():
		get_viewport().set_input_as_handled()
		return
	if _game_over != 0:
		if _button_hit("restart", point):
			Audio.play(AudioDirector.CLICK)
			gm.restart()
		get_viewport().set_input_as_handled()
		return
	# Кнопки окна инструментов идут первыми: ими окно и управляется, даже
	# когда оно само накрывает экран.
	if _tool_toggle != null and _tool_toggle.is_active() \
			and _tool_toggle.get_global_rect().has_point(point):
		Audio.play(AudioDirector.CLICK)
		toggle_tool_storage()
		get_viewport().set_input_as_handled()
		return
	if _tool_confirm != null and _tool_confirm.is_active() \
			and _tool_confirm.get_global_rect().has_point(point):
		Audio.play(AudioDirector.CLICK)
		tool_confirmed.emit()
		get_viewport().set_input_as_handled()
		return
	if _tool_button != null and _tool_button.get_global_rect().has_point(point):
		Audio.play(AudioDirector.CLICK)
		toggle_tool_storage()
		get_viewport().set_input_as_handled()
		return
	if is_tool_storage_shown():
		_handle_tool_storage_click(point)
		get_viewport().set_input_as_handled()
		return
	if _bag_button != null and _bag_button.get_global_rect().has_point(point):
		Audio.play(AudioDirector.CLICK)
		gm.toggle_bag()
		get_viewport().set_input_as_handled()
		return
	if burn_active and _button_hit("burn_skip", point):
		Audio.play(AudioDirector.CLICK)
		burn_skipped.emit()
		get_viewport().set_input_as_handled()
		return
	# Таймер ловит клики только активной кнопкой (фаза READY) — всё
	# остальное время это просто секундомер.
	if _timer != null and _timer.is_active() \
			and _timer.get_global_rect().has_point(point):
		Audio.play(AudioDirector.CLICK)
		start_pressed.emit()
		get_viewport().set_input_as_handled()


func _button_hit(id: String, point: Vector2) -> bool:
	return _buttons.has(id) and (_buttons[id] as Rect2).has_point(point)


## Клик по открытому окну инструментов. В режиме выбора клик по готовому
## инструменту выбирает его (он начинает светиться), а по уже выбранному —
## снимает выбор: раунд можно играть и без инструмента. Инструмент на
## кулдауне не берётся. В режиме просмотра клик мимо окна его закрывает.
func _handle_tool_storage_click(point: Vector2) -> void:
	var tool_state: ToolState = _tool_storage.tool_at(point)
	if tool_state == null:
		if not _tool_select_active and not _tool_storage.get_global_rect().has_point(point):
			_tool_storage.hide_window()
		return
	if not _tool_storage.is_selection():
		return
	if not tool_state.is_ready():
		# Инструмент на кулдауне — брать его нельзя, и это слышно.
		Audio.play(AudioDirector.BLOCK)
		notify("%s is still on cooldown: %d round(s)" % [
				tool_state.model.display_name, tool_state.cooldown_remaining])
		return
	Audio.play(AudioDirector.CLICK)
	var chosen: ToolState = null if tool_state == gm.player.get_active_tool() else tool_state
	tool_selected.emit(chosen)


# --- Отрисовка ---

func _draw() -> void:
	_buttons.clear()
	if gm == null or _theme == null:
		return
	var font := ThemeDB.fallback_font
	# Верхняя полоска убрана; звёзды, таймер, портреты и ряды рисуют виджеты-дети.
	# Номер раунда — настраиваемый узел RoundLabel ([HudRoundLabel]); без него
	# надпись рисуется здесь, по-старому.
	if _round_label == null:
		_draw_round_label(font)
	_draw_burn_banner(font)
	_draw_messages(font)
	if _game_over != 0:
		_draw_game_over(font)
	if _flash_alpha > 0.0:
		draw_rect(Rect2(Vector2.ZERO, _view), Color(_theme.flash_color, _flash_alpha))


## Номер раунда — ровно под таймером, по его центру: позиция считается от
## кликабельной области узла Timer, поэтому надпись едет за ним при
## перестановке в редакторе. Без узла таймера — в верхнем левом углу.
## Пишется шрифтом проекта — как имена сторон ([HudNameLabel]).
func _draw_round_label(_font: Font) -> void:
	var text := "Round %d" % gm.round_number
	var round_font := UiFont.resolve()
	if _timer == null:
		draw_string(round_font, Vector2(16, 24), text,
				HORIZONTAL_ALIGNMENT_LEFT, 200, 16, _theme.text_primary)
		return
	var timer_rect := _timer.get_global_rect()
	draw_string(round_font, Vector2(timer_rect.get_center().x - 100.0, timer_rect.end.y + 22.0),
			text, HORIZONTAL_ALIGNMENT_CENTER, 200, 16, _theme.text_primary)


func _draw_burn_banner(font: Font) -> void:
	if not burn_active:
		return
	var w := burn_banner_config
	var strip := w.rect
	draw_rect(strip, w.fill)
	draw_rect(strip, w.border, false, 2.0)
	draw_string(font, Vector2(strip.position.x + 14.0, strip.get_center().y + 6.0),
			"Burner: click an ingredient to burn it",
			HORIZONTAL_ALIGNMENT_LEFT, strip.size.x - w.skip_button_size.x - 40.0,
			w.font_size, w.text_color)
	var skip := Rect2(Vector2(
			strip.end.x - w.skip_button_size.x - 12.0,
			strip.position.y + (strip.size.y - w.skip_button_size.y) / 2.0),
			w.skip_button_size)
	_buttons["burn_skip"] = skip
	draw_rect(skip, w.skip_button_fill)
	draw_string(font, Vector2(skip.position.x, skip.get_center().y + 5.0), "Skip",
			HORIZONTAL_ALIGNMENT_CENTER, skip.size.x, w.skip_font_size, w.text_color)


func _draw_messages(_font: Font) -> void:
	var w := messages_config
	if scoring_label != "":
		# Строка подсчёта пишется шрифтом проекта — как имена сторон.
		draw_string(UiFont.resolve(w.scoring_font), w.scoring_pos + Vector2(-200.0, 0.0),
				scoring_label, HORIZONTAL_ALIGNMENT_CENTER, 400, w.scoring_font_size,
				w.scoring_color)
	if _notice_time > 0.0 and _notice != "":
		var alpha := clampf(_notice_time, 0.0, 1.0)
		# Уведомления («Burner destroyed: ...») — строкой под подсчётом и тем же
		# шрифтом проекта, что и он. Сообщения о сгоревшем — своим цветом.
		var notice_color := _notice_color if _notice_color.a > 0.0 else w.notice_color
		draw_string(UiFont.resolve(w.notice_font), w.notice_pos + Vector2(-300.0, 0.0),
				_notice, HORIZONTAL_ALIGNMENT_CENTER, 600, w.notice_font_size,
				Color(notice_color, alpha))


func _draw_game_over(font: Font) -> void:
	var w := game_over_config
	draw_rect(Rect2(Vector2.ZERO, _view), w.dim)
	var won := _game_over == 1
	var title := w.victory_text if won else w.defeat_text
	var title_color := w.victory_color if won else w.defeat_color
	draw_string(font, Vector2(0, w.title_y), title,
			HORIZONTAL_ALIGNMENT_CENTER, _view.x, w.title_font_size, title_color)
	draw_string(font, Vector2(0, w.subtitle_y), "Rounds played: %d" % gm.round_number,
			HORIZONTAL_ALIGNMENT_CENTER, _view.x, w.subtitle_font_size, w.text_color)
	_draw_reward(font)
	var restart := w.button_rect
	_buttons["restart"] = restart
	draw_rect(restart, w.button_fill)
	draw_rect(restart, w.button_border, false, 2.0)
	var label: String = _button_label if _button_label != "" else w.button_text
	draw_string(font, Vector2(restart.position.x, restart.get_center().y + 6.0), label,
			HORIZONTAL_ALIGNMENT_CENTER, restart.size.x, w.button_font_size, w.text_color)


## Строка награды на экране победы: квадратик цвета инструмента и его
## название. Пара «квадратик + текст» центрируется по ширине экрана целиком,
## поэтому текст рисуется от левого края, а не выравниванием по центру.
func _draw_reward(font: Font) -> void:
	if _reward_tool == null:
		return
	var w := game_over_config
	var text: String = w.reward_text % _reward_tool.display_name
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			w.reward_font_size).x
	var gap := w.reward_chip_size / 2.0
	var start_x := (_view.x - w.reward_chip_size - gap - text_width) / 2.0
	draw_rect(Rect2(start_x, w.reward_y - w.reward_chip_size,
			w.reward_chip_size, w.reward_chip_size), _reward_tool.color)
	draw_string(font, Vector2(start_x + w.reward_chip_size + gap, w.reward_y), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, w.reward_font_size, w.reward_color)
