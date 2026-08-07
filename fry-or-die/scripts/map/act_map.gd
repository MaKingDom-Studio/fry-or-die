## Карта забега: граф точек ([MapNode]) от входа в кухню до босса.
##
## Форма карты — вступление одной общей линией и две линии, расходящиеся
## от его магазина. Дважды линии сходятся в общий магазин: перед
## последними минибоссами и перед боссом.
##
## [codeblock]
##                 B          босс
##                 S          общий магазин перед боссом
##            /         \
##           M           M    последние минибоссы
##            \         /
##                 S          ОДИН общий магазин на все линии
##            /         \
##           o           o    бои линий
##           |           |
##           o           o
##           |           |
##           M           M    первые минибоссы: Tongie и Fireman
##            \         /
##                 S          общий магазин вступления
##                 |
##                 o          3-й бой — всегда third_enemy (Liza)
##                 |
##                 o          2-й бой — всегда second_enemy (avatar)
##                 |
##                 o          1-й бой — всегда first_enemy (Chef_1)
##                 |
##                 o          вход в кухню
## [/codeblock]
##
## Что генератор гарантирует (правила и числа — в [ActMapConfig]):
##
## - забег открывает вступление одной общей линией: три боя, которые
##   всегда одни и те же (`first_enemy`, `second_enemy`, `third_enemy`),
##   и общий магазин перед первыми минибоссами — линии расходятся уже
##   от него;
## - на каждой линии ровно `minibosses_per_branch` минибосса (по умолчанию 2)
##   и минимум один магазин (общие засчитываются);
## - всего на карте `enemies_total` обычных боёв: три из них — вступление,
##   остальные поделены между линиями поровну; минибоссов
##   `branches * minibosses_per_branch` (по умолчанию 4), магазинов
##   `shops_min`..`shops_max` вместе с общими;
## - магазин стоит вплотную перед минибоссом;
## - магазин перед последними минибоссами — один на все линии
##   (`shared_shop_before_last_miniboss`);
## - нижний минибосс каждой линии — из `first_miniboss_pool` (Tongie и
##   Fireman): их игрок и встречает первыми;
## - минибоссы по карте не повторяются, пока хватает пула.
##
## Игрок идёт снизу вверх: из текущей точки доступны только её дети
## ([method travelable]). Вступление идёт одной линией; от его магазина
## игрок выбирает линию, и она ведёт наверх сама по себе, пока линии
## снова не сойдутся в общем магазине, — оттуда можно пойти к минибоссу
## любой из них.
##
## Точки расставлены по рядам: ряд — это одна высота на карте, и общий
## магазин стоит в своём ряду между боями и минибоссами, поэтому линии
## сходятся к нему с обеих сторон.
class_name ActMap
extends RefCounted

var config: ActMapConfig
## Нижняя точка карты — вход в кухню.
var start: MapNode
## Верхняя точка карты — босс.
var boss: MapNode
## Общий магазин перед боссом; null, если он выключен в конфиге.
var hub: MapNode
## Все точки карты, в порядке создания.
var nodes: Array[MapNode] = []
## Где игрок стоит сейчас.
var current: MapNode


## Построить карту по конфигу. rng задаёт раскладку магазинов, порядок
## врагов и «дрожь» кружков; null — свой генератор со случайным сидом.
static func generate(map_config: ActMapConfig, rng: RandomNumberGenerator = null) -> ActMap:
	var map := ActMap.new()
	map.config = map_config if map_config != null else ActMapConfig.new()
	var gen := rng
	if gen == null:
		gen = RandomNumberGenerator.new()
		gen.randomize()
	map._build(gen)
	return map


# --- Перемещение ---

## Куда можно шагнуть из текущей точки: только дети (точки ряда выше).
func travelable() -> Array[MapNode]:
	if current != null:
		# В магазин, на котором игрок стоит, можно зайти ещё раз: витрина
		# у него та же ([method MapNode.is_revisitable]).
		if not current.is_revisitable():
			return current.children
		var result := current.children.duplicate()
		result.append(current)
		return result
	var from_start: Array[MapNode] = []
	if start != null:
		from_start.append(start)
	return from_start


func can_enter(node: MapNode) -> bool:
	return node != null and travelable().has(node)


## Встать на точку. false — туда с текущей точки хода нет.
func enter(node: MapNode) -> bool:
	if not can_enter(node):
		return false
	current = node
	return true


## Забег дошёл до босса и босс побеждён.
func is_finished() -> bool:
	return boss != null and boss.cleared


