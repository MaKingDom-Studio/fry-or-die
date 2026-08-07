extends Node2D

## Игровой режим боя (1-й скрин): гонка звёзд с врагом.
##
## Бой состоит из раундов без ограничения и заканчивается поражением одной
## из сторон. Цикл раунда:
## 1. DROPPING — содержимое корзин перелетает на стол: сначала враг,
##    затем игрок (в зону высыпания); после приземления корзина
##    наполняется из мешка заново (фишки вырастают из маленьких);
## 2. ABILITY — способности врага: щипцы минибосса ([TongsNode], только в ходах
##    с uses_ability) прилетают справа снизу, хватают с нейтральной зоны самые
##    ценные ингредиенты и уносят их на половину врага; крюк рыбака
##    ([HookNode], каждый раунд) цепляет самое далёкое от врага полезное и
##    тянет по столу, пока оно не окажется на его половине; тесак
##    ([CleaverNode], каждый раунд) рубит ровно по центру стола: от удара
##    подпрыгивает всё, кроме накрытого лезвием, а накрытое лезвие медленно
##    увозит с центра на половину врага;
## 3. TOOL_SELECT — выбор инструмента на раунд: ингредиенты уже лежат на
##    столе, поэтому выбирать есть из чего. Окно — хранилище инструментов
##    ([HudToolStorage]); его можно спрятать кнопкой слева и в это время
##    открыть холодильник, потрогать специи и фишки в корзине. Раунд идёт
##    дальше по кнопке «Продолжить». Способности инструмента разыгрываются
##    тут же — зеркально способностям минибоссов, только в пользу игрока:
##    щипцы ([ToolTongs]) прилетают слева снизу и утаскивают ценный
##    ингредиент с половины врага к игроку; удочка ([ToolRod]) забрасывает
##    крюк слева за самым далёким полезным и тянет его к игроку; тесак
##    ([ToolCleaver]) рубит по центру стола и увозит накрытое лезвием
##    на половину игрока;
## 4. READY — все ингредиенты на столе, но трогать их нельзя: таймер стал
##    активной кнопкой «Обратный отсчёт» (пульсирует и пишет «Count Down»
##    вместо цифр, см. [HudTimer]), время выставлено на полную длительность
##    и стоит;
## 5. COUNTDOWN — таймер нажат: экран затемняется и по центру идёт отсчёт
##    «3 2 1» (~1.5 с); ингредиенты по-прежнему трогать нельзя. Если враг
##    прячет подсказки ([member EnemyModel.hides_field_tooltips]), с этого
##    момента и до нуля таймера подсказки по ингредиентам стола не
##    показываются — что где лежит, надо запомнить заранее;
## 6. PLAY — отсчёт кончился, пошёл таймер; игрок перетаскивает
##    ингредиенты (в области врага двигать нельзя — если нет удочки);
##    мята притягивает полезные (множитель > 0);
##    горох прилипает к стене стола, в которую врезался, и только с этого
##    момента клеит к себе всё, что его коснётся ([member IngredientNode.glued]);
## 7. на нуле таймера — вспышка, все ингредиенты замораживаются, подсказки
##    стола и цвет возвращаются;
## 8. BURN — горелка может выжечь один любой ингредиент (или пропустить
##    кнопкой «SKIP»): тень накрывает всё, кроме стола, а над полем вместо
##    стрелки за курсором ходит сама горелка ([BurnOverlay], узел BurnOverlay);
## 9. свет уходит: сцена затемняется ([ScoringDim]), ингредиенты остаются
##    на свету — на этом фоне идут сжигание и подсчёт;
## 10. ENEMY_BURN — враг-минибосс сжигает самые ценные ингредиенты на поле
##    игрока (если это его умение) — до подсчёта, поэтому очки за них
##    игрок не получает;
## 11. SCORING — подсчёт: сперва поле игрока, потом поле врага; внутри поля —
##    нейтральные (0..1), положительные (1.01+), уникальные эффекты,
##    отрицательные (< 0); каждый посчитанный ингредиент дрожит, мигает и
##    показывает «звезда + доля звезды»; звёзды заполняются постепенно;
## 12. свет возвращается, очистка стола (вечные остаются) и следующий раунд;
##    если в подсчёте сработала водка, стол убирается не раньше, чем её волна
##    докрасит экран.
##
## Водка ([constant IngredientModel.Effect.GRAYSCALE]), оставшаяся к подсчёту
## на поле игрока, красит следующий раунд в чёрно-белое ([GrayscaleOverlay],
## узел Grayscale). Цвет уносит волна, и пускает её тот самый шаг подсчёта,
## на котором считается бутылка: подсчёт идёт дальше под волной, а стол
## убирается не раньше, чем она дойдёт до края экрана. Волна расходится кругами
## от самой бутылки — её место берётся в момент, когда эффект сработал
## в подсчёте. Обратно волна не идёт: на нуле таймера цвет возвращается ровным
## угасанием, вместе с подсказками стола, так что горелка, сжигание врага и
## подсчёт с его вспышками идут уже цветными.
##
## Первая бутылка за бой вдобавок **неуязвима** ([member IngredientNode.untouchable]):
## её нельзя ни сдвинуть, ни выжечь, она затемнена и над ней висит красная
## подпись — первый ЧБ-раунд игрок получает наверняка. Со второго хода водка обычная.
## В ЧБ уходит почти всё: стол с ингредиентами, корзины, полка специй,
## портреты, звёзды и окна HUD (узел стоит на z 105, HUD — на 100). Выше него
## только таймер (110), подписи подсчёта (130) и подсказки (135) — они в цвете
## всегда.
##
## Зоны стола — узлы [CombatZone] под $Zones, настраиваются в редакторе.
## Визуал сцены — [CombatTheme] (_Game/Data/Combat/da_combat_theme.tres).
## Корзины — [ChipContainer], мешок — отдельный модальный [BagPanel];
## фишки с коллизией и гравитацией, у мешка свой физический слой.
## Ингредиент считается на поле, если больше чем наполовину находится
## в соответствующей области; зона высыпания не приносит очков никому.

enum Phase { IDLE, TOOL_SELECT, DROPPING, ABILITY, READY, COUNTDOWN, PLAY, BURN, ENEMY_BURN, SCORING, GAME_OVER }

enum FieldSide { NONE, PLAYER, ENEMY }

const INGREDIENT_GROUP := "ingredients"

## Слой арены на время подсчёта: ингредиенты поднимаются над затемнением
## (у узла ScoringDim в сцене z-индекс 91), но остаются под HUD (z 100) —
## в тень уходят стол, фон, корзины и полка специй.
const SCORING_ARENA_Z := 92

## Во сколько раз режется скорость стола за физический тик, пока идёт
## успокоение после способности ([method _damp_all_ingredients]).
const TABLE_SETTLE_DAMP := 0.5

## Слой круга захвата под курсором: над мешком (120) и звёздочками подсчёта,
## под подсказками (135) и экранами итога.
const GRAB_CIRCLE_Z := 134

@export var config: CombatConfig
@export var theme: CombatTheme
@export var character: CharacterModel
@export var enemy: EnemyModel

var player: Player
var round_state: PlayerRoundState
var enemy_state: EnemyCombatState
var player_stars: StarProgress
var enemy_stars: StarProgress

var phase: Phase = Phase.IDLE
var round_number := 1
var time_left := 0.0
var time_total := 1.0

var player_area: Rect2
var pour_zone: Rect2
var enemy_area: Rect2
## Объединение зон — область, где можно двигать ингредиенты.
var field_bounds: Rect2

var _arena: Node2D
var _hud: CombatHud
var _player_basket_ui: ChipContainer
var _enemy_basket_ui: ChipContainer
var _bag_ui: BagPanel
var _spice_shelf: SpiceShelf
## Затемнение сцены на время подсчёта; null — узла нет, подсчёт идёт без него.
var _scoring_dim: ScoringDim
## Оверлей фазы горелки: тень на всё, кроме стола, надпись, кнопка «SKIP» и
## горелка у курсора; null — узла нет, HUD рисует запасной баннер.
var _burn_overlay: BurnOverlay
## Всплывающие подписи подсчёта («звезда + доля звезды»); рисуются поверх всего.
var _score_labels: CombatScoreLabels
## Летящие звёздочки подсчёта: от ингредиента к счётчику; null — узла нет.
var _star_particles: StarParticles
## Счётчики звёзд сторон в HUD — цели летящих звёздочек.
var _player_star_row: HudStarRow
var _enemy_star_row: HudStarRow
## Переход-клякса на запуск уровня и загрузку локации; null — узла нет.
var _transition: SceneTransition
## Обесцвечивание экрана (эффект водки); null — узла нет, ЧБ не показывается.
var _grayscale: GrayscaleOverlay
## Подсказки при наведении; null — узла нет, бой идёт без подсказок.
var _tooltip: HoverTooltip
## Экран итога боя: награда за победу и картинка поражения с кнопкой
## «Fry Again»; null — узла нет, и бой заканчивается прежним экраном
## победы/поражения ([method CombatHud.show_game_over]).
var _reward: RewardScreen
## Финальный экран (картинка END.png и кнопка перезапуска); null — узла нет,
## и победа над боссом заканчивается обычной наградой.
var _end: EndScreen
var _rng := RandomNumberGenerator.new()
## Ингредиенты, накрытые лезвием тесака: их не подбрасывает, их лезвие увозит
## с центра на свою половину. Живёт ровно один удар.
var _cleaver_cut: Array[IngredientNode] = []
var _drag_nodes: Array[IngredientNode] = []
var _drag_offsets: Array[Vector2] = []
var _grab_request := Vector2.ZERO
var _has_grab_request := false
## Выбор инструмента подтверждён кнопкой «Продолжить».
var _tool_confirmed := false
var _burn_done := false
## Горелка уже выжигает ингредиент: пока идёт растворение, второй клик
## не должен начать ещё одно выжигание.
var _burn_running := false
## Стол успокаивается после способности: каждый физический тик скорости
## гасятся ([method _damp_all_ingredients]), пока перекрывшиеся ингредиенты
## расходятся.
var _table_settling := false
var _start_pressed := false
var _bonus_time_next_round := 0.0
## Первая бутылка водки за бой уже выложена: она неуязвима, а все следующие —
## обычные (см. [method _spawn_drop]).
var _untouchable_vodka_used := false
## Перезапуск уже идёт: экран закрывается переходом, второй клик по кнопке
## не должен грузить локацию ещё раз.
var _restarting := false


