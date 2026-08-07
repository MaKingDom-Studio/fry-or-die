## Пер-бойное состояние врага: цикл настроенных вручную ходов,
## корзина-предпросмотр и усиление.
##
## Корзина врага показывает его следующий сброс: до высыпания — ход текущего
## раунда, после — ход следующего. Всё, что увеличивает количество
## ингредиентов на следующий ход, роллится сразу и тут же видно в корзине.
##
## Ход разворачивается в плоский список [SpawnRequest] (ингредиент + участок
## стола). Группы со случайным набором и со случайным эффектом роллятся один
## раз на раунд и кэшируются, чтобы предпросмотр корзины совпадал с тем, что
## реально выпадет.
class_name EnemyCombatState
extends RefCounted

signal basket_changed

var model: EnemyModel
var round_number := 1

var _has_dropped_this_round := false
var _pending_extras: Array[IngredientModel] = []
var _rng: RandomNumberGenerator
## Кэш разрешённого хода: номер раунда и его выкладка (для стабильного
## предпросмотра случайных наборов).
var _plan_round := -1
var _plan_cache: Array[SpawnRequest] = []


func _init(enemy_model: EnemyModel, rng: RandomNumberGenerator = null) -> void:
	model = enemy_model
	_rng = rng if rng != null else RandomNumberGenerator.new()


## Полная выкладка корзины врага (ход + доп. ингредиенты + усиление).
## live_permanents — сколько вечных ингредиентов уже стоит на поле
## (усиление капается лимитом).
func peek_basket(live_permanents: int) -> Array[SpawnRequest]:
	var upcoming := _upcoming_round()
	var result := _resolve_move(upcoming)
	for extra in _pending_extras:
		result.append(SpawnRequest.new(extra, EnemySpawnGroup.Placement.ENEMY))
	if model.is_empower_due(upcoming) and live_permanents < model.empower_limit:
		result.append(SpawnRequest.new(model.empower_ingredient, EnemySpawnGroup.Placement.ENEMY))
	return result


## Ингредиенты корзины врага без учёта размещения — для предпросмотра в UI.
func peek_basket_models(live_permanents: int) -> Array[IngredientModel]:
	var models: Array[IngredientModel] = []
	for spawn in peek_basket(live_permanents):
		models.append(spawn.model)
	return models


## Забрать сброс текущего раунда (ход + доп. ингредиенты + усиление).
func take_drop(live_permanents: int) -> Array[SpawnRequest]:
	var result := peek_basket(live_permanents)
	_pending_extras.clear()
	_has_dropped_this_round = true
	basket_changed.emit()
	return result


## Эффект «+N ингредиентов на следующий ход»: ингредиенты роллятся сразу,
## чтобы корзина немедленно показала прибавку.
func add_extra(count: int) -> void:
	if model.extra_pool.is_empty() or count <= 0:
		return
	for _i in count:
		_pending_extras.append(model.extra_pool[_rng.randi_range(0, model.extra_pool.size() - 1)])
	basket_changed.emit()


## Разыгрывает ли враг способность в текущем раунде: так настроен его ход
## ([member EnemyMove.uses_ability]).
func move_uses_ability() -> bool:
	var move := model.move_for_round(round_number)
	return move != null and move.uses_ability


func advance() -> void:
	round_number += 1
	_has_dropped_this_round = false
	basket_changed.emit()


func _upcoming_round() -> int:
	return round_number + 1 if _has_dropped_this_round else round_number


## Разрешить ход раунда в список выкладок. Результат кэшируется по номеру
## раунда: случайные наборы роллятся один раз, поэтому предпросмотр корзины
## и фактическое высыпание совпадают. Возвращается копия — вызывающий может
## дописывать доп. ингредиенты и усиление, не портя кэш.
func _resolve_move(round_number_to_plan: int) -> Array[SpawnRequest]:
	if _plan_round != round_number_to_plan:
		_plan_cache = _build_move_plan(round_number_to_plan)
		_plan_round = round_number_to_plan
	return _plan_cache.duplicate()


func _build_move_plan(round_number_to_plan: int) -> Array[SpawnRequest]:
	var plan: Array[SpawnRequest] = []
	var move := model.move_for_round(round_number_to_plan)
	if move == null:
		return plan
	# Множитель количества врага: и число копий, и ценность случайного набора.
	var quantity_mult := maxi(model.spawn_count_multiplier, 1)
	for group in move.groups:
		if group == null:
			continue
		if group.random_bad_count > 0:
			for ingredient in _sample_bad(_roll_bad_count(group) * quantity_mult):
				plan.append(SpawnRequest.new(ingredient, group.placement))
		elif group.random_effect_count > 0:
			for ingredient in _sample_with_effect(group.random_effect_count * quantity_mult):
				plan.append(SpawnRequest.new(ingredient, group.placement))
		elif group.random_points > 0:
			for ingredient in _sample_by_points(_roll_target_points(group) * quantity_mult):
				plan.append(SpawnRequest.new(ingredient, group.placement))
		elif group.ingredient != null:
			for _i in maxi(group.count, 0) * quantity_mult:
				plan.append(SpawnRequest.new(group.ingredient, group.placement))
	return plan