## Сколько листков соберётся на игле за забег: длина самого длинного
## маршрута от входа в кухню до босса, без самого входа (он пройден сразу
## и листка не оставляет). По этому числу игла и рассчитывается — чтобы
## стопка уместилась целиком.
func route_length() -> int:
	if start == null:
		return 0
	return _longest_path(start, {}) - 1


## Длина самого длинного пути вверх от точки, считая её саму. `seen`
## хранит уже посчитанные точки: линии сходятся в общем магазине, поэтому
## его поддерево иначе считалось бы дважды.
func _longest_path(node: MapNode, seen: Dictionary) -> int:
	if seen.has(node):
		return seen[node]
	var longest := 0
	for child: MapNode in node.children:
		longest = maxi(longest, _longest_path(child, seen))
	var length := longest + 1
	seen[node] = length
	return length


## Сколько каких точек получилось — для отладки и проверок в тестах.
func counts() -> Dictionary:
	var result := {
		MapNode.Kind.START: 0,
		MapNode.Kind.ENEMY: 0,
		MapNode.Kind.MINIBOSS: 0,
		MapNode.Kind.SHOP: 0,
		MapNode.Kind.BOSS: 0,
	}
	for node: MapNode in nodes:
		result[node.kind] += 1
	return result


# --- Генерация ---

func _build(rng: RandomNumberGenerator) -> void:
	var branches: int = maxi(config.branches, 1)
	var minibosses: int = maxi(config.minibosses_per_branch, 1)

	start = _add(MapNode.Kind.START, -1)
	start.row_frac = 0.0
	# На входе в кухню игрок уже стоит — точка сразу считается пройденной.
	start.cleared = true

	# Вступление — нижний сегмент карты: три всегда одинаковых боя одной
	# общей линией и общий магазин перед первыми минибоссами.
	var intro := _intro_enemies()

	# Остальные бои идут в сегменты выше первых минибоссов: делятся между
	# линиями поровну, а внутри линии — между её сегментами. Сегмент —
	# участок линии, который замыкает минибосс.
	var upper_segments := minibosses - 1
	var enemies_per_branch := _split(maxi(config.enemies_total - intro.size(), 0), branches)
	var segments: Array = []
	for branch in branches:
		var per_segment: Array[int] = [0]
		if upper_segments > 0:
			per_segment.append_array(_split(enemies_per_branch[branch], upper_segments))
		segments.append(per_segment)

	# Перед последними минибоссами магазин один на все линии, поэтому он
	# в раскладку магазинов линий не входит.
	var shared_last := config.shared_shop_before_last_miniboss
	var own_shops := _plan_own_shops(branches, minibosses, shared_last, rng)

	var enemy_deck: Array[EnemyModel] = []
	var miniboss_deck: Array[EnemyModel] = []
	# Самых первых минибоссов раздаём из своей колоды: нижний минибосс
	# каждой линии — Tongie или Fireman, и на разных линиях они разные.
	var first_miniboss_deck: Array[EnemyModel] = []

	# Сколько всего рядов до последнего минибосса — по ним точки и
	# раскладываются по высоте панели.
	var rows := 0
	for segment in minibosses:
		rows += _segment_rows(segments, branches, segment, own_shops, shared_last,
				minibosses, intro.size())

	# Хвост каждой линии: к нему цепляется следующий её ряд.
	var tails: Array[MapNode] = []
	for _i in branches:
		tails.append(start)

	var row := 0
	for segment in minibosses:
		if segment == 0:
			row = _build_intro(intro, branches, tails, row, rows, rng)
		else:
			# Бои сегмента: ряд за рядом, по одному бою с каждой линии. Если
			# у линии боёв в сегменте меньше, она этот ряд пропускает.
			var deepest := 0
			for branch in branches:
				deepest = maxi(deepest, segments[branch][segment])
			for step in deepest:
				for branch in branches:
					if step >= segments[branch][segment]:
						continue
					var fight := _add(MapNode.Kind.ENEMY, branch)
					fight.enemy = _draw(enemy_deck, config.enemy_pool, rng)
					_place(fight, branch, branches, row + step, rows, rng)
					tails[branch].link(fight)
					tails[branch] = fight
			row += deepest
			# Магазин перед минибоссом сегмента.
			if shared_last and segment == minibosses - 1:
				# Один общий на все линии: линии сходятся к нему, и уже из него
				# игрок выбирает, к чьему минибоссу идти.
				var shop := _add(MapNode.Kind.SHOP, -1)
				_place(shop, -1, branches, row, rows, rng)
				for branch in branches:
					tails[branch].link(shop)
				for branch in branches:
					tails[branch] = shop
				row += 1
			elif _has_own_shop(own_shops, branches, segment):
				for branch in branches:
					if not own_shops[branch].has(segment):
						continue
					var shop := _add(MapNode.Kind.SHOP, branch)
					_place(shop, branch, branches, row, rows, rng)
					tails[branch].link(shop)
					tails[branch] = shop
				row += 1
		# Минибосс замыкает сегмент.
		for branch in branches:
			var mini_boss := _add(MapNode.Kind.MINIBOSS, branch)
			mini_boss.enemy = _next_miniboss(segment, miniboss_deck, first_miniboss_deck, rng)
			_place(mini_boss, branch, branches, row, rows, rng)
			tails[branch].link(mini_boss)
			tails[branch] = mini_boss
		row += 1

	if config.shop_before_boss:
		hub = _add(MapNode.Kind.SHOP, -1)
		hub.row_frac = clampf(config.hub_row_frac, config.branch_top_frac, 0.99)
		hub.wobble = _wobble(rng)

	boss = _add(MapNode.Kind.BOSS, -1)
	boss.enemy = config.boss
	boss.row_frac = 1.0

	var above: MapNode = hub if hub != null else boss
	for branch in branches:
		tails[branch].link(above)
	if hub != null:
		hub.link(boss)

	current = start