func _ready() -> void:
	if config == null:
		config = CombatConfig.new()
	if theme == null:
		theme = CombatTheme.new()
	# Свежий сид: стартовый набор игрока и случайные наборы врага
	# отличаются от боя к бою.
	_rng.randomize()
	# Музыка боя; петли предыдущей локации (гомон магазина) уходят вместе
	# с ней ([AudioDirector]).
	Audio.stop_all_loops()
	Audio.play_music(AudioDirector.MUSIC_COMBAT)
	_arena = $Arena
	_hud = $Hud
	_read_zones()
	_build_walls()
	# Бой из забега: игрок и враг приходят с карты ([RunManager] — синглтон
	# `Run`), поэтому инвентарь, инструменты, специи и звёзды переживают бой.
	# Вне забега (сцена запущена сама по себе из редактора) всё как раньше:
	# свежий игрок и враг из экспортов сцены.
	if Run.is_active():
		player = Run.player
		var run_enemy := Run.current_enemy()
		if run_enemy != null:
			enemy = run_enemy
	else:
		player = Player.create_for_new_run(character, config, _rng)
	# Затемнение подсчёта и подписи «звезда + доля» (узлы сцены).
	_scoring_dim = get_node_or_null("ScoringDim") as ScoringDim
	_score_labels = get_node_or_null("ScoreLabels") as CombatScoreLabels
	# Оверлей горелки: затемнение всего, кроме стола, на фазу BURN.
	_burn_overlay = get_node_or_null("BurnOverlay") as BurnOverlay
	if _burn_overlay != null:
		_burn_overlay.skipped.connect(_on_burn_skipped)
	# Летящие звёздочки подсчёта и счётчики-цели для них (узлы сцены).
	_star_particles = get_node_or_null("StarParticles") as StarParticles
	_player_star_row = _hud.get_node_or_null("PlayerStars") as HudStarRow
	_enemy_star_row = _hud.get_node_or_null("EnemyStars") as HudStarRow
	# Переход между сценами: на старте держит экран закрытым.
	_transition = get_node_or_null("SceneTransition") as SceneTransition
	# Обесцвечивание экрана: эффект водки на один раунд.
	_grayscale = get_node_or_null("Grayscale") as GrayscaleOverlay
	# Полка специй: физические специи-бутылочки игрока (настраивается в сцене).
	_spice_shelf = get_node_or_null("SpiceShelf") as SpiceShelf
	if _spice_shelf != null:
		_spice_shelf.setup(player.spices, config)
	# Подсказки при наведении: цена звезды нужна ингредиентам без эффекта.
	# Флаг «стол без подсказок» статический, поэтому его надо снимать на входе:
	# после перезапуска боя стол начинается с обычных подсказок.
	_tooltip = get_node_or_null("Tooltip") as HoverTooltip
	if _tooltip != null:
		_tooltip.setup(config)
	_set_field_tooltips_hidden(false)
	# Флаг «подсказок нет вовсе» тоже статический: его поднимает экран
	# награды, и после перезапуска боя подсказки должны работать снова.
	HoverTooltip.suppressed = false
	# Экран итога боя: победа показывает награду, поражение — картинку
	# Defeat.png с кнопкой «Fry Again». И то, и другое само уводит игрока
	# с экрана ([signal RewardScreen.finished]).
	_reward = get_node_or_null("Reward") as RewardScreen
	if _reward != null:
		_reward.finished.connect(restart)
	# Финальный экран: победа над последним боссом открывает END.png, и уже
	# его кнопка перезапуска начинает новый забег.
	_end = get_node_or_null("EndScreen") as EndScreen
	if _end != null:
		_end.restart_pressed.connect(restart)
	round_state = player.start_combat(_rng)
	enemy_state = EnemyCombatState.new(enemy, _rng)
	# Цели сторон заданы «крест-накрест»: сколько звёзд нужно игроку, написано
	# в характеристике врага, а сколько врагу — в характеристике игрока.
	player_stars = StarProgress.new(config.points_per_star, enemy.star_target)
	enemy_stars = StarProgress.new(config.points_per_star, _defeat_star_target())
	# Таймер показывает длительность первого раунда ещё до его начала —
	# с учётом специй игрока.
	_show_next_round_timer()
	_player_basket_ui = $PlayerBasket
	_enemy_basket_ui = $EnemyBasket
	_player_basket_ui.set_fill_params(config)
	_enemy_basket_ui.set_fill_params(config)
	# Тени фишек в корзинах и мешке — тем же цветом, что на столе.
	ContainerChip.shadow_color = theme.ingredient_shadow
	# Подписи фишек — тем же переключателем темы, что и на столе.
	ContainerChip.show_labels = theme.show_ingredient_labels
	_bag_ui = $Bag
	_bag_ui.set_drag_params(config)
	_bag_ui.close_requested.connect(close_bag)
	# Видимый круг захвата под курсором — область, которой хватают предметы.
	GrabCircleOverlay.attach_to(self, config, GRAB_CIRCLE_Z)
	_hud.setup(self)
	_hud.tool_selected.connect(_on_tool_selected)
	_hud.tool_confirmed.connect(_on_tool_confirmed)
	_hud.burn_skipped.connect(_on_burn_skipped)
	_hud.start_pressed.connect(_on_start_pressed)
	round_state.basket.changed.connect(_refresh_player_basket)
	enemy_state.basket_changed.connect(_refresh_enemy_basket)
	_refresh_player_basket()
	_refresh_enemy_basket()
	_run_combat.call_deferred()


## Зоны стола настраиваются в редакторе — узлы CombatZone под $Zones.
## Четвёртая зона (BOUNDS) задаёт границы, за которые объекты не могут
## покинуть стол; если её нет — берётся объединение остальных зон.
func _read_zones() -> void:
	var explicit_bounds := Rect2()
	for child in $Zones.get_children():
		var zone := child as CombatZone
		if zone == null:
			continue
		match zone.kind:
			CombatZone.Kind.PLAYER:
				player_area = zone.get_rect()
			CombatZone.Kind.POUR:
				pour_zone = zone.get_rect()
			CombatZone.Kind.ENEMY:
				enemy_area = zone.get_rect()
			CombatZone.Kind.BOUNDS:
				explicit_bounds = zone.get_rect()
	if explicit_bounds.size.x > 0.0 and explicit_bounds.size.y > 0.0:
		field_bounds = explicit_bounds
	else:
		field_bounds = player_area.merge(pour_zone).merge(enemy_area)


func _refresh_player_basket() -> void:
	if _player_basket_ui != null:
		_player_basket_ui.set_contents(round_state.basket.peek())


func _refresh_enemy_basket() -> void:
	if _enemy_basket_ui != null:
		_enemy_basket_ui.set_contents(enemy_state.peek_basket_models(live_permanent_count()))


# --- Мешок игрока ---

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


# --- Цикл боя ---

func _run_combat() -> void:
	# Запуск уровня: экран открывается переходом-кляксой. Корзины наполняются
	# за ним, поэтому переход не задерживает бой.
	if _transition != null:
		await _transition.play_in()
	# В самом начале боя: дать первым ингредиентам высыпаться из мешка в
	# корзины и осесть, затем выдержать паузу перед первым высыпанием на
	# стол — игрок успевает разглядеть стартовый набор.
	await _wait_baskets_filled()
	if config.combat_start_delay > 0.0:
		await get_tree().create_timer(config.combat_start_delay).timeout
	while phase != Phase.GAME_OVER:
		await _play_round()


## Дождаться, пока стартовое наполнение корзин долетит и фишки перестанут
## лететь из точки появления. Страховочный лимит по времени — на случай,
## если какая-то фишка почему-то не долетит.
func _wait_baskets_filled() -> void:
	var elapsed := 0.0
	while elapsed < 5.0:
		if not _player_basket_ui.is_filling() and not _enemy_basket_ui.is_filling():
			return
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()


