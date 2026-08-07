## Витрина магазина — аналог MerchantInventory из референса.
##
## Наполняет девять позиций из пулов [ShopConfig]:
## - 3 позиции — большие и средние ингредиенты. Выбор взвешенный по
##   [member IngredientModel.shop_weight]; каждый выпавший средний
##   повышает шанс больших в следующих бросках (см.
##   [member ShopConfig.large_weight_bonus_per_medium]);
## - 3 позиции — средние и маленькие ингредиенты, минимум один товар
##   с эффектом ([member IngredientModel.effect]);
## - 3 позиции — специи без повторов; вес специй, которые уже есть у
##   игрока, понижается ([member ShopConfig.owned_spice_weight_multiplier]).
##
## Цены и веса задаются в конфиге самого товара (.tres ингредиента или
## специи), пулы и правила генерации — в da_shop.tres.
class_name ShopInventory
extends RefCounted

var player: Player
var config: ShopConfig

## Позиции 1–3: большие и средние ингредиенты.
var large_medium_entries: Array[ShopEntry] = []
## Позиции 4–6: средние и маленькие ингредиенты (минимум один с эффектом).
var small_medium_entries: Array[ShopEntry] = []
## Позиции 7–9: специи.
var spice_entries: Array[ShopEntry] = []


static func create(owner: Player, shop_config: ShopConfig,
		rng: RandomNumberGenerator) -> ShopInventory:
	var inventory := ShopInventory.new()
	inventory.player = owner
	inventory.config = shop_config
	inventory._populate_large_medium(rng)
	inventory._populate_small_medium(rng)
	inventory._populate_spices(rng)
	return inventory


## Все девять позиций по порядку витрины.
func all_entries() -> Array[ShopEntry]:
	var result: Array[ShopEntry] = []
	result.append_array(large_medium_entries)
	result.append_array(small_medium_entries)
	result.append_array(spice_entries)
	return result


## Большие и средние: взвешенный бросок с «жалостью» — каждый выпавший
## средний умножает вес больших на (1 + бонус * число средних), поэтому
## чем больше средних уже выпало, тем вероятнее большой ингредиент.
func _populate_large_medium(rng: RandomNumberGenerator) -> void:
	var pool := _ingredients_of_sizes([IngredientModel.Size.LARGE, IngredientModel.Size.MEDIUM])
	var medium_rolled := 0
	for _slot in config.slots_per_row:
		if pool.is_empty():
			break
		var weights: Array[float] = []
		for model in pool:
			var weight := maxf(model.shop_weight, 0.0)
			if model.size == IngredientModel.Size.LARGE:
				weight *= 1.0 + config.large_weight_bonus_per_medium * medium_rolled
			weights.append(weight)
		var picked: IngredientModel = _weighted_pick(pool, weights, rng)
		if picked == null:
			break
		if picked.size == IngredientModel.Size.MEDIUM:
			medium_rolled += 1
		large_medium_entries.append(ShopEntry.for_ingredient(player, picked))


## Средние и маленькие: взвешенный бросок; если среди трёх позиций не
## оказалось товара с эффектом — последняя перебрасывается из товаров
## с эффектом (гарантия «минимум один с эффектом»).
func _populate_small_medium(rng: RandomNumberGenerator) -> void:
	var pool := _ingredients_of_sizes([IngredientModel.Size.MEDIUM, IngredientModel.Size.SMALL])
	for _slot in config.slots_per_row:
		if pool.is_empty():
			break
		var picked: IngredientModel = _weighted_pick(pool, _plain_weights(pool), rng)
		if picked == null:
			break
		small_medium_entries.append(ShopEntry.for_ingredient(player, picked))
	if not config.require_effect_item or small_medium_entries.is_empty():
		return
	for entry in small_medium_entries:
		if entry.ingredient.effect != IngredientModel.Effect.NONE:
			return
	var effect_pool: Array[IngredientModel] = []
	for model in pool:
		if model.effect != IngredientModel.Effect.NONE:
			effect_pool.append(model)
	var replacement: IngredientModel = _weighted_pick(effect_pool, _plain_weights(effect_pool), rng)
	if replacement != null:
		small_medium_entries[small_medium_entries.size() - 1] = \
				ShopEntry.for_ingredient(player, replacement)


## Специи: взвешенный бросок без повторов; вес специй, которые уже есть
## у игрока, умножается на owned_spice_weight_multiplier (0.75 — «на 25%
## ниже»).
func _populate_spices(rng: RandomNumberGenerator) -> void:
	var pool: Array[SpiceModel] = []
	for spice in config.spice_pool:
		if spice != null:
			pool.append(spice)
	for _slot in config.slots_per_row:
		if pool.is_empty():
			break
		var weights: Array[float] = []
		for spice in pool:
			var weight := maxf(spice.shop_weight, 0.0)
			if player.has_spice(spice.id):
				weight *= config.owned_spice_weight_multiplier
			weights.append(weight)
		var picked: SpiceModel = _weighted_pick(pool, weights, rng)
		if picked == null:
			break
		spice_entries.append(ShopEntry.for_spice(player, picked))
		pool.erase(picked)


func _ingredients_of_sizes(sizes: Array) -> Array[IngredientModel]:
	var result: Array[IngredientModel] = []
	for model in config.ingredient_pool:
		if model != null and sizes.has(model.size):
			result.append(model)
	return result


func _plain_weights(pool: Array[IngredientModel]) -> Array[float]:
	var weights: Array[float] = []
	for model in pool:
		weights.append(maxf(model.shop_weight, 0.0))
	return weights


## Взвешенный выбор из пула; при нулевой сумме весов — null.
func _weighted_pick(pool: Array, weights: Array[float], rng: RandomNumberGenerator):
	var total := 0.0
	for weight in weights:
		total += weight
	if total <= 0.0 or pool.is_empty():
		return null
	var roll := rng.randf_range(0.0, total)
	for i in pool.size():
		roll -= weights[i]
		if roll <= 0.0:
			return pool[i]
	return pool[pool.size() - 1]
