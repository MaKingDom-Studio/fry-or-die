## Главное меню — первый экран игры (`_Game/UI/Screens/main_menu.tscn`).
##
## Собрано по макету `_Game/Art/Main_Menu/Main_Menu_Layout.png`: тёмный фон,
## название игры из отдельных букв ([MenuTitleLetter] — каждая дребезжит сама
## по себе), огонь с дымом поверх букв, повар, стоящий на кнопке «PLAY»
## ([MenuPlayButton]), и сковорода-крутилка громкости ([VolumeKnob])
## в левом нижнем углу.
##
## Все узлы расставлены в координатах макета ([member design_size],
## 1920×1080), а под окно подгоняются целыми слоями — так меню держит
## композицию макета на любом экране:
##
## - `Backdrop` (фон) и `Flames` (огонь) — «с покрытием»: масштаб по большей
##   стороне, лишнее уходит за края. Это рисунок, ему и положено упираться
##   в края экрана;
## - `Title` (название) и `Stage` (кнопка с поваром) — «по вписыванию»:
##   масштаб по меньшей стороне, поэтому ни буква, ни кнопка не обрежутся
##   даже на узком экране;
## - `Sound` (крутилка громкости) — сам узел прибит к левому нижнему углу
##   окна, а отступ крутилки от угла лежит в её позиции внутри `Sound`
##   (по макету — 274 вправо и 190 вверх), поэтому до звука дотянешься
##   на любом экране.
##
## На экране 16:9 оба масштаба совпадают, и меню собирается ровно по макету.
##
## Кнопка «PLAY» уводит на карту забега (`l_map.tscn`) тем же переходом
## кляксой ([SceneTransition]), что и остальные локации; сам забег карта
## начинает при входе.
class_name MainMenuScreen
extends Node2D

## Куда ведёт кнопка «PLAY»: карта забега.
const MAP_SCENE := "res://_Game/Maps/l_map.tscn"

## Размер макета: в этих координатах расставлены узлы меню.
@export var design_size := Vector2(1920.0, 1080.0)

var _backdrop: Node2D
var _title: Node2D
var _flames: Node2D
var _stage: Node2D
var _sound: Node2D
var _play: MenuPlayButton
var _transition: SceneTransition
## Уже уходим на карту — второй клик по кнопке ничего не делает.
var _leaving := false


func _ready() -> void:
	_backdrop = get_node_or_null("Backdrop") as Node2D
	_title = get_node_or_null("Title") as Node2D
	_flames = get_node_or_null("Flames") as Node2D
	_stage = get_node_or_null("Stage") as Node2D
	_sound = get_node_or_null("Sound") as Node2D
	_play = get_node_or_null("Stage/PlayButton") as MenuPlayButton
	_transition = get_node_or_null("SceneTransition") as SceneTransition
	_layout()
	get_viewport().size_changed.connect(_layout)
	# Музыка меню — она же музыка карты забега, поэтому переход туда её
	# не сбивает ([AudioDirector]).
	Audio.stop_all_loops()
	Audio.play_music(AudioDirector.MUSIC_MENU)
	if _play != null:
		_play.pressed.connect(_start_game)
	if _transition != null:
		_transition.play_in()


## Разложить слои меню по окну.
func _layout() -> void:
	if design_size.x <= 0.0 or design_size.y <= 0.0:
		return
	var view := get_viewport_rect().size
	# Рисунок — с покрытием, живые элементы — по вписыванию.
	var cover := maxf(view.x / design_size.x, view.y / design_size.y)
	var fit := minf(view.x / design_size.x, view.y / design_size.y)
	_place(_backdrop, cover, view)
	_place(_title, fit, view)
	_place(_flames, cover, view)
	_place(_stage, fit, view)
	if _sound != null:
		_sound.scale = Vector2(fit, fit)
		_sound.position = Vector2(0.0, view.y)


## Поставить слой по центру окна в выбранном масштабе.
func _place(layer: Node2D, factor: float, view: Vector2) -> void:
	if layer == null:
		return
	layer.scale = Vector2(factor, factor)
	layer.position = (view - design_size * factor) * 0.5


func _start_game() -> void:
	if _leaving:
		return
	_leaving = true
	Audio.play(AudioDirector.CLICK)
	if _transition != null:
		await _transition.play_out()
	get_tree().change_scene_to_file.call_deferred(MAP_SCENE)