func _play_round() -> void:
	# 1. Сначала враг: содержимое его корзины перелетает на стол, после
	# приземления корзина наполняется предпросмотром следующего хода.
	phase = Phase.DROPPING
	# Страховка: успокоение стола живёт только внутри способности.
	_table_settling = false
	var empty: Array[IngredientModel] = []
	# Если наполнение корзины ещё долетает — мгновенно рассадить фишки:
	# точки вылета снимаются с фактических мест, а не из воздуха.
	# Снимать надо ДО take_drop: его сигнал basket_changed синхронно
	# пересобирает корзину, и позиции были бы с новых фишек в точке
	# наполнения, а не с тех, что видит игрок.
	_enemy_basket_ui.settle_now()
	var enemy_launch := _enemy_basket_ui.chip_positions()
	var enemy_rotations := _enemy_basket_ui.chip_rotations()
	_spawn_drop(enemy_state.take_drop(live_permanent_count()), false,
			enemy_launch, enemy_rotations)
	_enemy_basket_ui.set_contents(empty)
	await _wait_all_landed()
	_refresh_enemy_basket()
	# 2. Затем игрок: корзина перелетает в зону высыпания, после чего
	# наполняется из мешка заново (фишки вырастают из маленьких).
	# Точки вылета снимаются до start_round — он опустошает корзину.
	_player_basket_ui.settle_now()
	var player_launch := _player_basket_ui.chip_positions()
	var player_rotations := _player_basket_ui.chip_rotations()
	# Корзина игрока всегда высыпается в центральную зону.
	_spawn_drop(_center_spawns(round_state.start_round()), true, player_launch, player_rotations)
	await _wait_all_landed()
	round_state.refill_basket()
	# 3. Способность врага: продукты уже упали на стол, но кнопка «Обратный
	#    отсчёт» ещё не активна — щипцы минибосса успевают утащить к нему
	#    ингредиенты с нейтральной зоны.
	await _enemy_ability()
	# 4. Выбор инструмента на раунд — стол уже накрыт, видно, что выбирать.
	#    Если инструментов нет вовсе, окно не показываем и играем без
	#    инструмента (чистый ранний бой).
	await _select_tool()
	# 5. Все ингредиенты на столе. Таймер выставлен на полную длительность,
	#    но стоит: ждём, пока игрок нажмёт таймер — он же кнопка «Обратный
	#    отсчёт». До нажатия ингредиенты трогать нельзя (см. _unhandled_input).
	# Эту длительность таймер уже показывает с подсчёта прошлого раунда;
	# здесь она закрепляется за раундом, а разовая прибавка эффектов
	# (лимон) списывается — на следующий раунд она не переносится.
	_show_next_round_timer()
	_bonus_time_next_round = 0.0
	phase = Phase.READY
	_start_pressed = false
	while not _start_pressed:
		await get_tree().process_frame
	# 6. Таймер нажат, но срабатывает он не сразу: сперва обратный отсчёт
	#    «3 2 1» на весь затемнённый экран. Ингредиенты всё ещё не трогать.
	#    Мешок закрываем — иначе он накрыл бы отсчёт собой.
	phase = Phase.COUNTDOWN
	close_bag()
	# Бой начался: если так настроен враг, подсказки по ингредиентам стола
	# гаснут на весь раунд — что где лежит, игрок должен запомнить заранее.
	_set_field_tooltips_hidden(enemy.hides_field_tooltips)
	await _hud.run_start_countdown()
	# 7. Отсчёт кончился — пошёл таймер, ингредиенты можно трогать.
	#    Пока он идёт, тикают часы: медленный ход и быстрый поверх него.
	phase = Phase.PLAY
	Audio.start_loop(AudioDirector.TICK_SLOW)
	Audio.start_loop(AudioDirector.TICK_FAST)
	while time_left > 0.0:
		await get_tree().physics_frame
	# Часы умолкают на нуле, и их сменяет звонок.
	Audio.stop_loop(AudioDirector.TICK_SLOW)
	Audio.stop_loop(AudioDirector.TICK_FAST)
	Audio.play(AudioDirector.TIMER_OFF)
	# 8. Таймер кончился: подсказки стола возвращаются (горелка и подсчёт идут
	#    уже с ними), небольшая вспышка, все ингредиенты замораживаются.
	#    С подсказками возвращается и цвет: ЧБ от водки мешает только в самом
	#    раунде, а горелка, сжигание врага и подсчёт — вспышки ингредиентов и
	#    подписи «звезда + доля» — идут уже в цвете.
	_set_field_tooltips_hidden(false)
	_set_grayscale(false)
	_release_drag()
	close_bag()
	for node in _ingredients():
		node.set_frozen(true)
	await _hud.flash()
	# 9. Горелка: убрать один любой ингредиент или пропустить.
	var active_tool := player.get_active_tool()
	if active_tool != null and active_tool.model.can_burn_after_timer() \
			and not _ingredients().is_empty():
		phase = Phase.BURN
		_burn_done = false
		_burn_running = false
		# Свет уходит со всего, кроме стола, — видно, из чего выбирать жертву;
		# картинка инструмента цепляется к курсору. Имена сторон на это время
		# гаснут: они стоят у кромки стола и попали бы в светлое окно. Без
		# узла оверлея — баннер HUD, как раньше.
		if _burn_overlay != null:
			_burn_overlay.open(field_bounds, active_tool.model.texture)
			_hud.set_names_hidden(true)
		else:
			_hud.burn_active = true
		while not _burn_done:
			await get_tree().process_frame
		_hud.burn_active = false
		if _burn_overlay != null:
			_burn_overlay.close()
			_hud.set_names_hidden(false)
	# 10. Свет уходит: сцена затемняется, на столе остаются только ингредиенты.
	# На этом фоне идут сжигание врага и подсчёт.
	await _dim_scene(true)
	# 11. Сжигание врага: минибосс выжигает самое ценное с поля игрока —
	# до подсчёта, поэтому эти очки игроку не достаются.
	await _enemy_burn()
	# 12. Подсчёт: сперва поле игрока. Если игрок набрал цель — засчитываем
	# победу сразу, ещё ДО подсчёта поля врага.
	phase = Phase.SCORING
	await _score_field(true)
	if player_stars.is_complete():
		_finish(true)
		return
	# 13. Затем поле врага; если цель набрал он — поражение.
	await _score_field(false)
	if enemy_stars.is_complete():
		_finish(false)
		return
	# 14. Свет возвращается, стол убирается (вечные остаются).
	await _dim_scene(false)
	# 15. Волна ЧБ, если её пустил подсчёт водки, должна пройти до конца: стол
	# убирается только с полностью перекрашенного кадра.
	await _wait_grayscale_wave()
	_cleanup_round()
	round_state.end_round()
	enemy_state.advance()
	round_number += 1


## Цель врага: сколько звёзд ему нужно набрать, чтобы игрок проиграл. База —
## [member CombatConfig.player_star_target], специи её поднимают (крутой
## перец добавляет игроку звезду запаса).
func _defeat_star_target() -> int:
	var target := config.player_star_target
	for spice in player.spices:
		target = spice.modify_defeat_star_target(player, target)
	return target


## Длительность следующего раунда: база из конфига (или своя у врага —
## [member EnemyModel.round_timer_seconds]), накопленная прибавка
## эффектов (лимон) и специи. Только считает — ничего не сбрасывает.
func _round_duration() -> float:
	var base := config.round_timer_seconds
	if enemy != null and enemy.round_timer_seconds > 0.0:
		base = enemy.round_timer_seconds
	var seconds := base + _bonus_time_next_round
	for spice in player.spices:
		seconds = spice.modify_timer_duration(player, seconds)
	return maxf(seconds, 3.0)


## Выставить таймер на длительность следующего раунда. Цифры таймера
## ([HudTimerDigits]) вне фазы PLAY показывают time_total, поэтому вызов
## сразу после изменения прибавки делает её видимой в тот же момент —
## а не в начале следующего раунда. Исключение — фаза READY: там таймер
## стал кнопкой и вместо цифр пишет «Count Down» ([HudTimer]), так что
## прибавку видно на подсчёте, где она и набегает.
func _show_next_round_timer() -> void:
	time_total = _round_duration()
	time_left = time_total


## Спрятать или вернуть подсказки по ингредиентам стола
## ([member EnemyModel.hides_field_tooltips]). Ту, что уже висит на экране,
## гасим сразу — иначе окно осталось бы до следующего движения мышью.
func _set_field_tooltips_hidden(hidden: bool) -> void:
	IngredientNode.tooltips_hidden = hidden
	if hidden and _tooltip != null:
		_tooltip.clear()


func _finish(player_won: bool) -> void:
	phase = Phase.GAME_OVER
	close_bag()
	# Итог боя слышно без музыки: она уходит, остаётся победа или поражение.
	# Чек ([constant AudioDirector.CASH]) пускает уже экран награды —
	# ровно тогда, когда его выкладывают на стол ([RewardScreen]).
	Audio.stop_all_loops()
	Audio.stop_music()
	Audio.play(AudioDirector.VICTORY if player_won else AudioDirector.DEFEAT)
	# Экран победы/поражения — в цвете, даже если раунд шёл в ЧБ.
	_set_grayscale(false)
	# Забег: победа отмечает точку карты пройденной, поражение заканчивает
	# забег — карта соберётся заново.
	if Run.is_active():
		Run.report_combat(player_won)
	# Победа над последним боссом — конец игры: награда уже ни к чему, вместо
	# неё открывается финальный экран ([EndScreen]) с картинкой END.png и
	# кнопкой перезапуска.
	if player_won and _end != null and _is_final_boss():
		_show_end()
		return
	# Победа: картинка победы и следом экран награды ([RewardScreen]) —
	# он же уводит игрока на карту.
	if player_won and _reward != null:
		_show_reward()
		return
	# Поражение: на том же месте, где висит победа, — картинка Defeat.png,
	# под ней кнопка «Fry Again» ([method RewardScreen.open_defeat]). Она
	# уводит игрока тем же путём, что и экран награды.
	if not player_won and _reward != null:
		_show_defeat()
		return
	var reward: ToolModel = _grant_victory_reward() if player_won else null
	var button_label := "Back to the map" if Run.is_active() else ""
	_hud.show_game_over(player_won, reward, button_label)


