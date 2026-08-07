## Товар магазина — аналог MerchantEntry из референса.
##
## Одна запись витрины: ингредиент ИЛИ специя, цена в звёздах и флаг
## «продано». Логика покупки живёт здесь (данные), узлы сцены
## ([ShopItemNode], [PriceTag]) только отображают запись и подписываются
## на её события — источником истины остаётся сущность.
class_name ShopEntry
extends RefCounted

## Покупка прошла: звёзды списаны, товар у игрока, слот опустел.
signal purchase_completed
## Покупка не прошла (не хватает звёзд).
signal purchase_failed

var player: Player
var ingredient: IngredientModel = null
var spice: SpiceModel = null
## Итоговая цена в звёздах (из конфига товара: [member IngredientModel.price]
## или [member SpiceModel.price]).
var price := 0
var sold := false


static func for_ingredient(owner: Player, model: IngredientModel) -> ShopEntry:
	var entry := ShopEntry.new()
	entry.player = owner
	entry.ingredient = model
	entry.price = model.price
	return entry


static func for_spice(owner: Player, model: SpiceModel) -> ShopEntry:
	var entry := ShopEntry.new()
	entry.player = owner
	entry.spice = model
	entry.price = model.price
	return entry


func display_name() -> String:
	if ingredient != null:
		return ingredient.display_name
	if spice != null:
		return spice.display_name
	return ""


func is_spice() -> bool:
	return spice != null


## Хватает ли игроку звёзд на этот товар.
func can_afford() -> bool:
	return player != null and player.stars >= price


## Есть ли товар в наличии.
func is_stocked() -> bool:
	return not sold and (ingredient != null or spice != null)


## Единая точка входа покупки — аналог OnTryPurchaseWrapper: проверки
## наличия и звёзд, списание, выдача товара игроку, события.
func try_purchase() -> bool:
	if not is_stocked():
		purchase_failed.emit()
		return false
	if not player.spend_stars(price):
		purchase_failed.emit()
		return false
	if ingredient != null:
		player.add_ingredient(ingredient)
	elif spice != null:
		player.add_spice(spice)
	sold = true
	purchase_completed.emit()
	return true
