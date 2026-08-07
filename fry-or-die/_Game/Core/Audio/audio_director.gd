## Весь звук игры в одном месте: музыка локаций, фоновые петли и разовые
## эффекты.
##
## Автозагрузка (синглтон `Audio` в project.godot) — она живёт дольше сцен,
## поэтому музыка не обрывается на смене локации, а проигрыватели эффектов
## не создаются заново в каждом бою.
##
## Звуки зовутся по именам-константам, а не по путям: [constant CLICK],
## [constant BLOCK], [constant MUSIC_COMBAT] и т.д. Что за файл стоит за
## именем и насколько он тише остальных — написано здесь ([constant _LIBRARY]
## и [constant _LEVELS]), поэтому подменить или подкрутить звук можно
## в одном месте, не трогая игровые сцены.
##
## Три вида звука живут по-разному:
##
## - разовые эффекты ([method play]) — щелчок кнопки, склянка специи,
##   победа. Их несколько голосов ([constant SFX_VOICES]), они идут по
##   кругу, поэтому эффекты накладываются друг на друга и не глотаются;
## - петли ([method start_loop], [method stop_loop]) — то, что тянется,
##   пока идёт сцена или фаза: тиканье таймера, гомон супермаркета. Петля
##   заводится один раз и дальше только пускается и останавливается;
## - музыка ([method play_music]) — одна на всю игру. Повторный запрос того
##   же трека ничего не делает (меню и карта играют один и тот же —
##   переход между ними музыку не сбивает), а другой трек сменяет текущий
##   через затухание.
##
## Локация, входя, зовёт [method stop_all_loops] — так ни одна петля не
## переезжает за ней в следующую сцену.
##
## Громкость ([method set_volume]) правит шину Master, переживает
## перезапуск игры (`user://settings.cfg`) и читается на старте — крутилка
## громкости главного меню ([VolumeKnob]) только показывает и меняет её.
class_name AudioDirector
extends Node

## Громкость поменялась (0 — тишина, 1 — полный звук).
signal volume_changed(volume: float)

const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "audio"
const SETTINGS_KEY := "volume"

## Громкость при первом запуске, пока настройка не сохранена.
const DEFAULT_VOLUME := 0.35

const MASTER_BUS := &"Master"
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"

## Сколько разовых эффектов может звучать одновременно.
const SFX_VOICES := 12

## За сколько секунд одна музыка сменяет другую.
const MUSIC_FADE := 0.9

## Громкость затихшей музыки на время смены трека, дБ.
const MUSIC_SILENCE_DB := -40.0

# --- Разовые эффекты ---

## Нажатие на любую кнопку.
const CLICK := &"click"
## Клик по тому, что трогать нельзя.
const BLOCK := &"block"
## Склянка специи.
const SPICE := &"spice"
## Победа в бою.
const VICTORY := &"victory"
## Чек после победы — идёт следом за [constant VICTORY].
const CASH := &"cash"
## Поражение.
const DEFEAT := &"defeat"
## Таймер раунда кончился.
const TIMER_OFF := &"timer_off"

# --- Петли ---

## Медленное тиканье таймера раунда.
const TICK_SLOW := &"tick_slow"
## Быстрое тиканье — идёт поверх медленного.
const TICK_FAST := &"tick_fast"
## Гомон супермаркета в магазине.
const SHOP_AMBIENT := &"shop_ambient"

# --- Музыка ---

## Меню и карта забега.
const MUSIC_MENU := &"music_menu"
## Бой.
const MUSIC_COMBAT := &"music_combat"
## Магазин.
const MUSIC_SHOP := &"music_shop"

