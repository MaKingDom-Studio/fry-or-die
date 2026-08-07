## Награда за выигранный бой: что игроку предлагают забрать с экрана награды
## ([RewardScreen]) и сколько звёзд он за бой получил.
##
## Набор роллится один раз, в момент победы ([method roll]), по правилам
## [RewardConfig]:
##
## [br]— обычный бой: один ингредиент — с шансом
##   [member RewardConfig.positive_chance] положительный, иначе с уникальным
##   эффектом; и с шансом [member RewardConfig.spice_chance] ещё случайная
##   специя из тех, которых у игрока пока нет (мята, если она уже есть,
##   выпасть не может — как и любая другая уже полученная специя: их бонус
##   постоянный и не складывается);
## [br]— минибосс: [member RewardConfig.miniboss_spice] (крутой перец) и
##   орудие самого минибосса ([member EnemyModel.reward_tool]).
##
## Звёзды не выбираются: их ровно столько, сколько нужно было набрать для
## победы над этим врагом ([member EnemyModel.star_target]), и начисляются
## они сразу при открытии экрана награды.
##
## Предметы лежат в [member items] слева направо — ровно в том порядке, в
## каком экран раскладывает их по бумажке (мест там два).
class_name BattleReward
extends RefCounted

## Сколько звёзд принёс бой.
var stars := 0

## Что предлагается забрать, слева направо: [IngredientModel],
## [SpiceModel] или [ToolModel]. Не больше двух — столько мест на бумажке.
var items: Array[Resource] = []


## Разложить награду за победу над врагом. is_miniboss — бой был с минибоссом
## (у минибосса своя награда: крутой перец и его орудие). config — правила
## выпадения; null — награда будет только звёздами.
static func roll(player: Player, enemy: EnemyModel, is_miniboss: bool,
		config: RewardConfig, rng: RandomNumberGenerator = null) -> BattleReward:
	var reward := BattleReward.new()
	reward.stars = enemy.star_target if enemy != null else 0
	if config == null:
		return reward
	var gen := rng if rng != null else RandomNumberGenerator.new()
	if is_miniboss:
		reward._roll_miniboss(player, enemy, config)
	else:
		reward._roll_battle(player, config, gen)
	return reward


## Минибосс отдаёт крутой перец и своё орудие. Инструмент, который у игрока
## уже есть, не предлагается — дубликаты бесполезны (на раунд всё равно
## выбирается один инструмент).
func _roll_miniboss(player: Player, enemy: EnemyModel, config: RewardConfig) -> void:
	if config.miniboss_spice != null:
		items.append(config.miniboss_spice)
	if enemy != null and enemy.reward_tool != null \
			and not player.has_tool(enemy.reward_tool.id):
		items.append(enemy.reward_tool)


## Обычный бой: ингредиент (положительный или с уникальным эффектом) и,
## если повезёт, ещё специя.
func _roll_battle(player: Player, config: RewardConfig,
		rng: RandomNumberGenerator) -> void:
	var positive := rng.randf() < config.positive_chance
	var ingredient := _pick_ingredient(config, positive, rng)
	if ingredient != null:
		items.append(ingredient)
	if rng.randf() < config.spice_chance:
		var spice := _pick_spice(player, config, rng)
		if spice != null:
			items.append(spice)


## Ингредиент награды: из пула положительных или из пула с уникальными
## эффектами. Если нужного пула нет, берётся второй — ингредиент за бой
## игрок получает всегда.
func _pick_ingredient(config: RewardConfig, positive: bool,
		rng: RandomNumberGenerator) -> IngredientModel:
	var first := config.positive_pool if positive else config.effect_pool
	var second := config.effect_pool if positive else config.positive_pool
	var pool := first if not first.is_empty() else second
	if pool.is_empty():
		push_warning("Пулы ингредиентов награды пусты — за бой ничего не выпадет.")
		return null
	return pool[rng.randi_range(0, pool.size() - 1)]


## Специя награды: случайная из тех, которых у игрока ещё нет. Все специи
## уже собраны — специя не выпадает.
func _pick_spice(player: Player, config: RewardConfig,
		rng: RandomNumberGenerator) -> SpiceModel:
	var candidates: Array[SpiceModel] = []
	for spice in config.spice_pool:
		if spice != null and not player.has_spice(spice.id):
			candidates.append(spice)
	if candidates.is_empty():
		return null
	return candidates[rng.randi_range(0, candidates.size() - 1)]


## Отдать забранный предмет игроку: ингредиент — в мешок, специя — в набор
## специй, инструмент — в сумку инструментов. Полку специй экран награды
## наполняет отдельно ([method SpiceShelf.drop_in]) — здесь только модель.
static func give(player: Player, item: Resource) -> void:
	var ingredient := item as IngredientModel
	if ingredient != null:
		player.add_ingredient(ingredient)
		return
	var spice := item as SpiceModel
	if spice != null:
		player.add_spice(spice)
		return
	var tool_model := item as ToolModel
	if tool_model != null:
		player.add_tool(tool_model)
