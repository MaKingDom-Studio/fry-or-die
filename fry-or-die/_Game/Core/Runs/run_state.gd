## Состояние забега между сценами: игрок, карта и текущая точка карты.
##
## Автозагрузка (синглтон `Run` в project.godot) — она живёт дольше сцен,
## поэтому переносит через смену локации то, что бой и магазин сами
## передать не могут: инвентарь игрока, звёзды, пройденные точки карты.
##
## Цикл забега:
## [codeblock]
## l_map.tscn   — карта: игрок кликает по доступной точке
##   → travel_to(node)
##       точка боя      → l_combat.tscn (враг точки, игрок забега)
##       точка магазина → l_shop.tscn   (звёзды и мешок забега)
##   → report_combat(won) — бой; из магазина возврат идёт сам собой
##   → return_to_map() — обратно на карту, точка помечена пройденной
## [/codeblock]
##
## Забег заканчивается победой над боссом или первым поражением; в обоих
## случаях [method return_to_map] сбрасывает состояние, и карта на входе
## сгенерирует новый забег.
##
## Пока забег не начат ([method is_active] == false), бой и магазин
## работают как раньше — сами по себе, со своим игроком из экспортов
## сцены. Так l_combat.tscn и l_shop.tscn по-прежнему можно запускать
## из редактора по отдельности.
class_name RunManager
extends Node

const MAP_SCENE := "res://_Game/Maps/l_map.tscn"
const COMBAT_SCENE := "res://_Game/Maps/l_combat.tscn"
const SHOP_SCENE := "res://_Game/Maps/l_shop.tscn"

## Забег начался.
signal run_started
## Точка карты пройдена (бой выигран или магазин покинут).
signal node_cleared(node: MapNode)
## Забег кончился: won — босс побеждён, иначе поражение.
signal run_ended(won: bool)

## Игрок забега: инвентарь, инструменты, специи и звёзды переживают бои.
var player: Player
## Карта текущего акта.
var map: ActMap
## Наполнение карты: кто стоит на точках и как они расставлены.
var map_config: ActMapConfig
## Настройки боя, с которыми создан игрок.
var combat_config: CombatConfig
## За кого идёт забег.
var character: CharacterModel

## Пройденные точки в порядке прохождения: по этому списку карта собирает
## стопку листков на игле — номер листка это его место в списке.
var cleared_order: Array[MapNode] = []
## Точка, чей листок ещё не наколот на иглу. Карта, увидев её, проигрывает
## связку «листок падает вниз → другой влетает справа → накалывается →
## съезжает на своё место» и обнуляет поле.
var pending_spike: MapNode = null

var _rng := RandomNumberGenerator.new()
## Последний бой проигран — забег кончится по возвращении на карту.
var _failed := false
## Босс побеждён.
var _completed := false


## Начать новый забег: свежий игрок и свежая карта.
func start_run(character_model: CharacterModel, game_config: CombatConfig,
		act_config: ActMapConfig) -> void:
	_rng.randomize()
	character = character_model
	combat_config = game_config if game_config != null else CombatConfig.new()
	map_config = act_config if act_config != null else ActMapConfig.new()
	player = Player.create_for_new_run(character_model, combat_config, _rng)
	map = ActMap.generate(map_config, _rng)
	cleared_order.clear()
	pending_spike = null
	_failed = false
	_completed = false
	run_started.emit()


## Идёт ли забег прямо сейчас.
func is_active() -> bool:
	return map != null and player != null


## Точка, на которой игрок стоит; null вне забега.
func current_node() -> MapNode:
	return map.current if is_active() else null


## Враг текущей точки; null вне забега или в магазине.
func current_enemy() -> EnemyModel:
	var node := current_node()
	return node.enemy if node != null else null


## Шагнуть в точку карты и загрузить её локацию. false — туда хода нет.
##
## Шаг с магазина дальше и помечает магазин пройденным: пока игрок стоял на
## нём, туда можно было вернуться ([method MapNode.is_revisitable]), а теперь
## его листок едет на иглу. Шаг в тот же магазин — это возврат за покупками,
## и точка остаётся непройденной.
func travel_to(node: MapNode) -> bool:
	if not is_active():
		return false
	var from := current_node()
	if not map.enter(node):
		return false
	if from != null and from != node and from.kind == MapNode.Kind.SHOP:
		_clear(from)
	_load_scene(COMBAT_SCENE if node.is_combat() else SHOP_SCENE)
	return true


## Итог боя: победа помечает точку пройденной, поражение заканчивает забег.
## Экран победы и награду за бой показывает сам бой — сюда он только
## сообщает результат; звёзды тоже начисляет он ([BattleReward]).
func report_combat(won: bool) -> void:
	var node := current_node()
	if node == null:
		return
	if not won:
		_failed = true
		return
	_clear(node)
	if node.kind == MapNode.Kind.BOSS:
		_completed = true


## Витрина магазина, в котором игрок сейчас стоит. Собирается один раз и
## дальше живёт в самой точке карты ([member MapNode.shop]), поэтому,
## вернувшись в тот же магазин, игрок застаёт тот же товар — новый не
## роллится, а купленное так и остаётся проданным.
func shop_inventory(shop_config: ShopConfig, rng: RandomNumberGenerator) -> ShopInventory:
	var node := current_node()
	if node == null:
		return ShopInventory.create(player, shop_config, rng)
	if node.shop == null:
		node.shop = ShopInventory.create(player, shop_config, rng)
	return node.shop


## Вернуться на карту. Если забег кончился (босс побеждён или бой
## проигран), состояние сбрасывается — карта сгенерирует новый забег.
func return_to_map() -> void:
	if _failed or _completed:
		var won := _completed
		end_run()
		run_ended.emit(won)
	_load_scene(MAP_SCENE)


## Забыть забег: следующий вход на карту начнёт новый.
func end_run() -> void:
	if player != null:
		player.end_combat()
	player = null
	map = null
	cleared_order.clear()
	pending_spike = null
	_failed = false
	_completed = false


func _clear(node: MapNode) -> void:
	if node.cleared:
		return
	node.cleared = true
	# Листок этой точки поедет на иглу — карта покажет это анимацией,
	# когда игрок на неё вернётся.
	cleared_order.append(node)
	pending_spike = node
	node_cleared.emit(node)


func _load_scene(path: String) -> void:
	get_tree().change_scene_to_file.call_deferred(path)