## Открыть экран награды: набор роллится один раз, звёзды за бой начисляются
## сразу (их не выбирают), а предметы игрок забирает кликом сам. Пока экран
## на месте, мир под ним мышь не ловит.
func _show_reward() -> void:
	var battle_reward := BattleReward.roll(player, enemy, _is_miniboss(),
			_reward.config, _rng)
	player.add_stars(battle_reward.stars)
	_hud.modal_overlay = true
	_reward.open(self, battle_reward)


## Открыть экран поражения: то же затемнение и то же место, что у картинки
## победы, только картинка `Defeat.png`, а под ней кнопка «Fry Again».
## Награды за проигранный бой нет — брать с экрана нечего, поэтому и
## роллить нечего. Пока экран на месте, мир под ним мышь не ловит.
func _show_defeat() -> void:
	_hud.modal_overlay = true
	_reward.open_defeat(self)


## Открыть финальный экран: чёрный фон, картинка концовки и кнопка
## перезапуска. Пока он на месте, мир под ним мышь не ловит; кнопка уводит
## игрока тем же путём, что и экран награды ([method restart]) — забег уже
## помечен пройденным, поэтому карта соберёт новый.
func _show_end() -> void:
	_hud.modal_overlay = true
	_end.open()


## Бой был с последним боссом акта: победа над ним заканчивает игру. В забеге
## это видно по точке карты, вне забега — по флагу самого врага
## ([member EnemyModel.is_final_boss]), чтобы бой с боссом можно было
## проверить из редактора отдельной сценой.
func _is_final_boss() -> bool:
	var node := Run.current_node()
	if node != null:
		return node.kind == MapNode.Kind.BOSS
	return enemy != null and enemy.is_final_boss


## Бой был с минибоссом: у него своя награда — крутой перец и собственное
## орудие. В забеге это видно по точке карты, вне забега — по тому, что
## орудие для награды есть только у минибоссов.
func _is_miniboss() -> bool:
	var node := Run.current_node()
	if node != null:
		return node.kind == MapNode.Kind.MINIBOSS
	return enemy != null and enemy.reward_tool != null


## Награда за победу без экрана награды (узла Reward в сцене нет): инструмент
## врага уходит игроку — минибосс-пожарный отдаёт горелку
## ([member EnemyModel.reward_tool]). Возвращает выданный инструмент, чтобы
## HUD показал его на экране победы; null — награды у врага нет или такой
## инструмент у игрока уже есть.
func _grant_victory_reward() -> ToolModel:
	if enemy == null or enemy.reward_tool == null:
		return null
	if player.has_tool(enemy.reward_tool.id):
		return null
	player.add_tool(enemy.reward_tool)
	return enemy.reward_tool


## Уход из боя: кнопка экрана поражения или конец экрана награды
## ([signal RewardScreen.finished]). Экран сначала закрывается тем же
## переходом в обратном порядке, и только потом грузится локация — на новой
## она откроется снова.
##
## В забеге кнопка возвращает на карту: там ждут остальные точки, а если
## забег кончился (босс побеждён или бой проигран), карта соберётся заново.
## Вне забега бой просто перезапускается, как раньше.
func restart() -> void:
	if _restarting:
		return
	_restarting = true
	if _transition != null:
		await _transition.play_out()
	if Run.is_active():
		Run.return_to_map()
	else:
		get_tree().reload_current_scene()


# --- Высыпание ---

## Высыпание: заполнение поля идёт с верха корзины — ингредиенты ждут
## на местах своих фишек (подменяя их без скачка: то же место и тот же
## поворот), и первыми отправляются те, что выше в горке (содержимое
## разбирается сверху). Каждый летит по дуге в свою точку зоны; точки
## приземления подбираются без пересечений, чтобы прилетевшие не
## застревали друг в друге. Высыпание врага выглядит в точности как
## у игрока.
func _spawn_drop(spawns: Array[SpawnRequest], from_player: bool,
		launch_points: Array[Vector2] = [],
		launch_rotations: Array[float] = []) -> void:
	var source: ChipContainer = _player_basket_ui if from_player else _enemy_basket_ui
	# Занятые места: уже лежащие на столе (вечные) и прилетающие сейчас.
	var taken := []
	for node in _ingredients():
		taken.append([node.position, node.model.radius])
	# Задержки выдачи с рандомизацией: интервалы неравномерные; раздаются
	# по рангу высоты — кто выше в корзине, тому меньшая задержка.
	var delays: Array[float] = []
	var delay := 0.0
	for _i in spawns.size():
		delays.append(delay)
		delay += config.drop_stagger + _rng.randf_range(0.0, config.drop_stagger_random)
	var rank := _rank_by_height(spawns.size(), launch_points)
	var order := 0
	for spawn in spawns:
		var model := spawn.model
		# Куда падает: у игрока всегда центр, у врага — по размещению группы.
		var zone := pour_zone if from_player else _zone_for_placement(spawn.placement)
		var node := IngredientNode.create(model, config, theme)
		node.from_player = from_player
		node.untouchable = _claim_untouchable(model)
		node.add_to_group(INGREDIENT_GROUP)
		node.position = _landing_point(zone, model.radius, taken)
		# Поворот — как у подменяемой фишки: подмена без скачка.
		node.rotation = launch_rotations[order] if order < launch_rotations.size() \
				else randf_range(0.0, TAU)
		_arena.add_child(node)
		# Точка вылета — фишка этого ингредиента в корзине; фолбэк —
		# центр корзины (совсем без корзины — верхний край экрана).
		var from := Vector2(node.position.x, -model.radius * 2.0)
		if order < launch_points.size():
			from = launch_points[order]
		elif source != null:
			from = source.panel_global_rect().get_center()
		node.fly_in(from, config.basket_flight_duration, config.basket_flight_arc,
				delays[rank[order]], config.drop_gravity, config.drop_bounce)
		order += 1


## Неуязвима ли эта штука: первая за бой бутылка водки (эффект
## [constant IngredientModel.Effect.GRAYSCALE]) трогать себя не даёт вовсе —
## ни рукой, ни горелкой, ни соседями, — поэтому первый ЧБ-раунд игрок получает
## наверняка. Со второго хода водка обычная, и её можно сгонять с поля.
func _claim_untouchable(model: IngredientModel) -> bool:
	if model.effect != IngredientModel.Effect.GRAYSCALE or _untouchable_vodka_used:
		return false
	_untouchable_vodka_used = true
	return true


## Участок стола для размещения группы врага.
func _zone_for_placement(placement: EnemySpawnGroup.Placement) -> Rect2:
	match placement:
		EnemySpawnGroup.Placement.PLAYER:
			return player_area
		EnemySpawnGroup.Placement.CENTER:
			return pour_zone
		_:
			return enemy_area


## Обернуть ингредиенты игрока в запросы на высыпание в центральную зону.
func _center_spawns(models: Array[IngredientModel]) -> Array[SpawnRequest]:
	var spawns: Array[SpawnRequest] = []
	for model in models:
		spawns.append(SpawnRequest.new(model, EnemySpawnGroup.Placement.CENTER))
	return spawns


## Ранг вылета для каждого индекса: сортировка по высоте точки вылета —
## меньший y (выше на экране) отправляется раньше; индексы без точки
## уходят в конец очереди.
func _rank_by_height(count: int, launch_points: Array[Vector2]) -> Array[int]:
	var indices: Array[int] = []
	for i in count:
		indices.append(i)
	indices.sort_custom(func(a: int, b: int) -> bool:
		var ya := launch_points[a].y if a < launch_points.size() else INF
		var yb := launch_points[b].y if b < launch_points.size() else INF
		return ya < yb)
	var rank: Array[int] = []
	rank.resize(count)
	for position_in_queue in count:
		rank[indices[position_in_queue]] = position_in_queue
	return rank


## Точка приземления, не пересекающаяся с уже занятыми местами (список
## [позиция, радиус]); выбранная точка добавляется в список. Сначала
## ищем в самой зоне; в тесноте выходим за её границу — область поиска
## расширяется шагами до границ стола, лишь бы не класть друг на друга.
func _landing_point(zone: Rect2, radius: float, taken: Array) -> Vector2:
	var point := Vector2.ZERO
	for _attempt in 24:
		point = _random_point_in(zone, radius + 6.0)
		if _landing_free(point, radius, taken):
			taken.append([point, radius])
			return point
	var area := zone
	for _ring in 6:
		area = area.grow(radius * 2.0).intersection(field_bounds)
		for _attempt in 16:
			point = _random_point_in(area, radius + 6.0)
			if _landing_free(point, radius, taken):
				taken.append([point, radius])
				return point
	taken.append([point, radius])
	return point


func _landing_free(point: Vector2, radius: float, taken: Array) -> bool:
	for entry in taken:
		if point.distance_to(entry[0]) < radius + entry[1] + 4.0:
			return false
	return true


func _random_point_in(zone: Rect2, margin: float) -> Vector2:
	var m := minf(margin, minf(zone.size.x, zone.size.y) / 2.0 - 1.0)
	return Vector2(
			_rng.randf_range(zone.position.x + m, zone.end.x - m),
			_rng.randf_range(zone.position.y + m, zone.end.y - m))


