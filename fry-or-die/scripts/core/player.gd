## Состояние игрока на весь забег.
##
## Здесь живёт всё, что переживает бой: ингредиенты (аналог колоды),
## инструменты с кулдаунами и специи. Состояние конкретного боя — в
## [PlayerRoundState], пересоздаваемом на каждый бой; шкалу звёзд боя
## ([StarProgress]) создаёт режим боя.
class_name Player
extends RefCounted

signal ingredient_added(ingredient: IngredientModel)
signal ingredient_removed(ingredient: IngredientModel)
signal tool_added(tool_state: ToolState)
signal tool_removed(tool_state: ToolState)
signal spice_added(spice: SpiceModel)
signal spice_removed(spice: SpiceModel)
signal stars_changed(stars: int)

## За кого играет игрок.
var character: CharacterModel

## Настройки баланса (кулдауны инструментов, размер корзины и т.п.).
var config: GameConfig

## Все ингредиенты забега. В начале боя из них наполняется мешочек ([IngredientBag]).
var ingredients: Array[IngredientModel] = []

## Инструменты игрока. Не пропадают при использовании — только уходят в кулдаун.
var tools: Array[ToolState] = []

## Специи: постоянные бонусы, работают всё время, пока есть у игрока.
var spices: Array[SpiceModel] = []

## Звёзды — валюта забега (покупки в магазине).
var stars := 0

## Состояние текущего боя; null вне боя.
var round_state: PlayerRoundState = null


## Создать игрока для нового забега со стартовым инвентарём из модели персонажа.
## rng — генератор для случайного стартового набора (см.
## [member CharacterModel.starting_ingredient_pool]); null — свой генератор.
static func create_for_new_run(character_model: CharacterModel, game_config: GameConfig = null,
		rng: RandomNumberGenerator = null) -> Player:
	var new_player := Player.new()
	new_player.character = character_model
	new_player.config = game_config if game_config != null else GameConfig.new()
	for ingredient in character_model.starting_ingredients:
		new_player.add_ingredient(ingredient)
	new_player._add_random_starting_ingredients(character_model, rng)
	new_player._add_random_positive_ingredients(character_model, rng)
	for tool_model in character_model.starting_tools:
		new_player.add_tool(tool_model)
	new_player._add_random_tools(character_model, rng)
	for spice in character_model.starting_spices:
		new_player.add_spice(spice)
	new_player._add_random_spices(character_model, rng)
	return new_player


## Набрать случайные стартовые ингредиенты из пула персонажа (с повторами),
## по размерам: сколько маленьких / средних / больших.
func _add_random_starting_ingredients(character_model: CharacterModel,
		rng: RandomNumberGenerator) -> void:
	var pool := character_model.starting_ingredient_pool
	if pool.is_empty():
		return
	var gen := rng if rng != null else RandomNumberGenerator.new()
	_draw_random_by_size(pool, IngredientModel.Size.SMALL, character_model.random_small_count, gen)
	_draw_random_by_size(pool, IngredientModel.Size.MEDIUM, character_model.random_medium_count, gen)
	_draw_random_by_size(pool, IngredientModel.Size.LARGE, character_model.random_large_count, gen)


## Добрать случайные положительные ингредиенты (с повторами) из отдельного
## пула персонажа — размер здесь не важен, важна только категория.
func _add_random_positive_ingredients(character_model: CharacterModel,
		rng: RandomNumberGenerator) -> void:
	if character_model.random_positive_count <= 0:
		return
	var candidates: Array[IngredientModel] = []
	for ingredient in character_model.random_positive_pool:
		if ingredient != null and ingredient.category() == IngredientModel.Category.POSITIVE:
			candidates.append(ingredient)
	if candidates.is_empty():
		push_warning("Нет положительных ингредиентов в пуле персонажа.")
		return
	var gen := rng if rng != null else RandomNumberGenerator.new()
	for _i in character_model.random_positive_count:
		add_ingredient(candidates[gen.randi_range(0, candidates.size() - 1)])


## Выдать случайные инструменты из пула персонажа — без повторов: на раунд
## всё равно выбирается один инструмент, поэтому второй такой же бесполезен.
func _add_random_tools(character_model: CharacterModel,
		rng: RandomNumberGenerator) -> void:
	if character_model.random_tool_count <= 0:
		return
	var candidates: Array[ToolModel] = []
	for tool_model in character_model.random_tool_pool:
		if tool_model != null and not has_tool(tool_model.id):
			candidates.append(tool_model)
	if candidates.is_empty():
		push_warning("Нет инструментов в пуле персонажа.")
		return
	var gen := rng if rng != null else RandomNumberGenerator.new()
	for _i in character_model.random_tool_count:
		if candidates.is_empty():
			return
		var index := gen.randi_range(0, candidates.size() - 1)
		add_tool(candidates[index])
		candidates.remove_at(index)