## Сколько рядов занимает сегмент: бои самой длинной линии, магазин (если
## в этом сегменте он есть) и ряд минибоссов. Нижний сегмент — вступление:
## его бои идут одной общей линией, и магазин в нём стоит всегда.
func _segment_rows(segments: Array, branches: int, segment: int, own_shops: Array,
		shared_last: bool, minibosses: int, intro_fights: int) -> int:
	if segment == 0:
		return intro_fights + 2
	var deepest := 0
	for branch in branches:
		deepest = maxi(deepest, segments[branch][segment])
	var shop_row := 0
	if shared_last and segment == minibosses - 1:
		shop_row = 1
	elif _has_own_shop(own_shops, branches, segment):
		shop_row = 1
	return deepest + shop_row + 1


## Стоит ли в этом сегменте магазин хоть у одной линии.
func _has_own_shop(own_shops: Array, branches: int, segment: int) -> bool:
	for branch in branches:
		if own_shops[branch].has(segment):
			return true
	return false


## Поставить точку в ряд `row` из `rows`: колонка — по её линии, высота —
## по номеру ряда, и поверх этого «дрожь» от руки.
func _place(node: MapNode, branch: int, branches: int, row: int, rows: int,
		rng: RandomNumberGenerator) -> void:
	node.index = row
	node.column = _column(branch, branches)
	node.wobble = _wobble(rng)
	node.row_frac = float(row + 1) / float(rows + 1) * config.branch_top_frac


## Сдвиг линии от центра карты: при двух линиях это -1 и +1, у общих
## точек — 0.
func _column(branch: int, branches: int) -> float:
	if branch < 0:
		return 0.0
	if branches <= 1:
		return -1.0
	return lerpf(-1.0, 1.0, float(branch) / float(branches - 1))


## В каких сегментах у каждой линии стоит свой магазин. Нижний сегмент —
## вступление с общим магазином, а магазин перед последними минибоссами
## общий, поэтому эти места линиям не достаются: свои магазины
## раскидываются по сегментам между ними, по одному на сегмент (магазин
## стоит прямо перед минибоссом).
func _plan_own_shops(branches: int, minibosses: int, shared_last: bool,
		rng: RandomNumberGenerator) -> Array:
	var own: Array = []
	for _i in branches:
		own.append([] as Array[int])
	var free_segments := minibosses - 1 - (1 if shared_last else 0)
	if free_segments <= 0:
		return own
	var hub_shop := 1 if config.shop_before_boss else 0
	# Общие магазины уже стоят на пути каждой линии — во вступлении и,
	# если включён, перед последними минибоссами, — поэтому в
	# гарантированный минимум линии они и засчитываются.
	var shared := 1 + (1 if shared_last else 0)
	var guaranteed: int = clampi(config.shops_per_branch_min - shared, 0, free_segments)
	var low: int = maxi(config.shops_min, branches * guaranteed + shared + hub_shop)
	var high: int = mini(maxi(config.shops_max, low),
			branches * free_segments + shared + hub_shop)
	var total := rng.randi_range(low, high) - shared - hub_shop

	var counts: Array[int] = []
	for _i in branches:
		counts.append(guaranteed)
	var left := total - branches * guaranteed
	# Куда ещё влезет магазин: по одному месту на каждый свободный сегмент.
	var free_slots: Array[int] = []
	for branch in branches:
		for _i in free_segments - guaranteed:
			free_slots.append(branch)
	free_slots.shuffle()
	while left > 0 and not free_slots.is_empty():
		var branch: int = free_slots.pop_back()
		counts[branch] += 1
		left -= 1
	for branch in branches:
		# Свободные сегменты идут сразу над первыми минибоссами, поэтому
		# их номера на карте — со сдвигом на вступление.
		var picked := _pick_segments(free_segments, counts[branch], rng)
		var shifted: Array[int] = []
		for segment in picked:
			shifted.append(segment + 1)
		own[branch] = shifted
	return own