func _wait_all_landed() -> void:
	while true:
		var still_falling := false
		for node in _ingredients():
			if node.is_airborne():
				still_falling = true
				break
		if not still_falling:
			return
		await get_tree().physics_frame


# --- Подсчёт ---

func _score_field(player_field: bool) -> void:
	_hud.scoring_label = "Scoring: player field" if player_field else "Scoring: enemy field"
	var side := FieldSide.PLAYER if player_field else FieldSide.ENEMY
	var track := player_stars if player_field else enemy_stars
	var on_field: Array[IngredientNode] = []
	for node in _ingredients():
		if field_side_of(node) == side:
			on_field.append(node)
	# Порядок: нейтральные (0..1), положительные (1.01+), уникальные
	# эффекты, отрицательные (< 0).
	var neutral: Array[IngredientNode] = []
	var positive: Array[IngredientNode] = []
	var negative: Array[IngredientNode] = []
	for node in on_field:
		match node.model.category():
			IngredientModel.Category.NEUTRAL:
				neutral.append(node)
			IngredientModel.Category.POSITIVE:
				positive.append(node)
			IngredientModel.Category.NEGATIVE:
				negative.append(node)
	for node in neutral:
		await _award(node, track, player_field)
	for node in positive:
		await _award(node, track, player_field)
	for node in on_field:
		# Полевые эффекты (липкий горох) отрабатывают на столе сами —
		# отдельного шага подсчёта у них нет.
		if node.model.has_scoring_effect():
			await _apply_effect(node, player_field)
	for node in negative:
		await _award(node, track, player_field)
	_hud.scoring_label = ""


func _award(node: IngredientNode, track: StarProgress, player_field: bool) -> void:
	var points := _points_for(node.model, player_field)
	node.highlight = 1.0
	track.add_points(points)
	# Эффект подсчёта: ингредиент дрожит и мигает, а поверх всего всплывает
	# подпись «звезда + доля звезды». Живут сами — шаг подсчёта их не ждёт.
	var flash := theme.score_highlight if points >= 0.0 else theme.score_flash_negative
	node.play_score_hit(theme.score_hit_material, theme.score_hit_duration, flash)
	if _score_labels != null:
		_score_labels.pop(node.global_position, _star_fraction_label(points), flash,
				node.model.radius)
	_send_star_particles(node, track, player_field, points)
	await get_tree().create_timer(config.score_step_delay).timeout


## Летящие звёздочки подсчёта: посчитанный ингредиент отправляет их в счётчик
## своей стороны — в звезду, которую сторона сейчас заполняет. Чем больше очков
## дал ингредиент, тем больше звёздочек; минусы звёздочек не шлют.
func _send_star_particles(node: IngredientNode, track: StarProgress,
		player_field: bool, points: float) -> void:
	if _star_particles == null or points <= 0.0:
		return
	var row := _player_star_row if player_field else _enemy_star_row
	if row == null:
		return
	var slot := clampi(track.filled_stars(), 0, track.target_stars - 1)
	var amount := clampi(ceili(points / track.points_per_star * 5.0), 2, 6)
	_star_particles.burst(node.global_position, row.slot_global_position(slot), amount)


## Подпись подсчёта: какую долю звезды дал ингредиент — его очки, поделённые
## на цену звезды ([member CombatConfig.points_per_star]). Не больше двух знаков
## после запятой, лишние нули срезаются: «0.33», «0.8», «1», «-0.15».
func _star_fraction_label(points: float) -> String:
	var per_star := config.points_per_star
	var fraction := points / per_star if per_star > 0.0 else 0.0
	var text := "%.2f" % fraction
	if text.contains("."):
		text = text.rstrip("0").rstrip(".")
	return "0" if text == "" or text == "-0" else text


## Затемнить сцену под подсчёт (on) или вернуть свет. Ингредиенты на время
## затемнения поднимаются над заливкой — они остаются на свету, как и HUD.
func _dim_scene(on: bool) -> void:
	if _scoring_dim == null:
		return
	if on:
		_arena.z_index = SCORING_ARENA_Z
		await _scoring_dim.fade_in()
	else:
		await _scoring_dim.fade_out()
		_arena.z_index = 0


## Очки, которые ингредиент принесёт полю стороны. Специи — пассивные
## эффекты, срабатывают всегда (на обоих полях).
func _points_for(model: IngredientModel, player_field: bool) -> float:
	var points := model.base_points()
	for spice in player.spices:
		points = spice.modify_ingredient_points(player, model, points, player_field)
	return points


func _apply_effect(node: IngredientNode, player_field: bool) -> void:
	var model := node.model
	node.highlight = 1.0
	match model.effect:
		IngredientModel.Effect.EXTRA_INGREDIENTS:
			# Прибавка сразу видна в корзине соответствующей стороны.
			if player_field:
				round_state.basket.add_from(round_state.bag, model.effect_amount)
			else:
				enemy_state.add_extra(model.effect_amount)
			_hud.notify("%s: +%d ingredients next round" % [model.display_name, model.effect_amount])
		IngredientModel.Effect.EXTRA_TIME:
			# На поле игрока лимон удлиняет следующий раунд, на поле врага —
			# укорачивает (вражеский лимон работает против игрока).
			var delta := model.effect_amount if player_field else -model.effect_amount
			_bonus_time_next_round += delta
			# Новая длительность сразу видна на таймере — как прибавка
			# ингредиентов сразу видна в корзине.
			_show_next_round_timer()
			_hud.notify("%s: %+d sec to the next round timer" % [model.display_name, delta])
		IngredientModel.Effect.GRAYSCALE:
			# Водка: осталась на поле игрока — сразу после подсчёта по экрану
			# пройдёт волна и унесёт цвет, а весь следующий раунд игрок
			# проведёт в чёрно-белом. На поле врага бутылка не работает:
			# сгонишь её с себя — и эффекта не будет.
			if player_field:
				# Волна идёт прямо с этого шага подсчёта и прямо от бутылки:
				# посчитали водку — от неё кругами уходит цвет. Ждать её здесь
				# не надо, подсчёт продолжается под ней; до конца волны раунд
				# доводит _wait_grayscale_wave() перед уборкой стола.
				if _grayscale != null:
					_grayscale.set_origin_global(node.global_position)
					_grayscale.set_active(true)
				_hud.notify("%s: the next round goes black and white" % model.display_name)
	await get_tree().create_timer(config.score_step_delay).timeout


## Дождаться волны ЧБ, которую пустил подсчёт водки ([method _apply_effect]):
## она должна дойти до края экрана и подержать перекрашенный кадр, и только
## потом стол убирается, а следующий раунд начинается — уже чёрно-белый.
func _wait_grayscale_wave() -> void:
	if _grayscale == null:
		return
	await _grayscale.await_wave()


## Включить или выключить ЧБ. Узла в сцене может не быть — тогда эффект просто
## не показывается.
func _set_grayscale(on: bool) -> void:
	if _grayscale != null:
		_grayscale.set_active(on)


## Вечные ингредиенты остаются на поле замороженными, остальные убираются.
func _cleanup_round() -> void:
	for node in _ingredients():
		if not node.model.permanent:
			node.queue_free()


# --- Поле и стороны ---

func _build_walls() -> void:
	# Четыре статичные стены по периметру стола, как в песочнице.
	var wall_material := PhysicsMaterial.new()
	wall_material.bounce = config.elasticity / 2.0
	wall_material.friction = 0.0
	var f := field_bounds
	var thickness := 60.0
	var half := thickness / 2.0
	var horizontal := Vector2(f.size.x + thickness * 2.0, thickness)
	var vertical := Vector2(thickness, f.size.y + thickness * 2.0)
	var walls := [
		[f.position + Vector2(f.size.x / 2.0, -half), horizontal],
		[f.position + Vector2(f.size.x / 2.0, f.size.y + half), horizontal],
		[f.position + Vector2(-half, f.size.y / 2.0), vertical],
		[f.position + Vector2(f.size.x + half, f.size.y / 2.0), vertical],
	]
	for wall_data in walls:
		var wall := StaticBody2D.new()
		wall.position = wall_data[0]
		wall.physics_material_override = wall_material
		var shape := RectangleShape2D.new()
		shape.size = wall_data[1]
		var collision := CollisionShape2D.new()
		collision.shape = shape
		wall.add_child(collision)
		_arena.add_child(wall)


func _ingredients() -> Array[IngredientNode]:
	var result: Array[IngredientNode] = []
	for node in get_tree().get_nodes_in_group(INGREDIENT_GROUP):
		var ingredient := node as IngredientNode
		if ingredient != null and not ingredient.is_queued_for_deletion():
			result.append(ingredient)
	return result


func live_permanent_count() -> int:
	var count := 0
	for node in _ingredients():
		if node.model.permanent:
			count += 1
	return count


## На чьём поле ингредиент: он считается на поле, если больше чем
## наполовину находится в соответствующей области.
func field_side_of(node: IngredientNode) -> FieldSide:
	var r := node.model.radius
	var aabb := Rect2(node.position - Vector2(r, r), Vector2(r, r) * 2.0)
	var area := aabb.size.x * aabb.size.y
	if area <= 0.0:
		return FieldSide.NONE
	if _overlap_area(aabb, player_area) >= area * 0.5:
		return FieldSide.PLAYER
	if _overlap_area(aabb, enemy_area) >= area * 0.5:
		return FieldSide.ENEMY
	return FieldSide.NONE