## Выдать случайные специи из пула персонажа — без повторов: одна и та же
## специя не выдаётся дважды, потому что её бонус постоянный и не складывается.
func _add_random_spices(character_model: CharacterModel,
		rng: RandomNumberGenerator) -> void:
	if character_model.random_spice_count <= 0:
		return
	var candidates: Array[SpiceModel] = []
	for spice in character_model.random_spice_pool:
		if spice != null and not has_spice(spice.id):
			candidates.append(spice)
	if candidates.is_empty():
		push_warning("Нет специй в пуле персонажа.")
		return
	var gen := rng if rng != null else RandomNumberGenerator.new()
	for _i in character_model.random_spice_count:
		if candidates.is_empty():
			return
		var index := gen.randi_range(0, candidates.size() - 1)
		add_spice(candidates[index])
		candidates.remove_at(index)


## Добрать count случайных ингредиентов заданного размера из пула (с повторами).
## Берутся только мягкие ингредиенты ([method IngredientModel.is_mild]) —
## множитель больше 0 и меньше 2: забег начинается с ровного набора, а всё
## сильное игрок добирает наградами за бои и покупками.
func _draw_random_by_size(pool: Array[IngredientModel], size: IngredientModel.Size,
		count: int, rng: RandomNumberGenerator) -> void:
	if count <= 0:
		return
	var candidates: Array[IngredientModel] = []
	for ingredient in pool:
		if ingredient != null and ingredient.size == size and ingredient.is_mild():
			candidates.append(ingredient)
	if candidates.is_empty():
		push_warning("Нет мягких ингредиентов размера %d в стартовом пуле." % size)
		return
	for _i in count:
		add_ingredient(candidates[rng.randi_range(0, candidates.size() - 1)])


## Инструмент, активный в текущем раунде; null вне боя или если не выбран.
func get_active_tool() -> ToolState:
	return round_state.active_tool if round_state != null else null


# --- Инвентарь (пополняется у торговцев) ---

func add_ingredient(ingredient: IngredientModel) -> void:
	ingredients.append(ingredient)
	ingredient_added.emit(ingredient)


func remove_ingredient(ingredient: IngredientModel) -> bool:
	if not ingredients.has(ingredient):
		return false
	ingredients.erase(ingredient)
	ingredient_removed.emit(ingredient)
	return true


func add_tool(tool_model: ToolModel) -> ToolState:
	var tool_state := ToolState.new(tool_model)
	tools.append(tool_state)
	tool_added.emit(tool_state)
	return tool_state


func remove_tool(tool_state: ToolState) -> bool:
	if not tools.has(tool_state):
		return false
	tools.erase(tool_state)
	tool_removed.emit(tool_state)
	return true


func add_spice(spice: SpiceModel) -> void:
	spices.append(spice)
	spice.on_obtained(self)
	spice_added.emit(spice)


func remove_spice(spice: SpiceModel) -> bool:
	if not spices.has(spice):
		return false
	spices.erase(spice)
	spice.on_removed(self)
	spice_removed.emit(spice)
	return true


func add_stars(amount: int) -> void:
	if amount <= 0:
		return
	stars += amount
	stars_changed.emit(stars)


## Списать звёзды; false — если их не хватает (баланс не меняется).
func spend_stars(amount: int) -> bool:
	if amount < 0 or amount > stars:
		return false
	stars -= amount
	stars_changed.emit(stars)
	return true


## Есть ли у игрока инструмент с таким id (в любом состоянии кулдауна).
func has_tool(tool_id: StringName) -> bool:
	for tool_state in tools:
		if tool_state.model != null and tool_state.model.id == tool_id:
			return true
	return false


func has_spice(spice_id: StringName) -> bool:
	for spice in spices:
		if spice.id == spice_id:
			return true
	return false


## Инструменты, готовые к выбору (не на кулдауне).
func get_ready_tools() -> Array[ToolState]:
	var ready: Array[ToolState] = []
	for tool_state in tools:
		if tool_state.is_ready():
			ready.append(tool_state)
	return ready


# --- Бой ---

## Начать бой: создаёт свежее пер-бойное состояние
## (мешочек наполняется всеми ингредиентами, корзина — первым набором).
func start_combat(rng: RandomNumberGenerator = null) -> PlayerRoundState:
	round_state = PlayerRoundState.new(self, config, rng)
	return round_state


## Завершить бой и очистить пер-бойное состояние.
func end_combat() -> void:
	if round_state == null:
		return
	round_state.end_combat()
	round_state = null