## Что за файл стоит за каждым именем.
const _LIBRARY := {
	CLICK: "res://_Game/Audio/wood-click_144bpm.wav",
	BLOCK: "res://_Game/Audio/BLOCK.wav",
	SPICE: "res://_Game/Audio/glass.mp3",
	VICTORY: "res://_Game/Audio/Victory.mp3",
	CASH: "res://_Game/Audio/Cash_After_Victory.mp3",
	DEFEAT: "res://_Game/Audio/Defeat.wav",
	TIMER_OFF: "res://_Game/Audio/timer-off-sfx.wav",
	TICK_SLOW: "res://_Game/Audio/Clock_Ticking_Slow.mp3",
	TICK_FAST: "res://_Game/Audio/clock-ticking_Fast.wav",
	SHOP_AMBIENT: "res://_Game/Audio/Supermarket_Ambient.mp3",
	MUSIC_MENU: "res://_Game/Audio/Music/Lowtone Music - Intro Funk.mp3",
	MUSIC_COMBAT: "res://_Game/Audio/Music/Kevin MacLeod - Off to Osaka.mp3",
	MUSIC_SHOP: "res://_Game/Audio/Music/Crowander - Bye Bye Intro.mp3",
}

## Насколько тише полной громкости звучит каждый источник, дБ. Здесь
## сводится баланс: музыка и фон уходят под игру, а то, что игрок должен
## услышать наверняка (победа, поражение, запрет), звучит громче.
const _LEVELS := {
	CLICK: -7.0,
	BLOCK: -4.0,
	SPICE: -6.0,
	VICTORY: -2.0,
	CASH: -3.0,
	DEFEAT: -2.0,
	TIMER_OFF: -4.0,
	TICK_SLOW: -11.0,
	TICK_FAST: -17.0,
	SHOP_AMBIENT: -16.0,
	MUSIC_MENU: -10.0,
	MUSIC_COMBAT: -12.0,
	MUSIC_SHOP: -11.0,
}

var _volume := DEFAULT_VOLUME
## Загруженные потоки: имя → поток. Файл читается один раз за запуск.
var _cache: Dictionary = {}
## Голоса разовых эффектов; идут по кругу.
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
## Заведённые петли: имя → проигрыватель.
var _loops: Dictionary = {}
var _music: AudioStreamPlayer
## Какой трек играет сейчас; пусто — музыки нет.
var _music_key := &""
## Затухание на смене трека — второй запрос его прерывает.
var _music_tween: Tween


func _ready() -> void:
	# Звук не должен замолкать на паузе: игра ставится на паузу вместе
	# с деревом, а музыка и щелчки кнопок идут дальше.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	_music = _make_player(MUSIC_BUS)
	for _i in SFX_VOICES:
		_voices.append(_make_player(SFX_BUS))
	set_volume(_load_volume(), false)


# --- Громкость ---

## Текущая громкость: 0 — тишина, 1 — полный звук.
func get_volume() -> float:
	return _volume


## Поставить громкость шине Master. save — записать её в настройки; на
## протяжке крутилки этого не делают на каждый кадр, только на отпускании.
func set_volume(value: float, save := true) -> void:
	_volume = clampf(value, 0.0, 1.0)
	var index := AudioServer.get_bus_index(MASTER_BUS)
	if index >= 0:
		# В ноль шина не уводится линейно — на тишине её проще заглушить.
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(_volume, 0.0001)))
		AudioServer.set_bus_mute(index, _volume <= 0.001)
	if save:
		_save_volume()
	volume_changed.emit(_volume)


# --- Разовые эффекты ---

## Проиграть разовый эффект. volume_db — поправка к его обычному уровню.
func play(key: StringName, volume_db := 0.0) -> void:
	var stream := _stream(key)
	if stream == null or _voices.is_empty():
		return
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = stream
	voice.volume_db = _level(key) + volume_db
	voice.play()


# --- Петли ---

## Завести петлю. Уже играющую не перезапускает — звать можно спокойно.
func start_loop(key: StringName, volume_db := 0.0) -> void:
	var player: AudioStreamPlayer = _loops.get(key)
	if player == null:
		var stream := _looped(_stream(key))
		if stream == null:
			return
		player = _make_player(SFX_BUS)
		player.stream = stream
		_loops[key] = player
	elif player.playing:
		return
	player.volume_db = _level(key) + volume_db
	player.play()


