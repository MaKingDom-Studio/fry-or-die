## Модель играбельного персонажа: стартовый инвентарь.
##
## Аналог CharacterModel из референса: игрок создаётся из этой модели
## через [method Player.create_for_new_run].
class_name CharacterModel
extends Resource

@export var id: StringName
@export var display_name := ""
## Внешность в HUD боя (портрет-текстура или рисованный повар).
@export var portrait: PortraitStyle

## Фиксированные стартовые ингредиенты (аналог стартовой колоды).
@export var starting_ingredients: Array[IngredientModel] = []

## Стартовые инструменты.
@export var starting_tools: Array[ToolModel] = []

## Стартовые специи (аналог стартовой реликвии).
@export var starting_spices: Array[SpiceModel] = []

@export_group("Случайный стартовый набор")
## Пул кандидатов, из которого набирается стартовый инвентарь (с повторами) —
## в дополнение к [member starting_ingredients]. Ингредиенты берутся нужного
## размера ([enum IngredientModel.Size]) по счётчикам ниже.
@export var starting_ingredient_pool: Array[IngredientModel] = []
## Сколько случайных маленьких ингредиентов набрать из пула.
@export var random_small_count := 0
## Сколько случайных средних ингредиентов набрать из пула.
@export var random_medium_count := 0
## Сколько случайных больших ингредиентов набрать из пула.
@export var random_large_count := 0

@export_group("Случайные положительные")
## Пул положительных ингредиентов (категория [constant
## IngredientModel.Category.POSITIVE], то есть множитель больше 1), из которого
## игрок получает в инвентарь [member random_positive_count] штук с повторами.
## Отдельно от [member starting_ingredient_pool]: размер здесь не важен.
@export var random_positive_pool: Array[IngredientModel] = []
## Сколько случайных положительных ингредиентов выдать из пула выше.
@export var random_positive_count := 0

@export_group("Случайные инструменты")
## Пул инструментов, из которого игрок получает [member random_tool_count] штук —
## в дополнение к [member starting_tools].
@export var random_tool_pool: Array[ToolModel] = []
## Сколько случайных инструментов выдать из пула выше. Без повторов: один и
## тот же инструмент дважды не выдаётся (второй такой же всё равно нечем
## занять — выбирается один инструмент на раунд).
@export var random_tool_count := 0

@export_group("Случайные специи")
## Пул специй, из которого игрок получает [member random_spice_count] штук —
## в дополнение к [member starting_spices].
@export var random_spice_pool: Array[SpiceModel] = []
## Сколько случайных специй выдать из пула выше. Без повторов: одна и та же
## специя дважды не выдаётся (её бонус всё равно постоянный).
@export var random_spice_count := 0