## В каких сегментах линии стоят магазины: `count` разных сегментов
## из `segments`.
func _pick_segments(segments: int, count: int, rng: RandomNumberGenerator) -> Array[int]:
	var pool: Array[int] = []
	for i in segments:
		pool.append(i)
	var picked: Array[int] = []
	for _i in mini(count, segments):
		var segment: int = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		picked.append(segment)
	return picked


## Бои вступления, в порядке прохождения. Первые три врага забега всегда
## одни и те же — [member ActMapConfig.first_enemy],
## [member ActMapConfig.second_enemy] и [member ActMapConfig.third_enemy];
## пустые поля пропускаются.
func _intro_enemies() -> Array[EnemyModel]:
	var intro: Array[EnemyModel] = []
	for model: EnemyModel in [config.first_enemy, config.second_enemy, config.third_enemy]:
		if model != null:
			intro.append(model)
	return intro


## Вступление забега — одна общая линия до первых минибоссов: три всегда
## одинаковых боя друг за другом и общий магазин. Хвосты всех линий
## сходятся на магазине: из него игрок и выбирает, к чьему минибоссу
## идти. Возвращает ряд, с которого карта продолжается.
func _build_intro(intro: Array[EnemyModel], branches: int, tails: Array[MapNode],
		row: int, rows: int, rng: RandomNumberGenerator) -> int:
	var tail := start
	for enemy_model in intro:
		var fight := _add(MapNode.Kind.ENEMY, -1)
		fight.enemy = enemy_model
		_place(fight, -1, branches, row, rows, rng)
		tail.link(fight)
		tail = fight
		row += 1
	var shop := _add(MapNode.Kind.SHOP, -1)
	_place(shop, -1, branches, row, rows, rng)
	tail.link(shop)
	row += 1
	for branch in branches:
		tails[branch] = shop
	return row


## Минибосс сегмента линии. Нижний сегмент (segment == 0) — это первый
## минибосс забега, поэтому он тянется из отдельного пула самых первых
## минибоссов (Tongie и Fireman); остальные — из общего.
func _next_miniboss(segment: int, deck: Array[EnemyModel],
		first_deck: Array[EnemyModel], rng: RandomNumberGenerator) -> EnemyModel:
	if segment == 0 and not config.first_miniboss_pool.is_empty():
		var first := _draw(first_deck, config.first_miniboss_pool, rng)
		if first != null:
			return first
	return _draw(deck, config.miniboss_pool, rng)


## Вытянуть врага из колоды: колода — перетасованный пул, который
## раздаётся без повторов и тасуется заново, когда кончился.
func _draw(deck: Array[EnemyModel], pool: Array[EnemyModel],
		rng: RandomNumberGenerator) -> EnemyModel:
	if deck.is_empty():
		for model in pool:
			if model != null:
				deck.append(model)
		if deck.is_empty():
			return null
		_shuffle(deck, rng)
	return deck.pop_back()


func _shuffle(deck: Array[EnemyModel], rng: RandomNumberGenerator) -> void:
	for i in range(deck.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := deck[i]
		deck[i] = deck[j]
		deck[j] = swap


func _wobble(rng: RandomNumberGenerator) -> Vector2:
	var strength := config.wobble
	return Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * strength


## Поделить total на parts как можно ровнее; остаток уходит нижним частям
## (в них бои идут первыми). Каждая часть получает минимум 1.
func _split(total: int, parts: int) -> Array[int]:
	var result: Array[int] = []
	if parts <= 0:
		return result
	var amount: int = maxi(total, parts)
	var base := amount / parts
	var extra := amount % parts
	for i in parts:
		result.append(base + (1 if i < extra else 0))
	return result


func _add(kind: MapNode.Kind, branch: int) -> MapNode:
	var node := MapNode.new()
	node.kind = kind
	node.branch = branch
	nodes.append(node)
	return node