## Остановить петлю; не заведённую — молча пропустить.
func stop_loop(key: StringName) -> void:
	var player: AudioStreamPlayer = _loops.get(key)
	if player != null:
		player.stop()


## Остановить все петли. Локация зовёт это на входе: петля предыдущей
## сцены не должна тянуться за ней.
func stop_all_loops() -> void:
	for player: AudioStreamPlayer in _loops.values():
		player.stop()


# --- Музыка ---

## Поставить музыку локации. Тот же трек, что играет сейчас, не
## перезапускается — переход между меню и картой музыку не сбивает.
func play_music(key: StringName) -> void:
	if _music == null or (_music_key == key and _music.playing):
		return
	var stream := _looped(_stream(key))
	if stream == null:
		stop_music()
		return
	_music_key = key
	var target := _level(key)
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	if not _music.playing:
		_music.stream = stream
		_music.volume_db = target
		_music.play()
		return
	# Играющий трек сперва затихает и только потом сменяется новым —
	# иначе смена локации резала бы музыку по живому.
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", MUSIC_SILENCE_DB, MUSIC_FADE * 0.5)
	_music_tween.tween_callback(func() -> void:
		_music.stream = stream
		_music.play())
	_music_tween.tween_property(_music, "volume_db", target, MUSIC_FADE * 0.5)


## Оборвать музыку: следующая локация заведёт свою с начала.
func stop_music() -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_key = &""
	if _music != null:
		_music.stop()


# --- Внутреннее ---

## Поток по имени; читается один раз за запуск. null — имени нет в
## библиотеке или файл не читается.
func _stream(key: StringName) -> AudioStream:
	if _cache.has(key):
		return _cache[key]
	var path: String = _LIBRARY.get(key, "")
	var stream: AudioStream = null
	if path != "" and ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	if stream == null:
		push_warning("AudioDirector: нет звука «%s» (%s)" % [key, path])
	_cache[key] = stream
	return stream


func _level(key: StringName) -> float:
	return float(_LEVELS.get(key, 0.0))


## Зацикленная копия потока: сами файлы импортированы без петли, а музыке,
## фону и тиканью нужен бесконечный повтор. Копия своя, поэтому обычные
## разовые эффекты из того же файла остаются незацикленными.
func _looped(stream: AudioStream) -> AudioStream:
	if stream == null:
		return null
	var mp3 := stream as AudioStreamMP3
	if mp3 != null:
		var looped_mp3 := mp3.duplicate() as AudioStreamMP3
		looped_mp3.loop = true
		return looped_mp3
	var wav := stream as AudioStreamWAV
	if wav != null:
		# Конец петли у WAV — в кадрах, а не в секундах. Не посчитался —
		# оставляем звук как есть: лучше без повтора, чем щелчок по кругу.
		var frames := int(wav.get_length() * wav.mix_rate)
		if frames <= 0:
			return stream
		var looped_wav := wav.duplicate() as AudioStreamWAV
		looped_wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		looped_wav.loop_begin = 0
		looped_wav.loop_end = frames
		return looped_wav
	return stream


func _make_player(bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player


## Шина микшера должна существовать: обычно её приносит
## `default_bus_layout.tres`, но без него звук не должен пропадать —
## недостающую шину заводим на ходу.
func _ensure_bus(bus: StringName) -> void:
	if AudioServer.get_bus_index(bus) >= 0:
		return
	var index := AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_send(index, MASTER_BUS)


func _load_volume() -> float:
	var file := ConfigFile.new()
	if file.load(SETTINGS_PATH) != OK:
		return DEFAULT_VOLUME
	return float(file.get_value(SETTINGS_SECTION, SETTINGS_KEY, DEFAULT_VOLUME))


func _save_volume() -> void:
	var file := ConfigFile.new()
	# Читаем перед записью: в файле лежат и другие настройки.
	file.load(SETTINGS_PATH)
	file.set_value(SETTINGS_SECTION, SETTINGS_KEY, _volume)
	file.save(SETTINGS_PATH)