## Цель случайного набора группы с учётом разброса
## ([member EnemySpawnGroup.random_points_variance]). Роллится вместе с самим
## набором — то есть один раз на раунд, из-за кэша плана хода.
func _roll_target_points(group: EnemySpawnGroup) -> int:
	var variance := maxi(group.random_points_variance, 0)
	if variance == 0:
		return group.random_points
	return maxi(group.random_points + _rng.randi_range(-variance, variance), 0)


## Сколько штук мусора кладёт группа: число из диапазона
## [member EnemySpawnGroup.random_bad_count]…[member EnemySpawnGroup.random_bad_count_max].
## Роллится вместе с ходом — то есть один раз на раунд, из-за кэша плана.
func _roll_bad_count(group: EnemySpawnGroup) -> int:
	if group.random_bad_count_max > group.random_bad_count:
		return _rng.randi_range(group.random_bad_count, group.random_bad_count_max)
	return group.random_bad_count


## Столько случайных **вредных** ингредиентов (множитель меньше 0). Берутся из
## [member EnemyModel.bad_pool], а если он пуст — из вредных ингредиентов
## инвентаря врага. Штуки роллятся с повторами: одного и того же мусора может
## выпасть сколько угодно. Пустой пул — пустой список, ход просто без мусора.
func _sample_bad(count: int) -> Array[IngredientModel]:
	var result: Array[IngredientModel] = []
	if count <= 0:
		return result
	var pool := _bad_pool()
	if pool.is_empty():
		return result
	for _i in count:
		result.append(pool[_rng.randi_range(0, pool.size() - 1)])
	return result


## Вредные ингредиенты, из которых сэмплятся группы со случайным мусором.
func _bad_pool() -> Array[IngredientModel]:
	var pool: Array[IngredientModel] = []
	for ingredient in model.bad_pool:
		if ingredient != null and ingredient.category() == IngredientModel.Category.NEGATIVE:
			pool.append(ingredient)
	if not pool.is_empty():
		return pool
	for ingredient in model.inventory:
		if ingredient != null and ingredient.category() == IngredientModel.Category.NEGATIVE:
			pool.append(ingredient)
	return pool


## Столько случайных ингредиентов с эффектом ([member IngredientModel.effect]).
## Берутся из [member EnemyModel.effect_pool], а если он пуст — из ингредиентов
## с эффектом в инвентаре врага. Ингредиенты могут повторяться: каждая штука
## роллится отдельно. Пустой пул — пустой список, ход просто без эффектов.
func _sample_with_effect(count: int) -> Array[IngredientModel]:
	var result: Array[IngredientModel] = []
	if count <= 0:
		return result
	var pool := _effect_pool()
	if pool.is_empty():
		return result
	for _i in count:
		result.append(pool[_rng.randi_range(0, pool.size() - 1)])
	return result


## Ингредиенты с эффектом, из которых сэмплятся группы со случайным эффектом.
func _effect_pool() -> Array[IngredientModel]:
	var pool: Array[IngredientModel] = []
	for ingredient in model.effect_pool:
		if ingredient != null and ingredient.effect != IngredientModel.Effect.NONE:
			pool.append(ingredient)
	if not pool.is_empty():
		return pool
	for ingredient in model.inventory:
		if ingredient != null and ingredient.effect != IngredientModel.Effect.NONE:
			pool.append(ingredient)
	return pool


## Случайный набор из инвентаря врага суммарной ценностью примерно на
## target_points очков. Учитываются только ингредиенты с положительной
## ценностью (иначе набор не сойдётся к цели); добор идёт, пока сумма не
## достигнет цели.
func _sample_by_points(target_points: int) -> Array[IngredientModel]:
	var result: Array[IngredientModel] = []
	if target_points <= 0:
		return result
	var pool: Array[IngredientModel] = []
	for ingredient in model.inventory:
		if ingredient != null and ingredient.base_points() > 0.0:
			pool.append(ingredient)
	if pool.is_empty():
		return result
	var total := 0.0
	# Верхний предел на число штук — страховка от вырожденных настроек.
	while total < float(target_points) and result.size() < 64:
		var pick := pool[_rng.randi_range(0, pool.size() - 1)]
		result.append(pick)
		total += pick.base_points()
	return result