func _overlap_area(a: Rect2, b: Rect2) -> float:
	var inter := a.intersection(b)
	return inter.size.x * inter.size.y


# --- Ввод и перетаскивание ---

func _unhandled_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.pressed:
		var point := get_global_mouse_position()
		if _hud.blocks_point(point) or is_bag_open():
			return
		if phase == Phase.BURN:
			_try_burn_at(point)
		elif phase == Phase.PLAY:
			# До нажатия «Обратного отсчёта» (фаза READY) ингредиенты
			# трогать нельзя — двигаются только когда пошёл таймер.
			_grab_request = point
			_has_grab_request = true
	else:
		_has_grab_request = false
		_release_drag()


func _notification(what: int) -> void:
	# В браузере mouseup может потеряться при потере фокуса вкладки.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_has_grab_request = false
		_release_drag()


func _physics_process(delta: float) -> void:
	if phase == Phase.PLAY:
		time_left = maxf(time_left - delta, 0.0)
	if _table_settling:
		_damp_all_ingredients()
	if _has_grab_request:
		_has_grab_request = false
		_try_start_drag(_grab_request)
	_update_grab_blocked()
	_process_drag()
	_process_spice_attraction(delta)


## Затемнение на половине врага: ингредиент, который рука оттуда не возьмёт
## ([method _grab_allowed]), затемнён так же, как неуязвимый
## ([member CombatTheme.untouchable_tint]). Считается каждый тик по положению:
## уехал к врагу — погас, вернулся — снова цветной. С инструментом, которому
## половина врага доступна (удочка), затемнение гаснет — брать снова можно.
func _update_grab_blocked() -> void:
	var rod := _rod_active()
	for node in _ingredients():
		node.grab_blocked = not rod and field_side_of(node) == FieldSide.ENEMY


func _try_start_drag(point: Vector2) -> void:
	var rod := _rod_active()
	var primary := _node_at_point(point)
	if primary == null:
		return
	if not _grab_allowed(primary, rod):
		# По ингредиенту кликнули, а взять его нельзя (неуязвимый, замороженный
		# или лежит на половине врага без удочки) — отказ слышно.
		Audio.play(AudioDirector.BLOCK)
		return
	_release_drag()
	var grabbed: Array[IngredientNode] = [primary]
	var radius := 0.0
	var active_tool := player.get_active_tool()
	if active_tool != null:
		radius = active_tool.model.get_grab_radius()
	if radius > 0.0:
		# Сито: захват всех подходящих ингредиентов в небольшой области.
		for node in _ingredients():
			if node != primary and _grab_allowed(node, rod) \
					and node.position.distance_to(point) <= radius:
				grabbed.append(node)
	for node in grabbed:
		# Основной ингредиент хватается за точку клика и тянется ровно к
		# курсору — смещение нулевое, иначе точка захвата сходится не к
		# мышке, а к мышке + (центр - клик). Соседи из сита хватаются за
		# свой центр со смещением строя относительно точки клика.
		node.start_drag(point if node == primary else node.global_position)
		_drag_nodes.append(node)
		_drag_offsets.append(Vector2.ZERO if node == primary
				else node.global_position - point)


func _grab_allowed(node: IngredientNode, rod: bool) -> bool:
	if not node.can_be_grabbed():
		return false
	# В области врага двигать ингредиенты нельзя — если нет удочки.
	if not rod and field_side_of(node) == FieldSide.ENEMY:
		return false
	return true


func _rod_active() -> bool:
	var active_tool := player.get_active_tool()
	return active_tool != null and active_tool.model.can_touch_enemy_area()


func _process_drag() -> void:
	if _drag_nodes.is_empty():
		return
	var rod := _rod_active()
	var mouse := get_global_mouse_position()
	for i in range(_drag_nodes.size() - 1, -1, -1):
		var node := _drag_nodes[i]
		# Захват отдирает приклеенное, но клей может поймать его снова прямо
		# в руке — тогда перетаскивание обрывается, как у замороженного.
		if not is_instance_valid(node) or node.frozen or node.glued:
			_drop_drag_index(i)
			continue
		# Без удочки ингредиент, затянутый в область врага, отпускается
		# (долетит туда уже по инерции).
		if not rod and enemy_area.has_point(node.position):
			_drop_drag_index(i)
			continue
		node.apply_drag_force(mouse + _drag_offsets[i])


func _drop_drag_index(i: int) -> void:
	var node := _drag_nodes[i]
	if is_instance_valid(node):
		node.end_drag()
	_drag_nodes.remove_at(i)
	_drag_offsets.remove_at(i)


func _release_drag() -> void:
	for node in _drag_nodes:
		if is_instance_valid(node):
			node.end_drag()
	_drag_nodes.clear()
	_drag_offsets.clear()


## Линии «тяги» для оверлея (CombatDragOverlay): пары
## [точка захвата, цель пружины] для каждого перетаскиваемого ингредиента.
func get_drag_lines() -> Array:
	var lines := []
	var mouse := get_global_mouse_position()
	for i in _drag_nodes.size():
		var node := _drag_nodes[i]
		if is_instance_valid(node) and node.is_dragging():
			lines.append([node.grab_point_global(), mouse + _drag_offsets[i]])
	return lines


## Ингредиент под курсором: точное попадание, а если под самим курсором
## пусто — ближайший в кругу захвата ([member CombatConfig.grab_radius]).
func _node_at_point(point: Vector2) -> IngredientNode:
	for body in GrabArea.bodies_at(get_world_2d(), point, config.grab_radius):
		var node := body as IngredientNode
		if node != null:
			return node
	return null


## Притяжение от специй (сейчас это мята): слабое постоянное подтягивание
## полезных ингредиентов к полю игрока. Настраивается целиком в ресурсе самой
## специи ([SpiceMint], da_spice_mint.tres) — сила, кого тянет, до какой
## скорости разгоняет, отпускать ли долетевшее и работать ли только в раунде;
## режим боя только раздаёт силу. Специи складываются: две тянущие специи
## тянут вдвое сильнее, но каждая по своим правилам.
##
## По умолчанию притяжение идёт только в фазе PLAY — когда пошёл таймер
## и ингредиенты можно трогать. Пока они высыпаются и ждут «Обратного
## отсчёта», мята не тянет: иначе она растаскивала бы стол до начала раунда.
func _process_spice_attraction(_delta: float) -> void:
	for spice in player.spices:
		var pull := spice.get_useful_attraction()
		if pull <= 0.0:
			continue
		if spice.get_attraction_only_in_round() and phase != Phase.PLAY:
			continue
		_apply_spice_attraction(spice, pull)


## Одна тянущая специя: подтягивает к середине поля игрока всё, что подходит
## под её правила.
func _apply_spice_attraction(spice: SpiceModel, pull: float) -> void:
	var target := player_area.get_center()
	var min_multiplier := spice.get_attraction_min_multiplier()
	var max_speed := spice.get_attraction_max_speed()
	var stops_on_field := spice.get_attraction_stops_on_field()
	for node in _ingredients():
		if node.frozen or node.glued or node.is_airborne() or node.untouchable:
			continue
		if node.model.multiplier <= min_multiplier:
			continue
		if stops_on_field and player_area.has_point(node.position):
			continue
		# Дошёл до предела скорости — дальше катится сам, специя не добавляет.
		if max_speed > 0.0 and node.linear_velocity.length() >= max_speed:
			continue
		var dir := (target - node.position).normalized()
		node.apply_central_force(dir * pull * node.mass)


# --- Инструменты ---

## Выбор инструмента на раунд. Окно ([HudToolStorage]) раскрывается само,
## как только всё легло на стол: клик по инструменту выбирает его (он
## светится), кнопка «Продолжить» заканчивает выбор. Окно можно спрятать
## кнопкой слева — раунд подождёт, а игрок пока посмотрит холодильник,
## специи и корзину. Инструменты на кулдауне видно (затемнены, с цифрой),
## но выбрать их нельзя — тогда раунд идёт без инструмента. Совсем без
## инструментов окно не показывается (чистый ранний бой).
func _select_tool() -> void:
	round_state.select_tool(null)
	if player.tools.is_empty():
		return
	phase = Phase.TOOL_SELECT
	_tool_confirmed = false
	# Мешок рисуется поверх HUD — иначе он накрыл бы окно собой.
	close_bag()
	_hud.open_tool_select()
	while not _tool_confirmed:
		await get_tree().process_frame
	_hud.close_tool_select()
	# Выбранный инструмент вступает в силу — и, если у него есть способность
	# (щипцы, удочка, тесак), она разыгрывается сразу же.
	round_state.apply_selected_tool()
	await _player_tool_ability()


func _on_tool_selected(tool_state: ToolState) -> void:
	if phase != Phase.TOOL_SELECT:
		return
	round_state.select_tool(tool_state)


func _on_tool_confirmed() -> void:
	if phase == Phase.TOOL_SELECT:
		_tool_confirmed = true


func _on_burn_skipped() -> void:
	_burn_done = true


## Кнопка «Обратный отсчёт»: по нажатию идёт отсчёт «3 2 1» на весь экран,
## и только после него запускается таймер раунда. Ингредиенты становятся
## подвижными в фазе PLAY, то есть после отсчёта (см. _unhandled_input).
func _on_start_pressed() -> void:
	if phase == Phase.READY:
		_start_pressed = true


