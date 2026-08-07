## Содержимое подсказки при наведении: что о предмете написать.
##
## Собирается из модели предмета — ингредиента ([IngredientModel]), специи
## ([SpiceModel]) или инструмента ([ToolModel]) — методом [method for_model],
## поэтому все подсказки в игре пишутся по одним и тем же правилам:
## [br]— заголовок — название предмета;
## [br]— строка описания: у специй и инструментов — их описание, у
##   ингредиентов с эффектом — что этот эффект делает;
## [br]— у ингредиентов без эффекта вместо описания идёт доля звезды, которую
##   ингредиент приносит при подсчёте: сначала звёздочка, затем значение
##   («0.2», «-0.25»).
##
## Тексты — на английском: игра англоязычная.
class_name TooltipContent
extends RefCounted

## Название предмета.
var title := ""
## Строка под названием: описание или эффект. Пусто — строки нет.
var body := ""
## Доля звезды со звёздочкой перед ней («0.2»). Пусто — строки нет.
var star_value := ""


## Подсказка по модели предмета. points_per_star — цена звезды
## ([member CombatConfig.points_per_star]), нужна ингредиентам без эффекта.
## null — подсказки для этой модели нет.
static func for_model(model: Resource, points_per_star := 10.0) -> TooltipContent:
	var ingredient := model as IngredientModel
	if ingredient != null:
		return for_ingredient(ingredient, points_per_star)
	var spice := model as SpiceModel
	if spice != null:
		return for_spice(spice)
	var tool_model := model as ToolModel
	if tool_model != null:
		return for_tool(tool_model)
	return null


## Ингредиент: с эффектом — что эффект делает, без эффекта — доля звезды.
static func for_ingredient(model: IngredientModel, points_per_star := 10.0) -> TooltipContent:
	var content := TooltipContent.new()
	content.title = model.display_name
	var effect := effect_text(model)
	if effect != "":
		content.body = effect
	else:
		content.star_value = star_fraction_text(model.base_points(), points_per_star)
	return content


static func for_spice(model: SpiceModel) -> TooltipContent:
	var content := TooltipContent.new()
	content.title = model.display_name
	content.body = model.description
	return content


static func for_tool(model: ToolModel) -> TooltipContent:
	var content := TooltipContent.new()
	content.title = model.display_name
	content.body = model.description
	return content


## Что делает уникальный эффект ингредиента; пусто — эффекта нет.
static func effect_text(model: IngredientModel) -> String:
	match model.effect:
		IngredientModel.Effect.EXTRA_INGREDIENTS:
			return "+%d ingredients in the basket next round" % model.effect_amount
		IngredientModel.Effect.EXTRA_TIME:
			return "+%d sec to the next round timer" % model.effect_amount
		IngredientModel.Effect.STICKY:
			return "Sticks to the first table wall it hits, then glues everything that touches it"
		IngredientModel.Effect.GRAYSCALE:
			return "Left on your field: the next round goes black and white"
	return ""


## Доля звезды: очки, поделённые на цену звезды. Не больше двух знаков после
## запятой, лишние нули срезаются: «0.5», «0.25», «-0.15», «1».
static func star_fraction_text(points: float, points_per_star: float) -> String:
	var fraction := points / points_per_star if points_per_star > 0.0 else 0.0
	var text := "%.2f" % fraction
	if text.contains("."):
		text = text.rstrip("0").rstrip(".")
	return "0" if text == "" or text == "-0" else text