## Горелка: выжечь ингредиент под курсором (можно даже вечный). Ингредиент
## растворяется шейдером от точки клика, и только после этого фаза кончается.
func _try_burn_at(point: Vector2) -> void:
	if _burn_running:
		return
	var node := _node_at_point(point)
	if node == null:
		return
	if node.untouchable:
		Audio.play(AudioDirector.BLOCK)
		_hud.notify("%s can't be touched this round" % node.model.display_name)
		return
	_burn_running = true
	_hud.burn_active = false
	# Жертва выбрана: надпись, кнопка и горелка уходят, тень висит до конца
	# растворения — её снимет конец фазы.
	if _burn_overlay != null:
		_burn_overlay.lock()
	_hud.notify_burned("Burner destroyed: %s" % node.model.display_name)
	await node.burn_away(theme.burn_material, theme.burn_duration, node.uv_at_global(point))
	_burn_running = false
	_burn_done = true
	# Сгоревший вечный освобождает место — предпросмотр усиления обновляется.
	_refresh_enemy_basket.call_deferred()


## Сжигание врага в конце хода: минибосс выжигает у игрока с поля
## [member EnemyModel.burn_player_ingredients] самых ценных ингредиентов —
## тех, что дали бы больше всего очков. Идёт до подсчёта, поэтому очки за них
## игрок не получает. Ингредиенты в минус и в ноль враг не жжёт: они и так
## работают против игрока.
func _enemy_burn() -> void:
	if enemy == null or enemy.burn_player_ingredients <= 0:
		return
	phase = Phase.ENEMY_BURN
	for _i in enemy.burn_player_ingredients:
		var target := _best_player_ingredient()
		if target == null:
			return
		_hud.notify_burned("%s burns: %s" % [enemy.display_name, target.model.display_name])
		# Огонь идёт со стороны врага: точка снаружи прижимается к той кромке
		# изображения, которая смотрит на его половину стола.
		await target.burn_away(theme.burn_material, theme.burn_duration,
				target.uv_at_global(enemy_area.get_center()))


## Способности врага перед раундом. Идут после того, как всё упало на стол,
## и до того, как игрок сможет нажать «Обратный отсчёт», — так что утащенное
## успевает лечь и посчитается уже в пользу врага. У врага может быть больше
## одной способности; чего нет, то молча пропускается.
func _enemy_ability() -> void:
	await _enemy_tongs()
	await _enemy_hook()
	await _enemy_cleaver()


## Щипцы минибосса ([TongsNode]) прилетают справа снизу за границей стола,
## хватают с нейтральной зоны самые ценные ингредиенты и уносят их на
## половину врага. Только в ходах с [member EnemyMove.uses_ability].
func _enemy_tongs() -> void:
	if enemy == null or enemy.tongs == null or not enemy_state.move_uses_ability():
		return
	var targets := _tongs_targets(enemy.tongs.steal_count, FieldSide.NONE)
	if targets.is_empty():
		return
	phase = Phase.ABILITY
	# Куда класть добычу: свободные места на половине врага. Занятыми считаем
	# всё, что уже лежит на столе, кроме самой добычи.
	var taken := []
	for node in _ingredients():
		if not targets.has(node):
			taken.append([node.position, node.model.radius])
	var drop_points: Array[Vector2] = []
	for node in targets:
		drop_points.append(_landing_point(enemy_area, node.model.radius, taken))
	var tongs := TongsNode.create(enemy.tongs, config, _rng)
	add_child(tongs)
	tongs.ingredient_grabbed.connect(_on_tongs_grabbed)
	await tongs.run_steal(targets, drop_points,
			field_bounds.end + enemy.tongs.entry_offset)
	tongs.queue_free()
	# Последний сброшенный ингредиент ещё подпрыгивает — дать ему улечься.
	await _wait_all_landed()


func _on_tongs_grabbed(node: IngredientNode) -> void:
	_hud.notify("%s drags away: %s" % [enemy.display_name, node.model.display_name])


## Крюк минибосса-рыбака ([HookNode]): вылетает справа, из-за края стола, за
## самым далёким от врага полезным ингредиентом и тянет его на половину врага.
func _enemy_hook() -> void:
	if enemy == null or enemy.hook == null:
		return
	await _run_hook(enemy.hook, FieldSide.ENEMY, enemy.display_name)


## Заброс крюка ([HookNode]) в пользу стороны side: крюк вылетает из-за края
## стола со стороны хозяина, цепляет самое далёкое от него полезное и тянет
## **до середины** его половины — не до первой попавшейся свободной точки и не
## до кромки поля. Тянет физически: добыча едет по столу сама и расталкивает
## всё на пути. Как только она доехала, стол замирает целиком
## ([method _stop_all_ingredients]): иначе и добыча, и расталканные ею соседи
## разъезжались бы дальше — трение стола слабое.
##
## Один и тот же проход и у врага (справа, добыча едет к нему), и у игрока
## с удочкой ([ToolRod]) — тому же крюку меняются только сторона и хозяин.
func _run_hook(ability: HookAbility, side: FieldSide, actor: String) -> void:
	var home_area := enemy_area if side == FieldSide.ENEMY else player_area
	var targets := _hook_targets(ability.pull_count, side)
	if targets.is_empty():
		if side == FieldSide.PLAYER:
			_hud.notify("Nothing for the hook to reel in")
		return
	phase = Phase.ABILITY
	# Куда тянуть: середина своей половины. Добыча едет туда как есть и
	# расталкивает то, что там лежало, — место под неё заранее не ищется.
	var reel_points: Array[Vector2] = []
	for _node in targets:
		reel_points.append(home_area.get_center())
	var hook := HookNode.create(ability, _rng)
	add_child(hook)
	hook.ingredient_hooked.connect(_on_ingredient_hooked.bind(actor))
	hook.ingredient_delivered.connect(_on_ingredient_delivered)
	# Удилище стоит со стороны хозяина: у врага — за правым краем стола,
	# у игрока — за левым, отступ по высоте тот же.
	var rod := field_bounds.end + ability.entry_offset
	if side == FieldSide.PLAYER:
		rod = Vector2(field_bounds.position.x - ability.entry_offset.x,
				field_bounds.end.y + ability.entry_offset.y)
	await hook.run_pull(targets, reel_points, rod)
	hook.queue_free()
	# Страховка на случай таймаута: добыча могла и не доехать, но стол всё
	# равно не должен уезжать дальше.
	_stop_all_ingredients()
	# Крюк ушёл — добычу можно вернуть в физику: она стоит на месте, и трогать
	# её игрок всё равно сможет только с началом раунда. Стол при этом ещё
	# гасится: разбуженная добыча и её соседи расходятся из перекрытия, и без
	# затухания они разъехались бы по всему полю.
	for node in targets:
		if is_instance_valid(node):
			node.wake()
	await get_tree().create_timer(ability.settle_pause).timeout
	_table_settling = false
	_stop_all_ingredients()
	await _wait_all_landed()


func _on_ingredient_hooked(node: IngredientNode, actor: String) -> void:
	# Крюк взялся за новую добычу — её тянуть надо, а не гасить.
	_table_settling = false
	_hud.notify("%s hooks: %s" % [actor, node.model.display_name])


## Крюк довёл добычу до середины своей половины и отпустил. Добыча замирает
## намертво ровно в этой точке ([method IngredientNode.hold_still]): гасить
## одну скорость мало — пружина крюка успевает подать силу за тот же кадр,
## и ингредиент проезжает мимо. Стол при этом не просто останавливается один
## раз, а гасится каждый тик ([member _table_settling]): добыча приезжает
## в кучу, и расталкивание перекрытия решатель раздаёт кадр за кадром —
## разово обнулённый стол тут же поехал бы снова.
func _on_ingredient_delivered(node: IngredientNode) -> void:
	if is_instance_valid(node):
		node.hold_still()
	_stop_all_ingredients()
	_table_settling = true


## Кого цепляет крюк стороны side: самые далёкие от её половины полезные
## ингредиенты (множитель больше 0) — вредные и пустые крюк не тянет. Лежащее
## у самого хозяина крюка, вечное и застывшее не в счёт.
func _hook_targets(count: int, side: FieldSide) -> Array[IngredientNode]:
	var home_area := enemy_area if side == FieldSide.ENEMY else player_area
	var home := home_area.get_center()
	var candidates: Array[IngredientNode] = []
	for node in _ingredients():
		if field_side_of(node) == side:
			continue
		if node.model.multiplier <= 0.0 or not node.is_movable() or node.glued:
			continue
		candidates.append(node)
	candidates.sort_custom(func(a: IngredientNode, b: IngredientNode) -> bool:
		return a.position.distance_to(home) > b.position.distance_to(home))
	return candidates.slice(0, maxi(count, 0))


## Удар тесака минибосса ([CleaverNode]): он рубит ровно по центру стола и
## увозит накрытое лезвием на свою половину. Идёт через раунд
## ([member CleaverAbility.every_n_rounds]).
func _enemy_cleaver() -> void:
	if enemy == null or enemy.cleaver == null:
		return
	if not enemy.cleaver.strikes_on_round(round_number):
		return
	await _run_cleaver(enemy.cleaver, FieldSide.ENEMY, enemy.display_name)


## Удар тесака ([CleaverNode]) в пользу стороны side: лезвие падает ровно на
## центр стола. От удара подпрыгивает всё, что лежит на столе, — кроме того,
## что накрыло само лезвие ([member CleaverAbility.texture]): задетое лезвие
## медленно увозит с центра на половину side.
##
## Один и тот же проход и у врага (задетое едет к нему), и у игрока с тесаком
## ([ToolCleaver]) — тому же лезвию меняется только сторона сдвига.
func _run_cleaver(ability: CleaverAbility, side: FieldSide, actor: String) -> void:
	var home_area := enemy_area if side == FieldSide.ENEMY else player_area
	phase = Phase.ABILITY
	# «Своя сторона» тесака: туда, где лежит половина хозяина. Смещение линии
	# удара тоже считается от центра стола в свою сторону.
	var side_dir := signf(home_area.get_center().x - pour_zone.get_center().x)
	var push_dir := Vector2(side_dir if side_dir != 0.0 else 1.0, 0.0)
	# Бьёт по центру стола — по середине зоны высыпания.
	var strike_x := pour_zone.get_center().x + ability.strike_line_offset * push_dir.x
	var blade := CleaverNode.create(ability)
	add_child(blade)
	blade.blade_landed.connect(_on_cleaver_landed.bind(ability, actor))
	blade.blade_pushed.connect(_on_cleaver_pushed)
	# Тесак виден только сверху: он появляется прямо над линией удара —
	# крупным (занесён высоко) — и уменьшается, пока падает на стол.
	await blade.run_strike(Vector2(strike_x, pour_zone.get_center().y), push_dir)
	blade.queue_free()
	_cleaver_cut.clear()
	# Тесак ушёл — стол замирает: ни сдвинутые, ни расталканные ими соседи
	# не должны разъезжаться дальше (трение стола слабое, иначе они катятся
	# чуть ли не до конца раунда).
	_stop_all_ingredients()
	# Подскоки ещё гаснут — дать столу улечься.
	await get_tree().create_timer(ability.settle_pause).timeout
	_stop_all_ingredients()
	await _wait_all_landed()


## Лезвие легло на стол: всё, что вне полосы удара, подпрыгивает на месте,
## а накрытое лезвием запоминается — его тесак повезёт с собой.
func _on_cleaver_landed(band: Rect2, ability: CleaverAbility, actor: String) -> void:
	_cleaver_cut.clear()
	for node in _ingredients():
		if node.frozen or node.glued or node.is_airborne() or not node.is_movable():
			continue
		if band.intersects(_ingredient_box(node)):
			_cleaver_cut.append(node)
			continue
		var height := ability.hop_height \
				+ _rng.randf_range(-ability.hop_height_variance, ability.hop_height_variance)
		node.hop(height, ability.hop_gravity, ability.hop_bounce)
	_hud.notify("%s chops the middle of the table!" % actor)


## Лезвие поехало на свою половину: задетое едет с ним с той же скоростью.
## Скорость задаётся каждый физический тик, поэтому ингредиенты не разгоняются,
## а ползут вместе с лезвием и толкают всё, что попадётся; в конце сдвига они
## встают.
func _on_cleaver_pushed(velocity: Vector2, duration: float) -> void:
	var moved: Array[IngredientNode] = _cleaver_cut.duplicate()
	var elapsed := 0.0
	while elapsed < duration:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		for node in moved:
			if _is_pushable(node):
				node.linear_velocity = velocity
	for node in moved:
		if _is_pushable(node):
			node.linear_velocity = Vector2.ZERO


## Остановить весь стол: всё, что ещё едет, замирает там, где оказалось.
## Зовётся после удара тесака — способность не должна оставлять после себя
## разъезжающиеся ингредиенты.
func _stop_all_ingredients() -> void:
	for node in _ingredients():
		node.stop()


## Гасить стол постепенно: каждый физический тик скорости режутся в
## [constant TABLE_SETTLE_DAMP] раз. Нужно там, где одного
## [method _stop_all_ingredients] мало: перекрывшиеся тела решатель
## расталкивает не мгновенно, а кадр за кадром, и обнулённый стол тут же
## начинает разъезжаться заново. Затухание даёт им разойтись, но ползком —
## за доли секунды всё встаёт.
func _damp_all_ingredients() -> void:
	for node in _ingredients():
		node.linear_velocity *= TABLE_SETTLE_DAMP
		node.angular_velocity *= TABLE_SETTLE_DAMP


## Можно ли ещё двигать ингредиент лезвием: он жив, не заморожен, не приклеен
## и не застыл на месте.
func _is_pushable(node: IngredientNode) -> bool:
	return is_instance_valid(node) and not node.frozen and not node.glued \
			and not node.is_airborne() and node.is_movable()


## Габаритный квадрат ингредиента на столе (по радиусу модели) — по нему
## считается попадание в полосу удара тесака.
func _ingredient_box(node: IngredientNode) -> Rect2:
	var r := node.model.radius
	return Rect2(node.global_position - Vector2(r, r), Vector2(r, r) * 2.0)


## Способности выбранного инструмента — зеркала способностей минибоссов: они
## разыгрываются сразу после выбора инструмента, до кнопки «Обратный отсчёт»,
## поэтому добыча успевает лечь и посчитается уже игроку. Порядок тот же, что
## у врага ([method _enemy_ability]); чего у инструмента нет, то пропускается.
func _player_tool_ability() -> void:
	var active_tool := player.get_active_tool()
	if active_tool == null:
		return
	await _player_tongs(active_tool.model)
	await _player_hook(active_tool.model)
	await _player_cleaver(active_tool.model)


## Удочка игрока ([ToolRod]) — зеркало крюка минибосса-рыбака: крюк вылетает
## слева, из-за края стола, за самым далёким от игрока полезным ингредиентом
## и тянет его к игроку — до середины его половины.
func _player_hook(tool_model: ToolModel) -> void:
	var ability := tool_model.get_hook_ability()
	if ability == null:
		return
	await _run_hook(ability, FieldSide.PLAYER, "The rod")


## Тесак игрока ([ToolCleaver]) — зеркало тесака минибосса: лезвие падает на
## середину стола, подбрасывает всё вокруг, а накрытое собой увозит на половину
## игрока. Кулдаун инструмента и есть его «через раунд», поэтому
## [member CleaverAbility.every_n_rounds] здесь не спрашивается.
func _player_cleaver(tool_model: ToolModel) -> void:
	var ability := tool_model.get_cleaver_ability()
	if ability == null:
		return
	await _run_cleaver(ability, FieldSide.PLAYER, "The cleaver")


## Щипцы игрока ([ToolTongs]) — зеркало способности минибосса: прилетают слева
## снизу и утаскивают самое ценное с половины врага на половину игрока.
func _player_tongs(tool_model: ToolModel) -> void:
	var ability := tool_model.get_tongs_ability()
	if ability == null:
		return
	var targets := _tongs_targets(ability.steal_count, FieldSide.ENEMY)
	if targets.is_empty():
		_hud.notify("Nothing for the tongs to drag from the enemy half")
		return
	phase = Phase.ABILITY
	# Куда класть добычу: свободные места на половине игрока. Занятыми
	# считаем всё, что уже лежит на столе, кроме самой добычи.
	var taken := []
	for node in _ingredients():
		if not targets.has(node):
			taken.append([node.position, node.model.radius])
	var drop_points: Array[Vector2] = []
	for node in targets:
		drop_points.append(_landing_point(player_area, node.model.radius, taken))
	var tongs := TongsNode.create(ability, config, _rng)
	add_child(tongs)
	tongs.ingredient_grabbed.connect(_on_player_tongs_grabbed)
	# Щипцы игрока приходят с его стороны — слева снизу за границей стола.
	await tongs.run_steal(targets, drop_points, Vector2(
			field_bounds.position.x - ability.entry_offset.x,
			field_bounds.end.y + ability.entry_offset.y))
	tongs.queue_free()
	# Последний сброшенный ингредиент ещё подпрыгивает — дать ему улечься.
	await _wait_all_landed()


func _on_player_tongs_grabbed(node: IngredientNode) -> void:
	_hud.notify("Tongs drag away: %s" % node.model.display_name)


## Кого утащат щипцы: ингредиенты со стороны side (у врага — с нейтральной
## зоны, у игрока — с половины врага) с множителем больше 0 — вредные и
## пустые щипцы не берут. Самые ценные идут первыми, вечные и застывшие
## не в счёт.
func _tongs_targets(count: int, side: FieldSide) -> Array[IngredientNode]:
	var candidates: Array[IngredientNode] = []
	for node in _ingredients():
		if field_side_of(node) != side:
			continue
		if node.model.multiplier <= 0.0 or not node.is_movable() or node.glued:
			continue
		candidates.append(node)
	candidates.sort_custom(func(a: IngredientNode, b: IngredientNode) -> bool:
		return a.model.base_points() > b.model.base_points())
	return candidates.slice(0, maxi(count, 0))


## Самый ценный ингредиент на поле игрока (очки — как при подсчёте, со
## специями); null, если приносящих очки ингредиентов там нет.
func _best_player_ingredient() -> IngredientNode:
	var best: IngredientNode = null
	var best_points := 0.0
	for node in _ingredients():
		if field_side_of(node) != FieldSide.PLAYER:
			continue
		var points := _points_for(node.model, true)
		if points > best_points:
			best = node
			best_points = points
	return best


# --- Отрисовка стола (фон — узел Background, зоны и границы — CombatZone) ---

func _draw() -> void:
	if config == null or theme == null:
		return
	var table_rect := field_bounds.grow(theme.table_margin)
	if theme.table_texture != null:
		draw_texture_rect(theme.table_texture, table_rect, false)
	else:
		draw_rect(table_rect, theme.table_color)
