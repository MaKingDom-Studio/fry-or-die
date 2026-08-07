## Шрифт надписей магазина (ценники, баланс звёзд).
##
## Основной шрифт проекта — Grunge Bold V2. Файл кладётся в
## [constant FONT_DIR] (имя может быть любым из [constant FONT_NAMES] —
## подходит и .ttf, и .otf), после чего ценники и баланс начинают писать
## им сами: искать и назначать шрифт в каждом узле не нужно. Если в узле
## шрифт задан явно (поле «Шрифт» в инспекторе), берётся он; если файла
## нет вовсе — системный шрифт-заглушка, как раньше.
class_name UiFont
extends RefCounted

## Где лежит шрифт проекта.
const FONT_DIR := "res://_Game/Art/UI/Fonts/"

## Имена файла, которые подхватываются автоматически (в этом порядке).
const FONT_NAMES := [
	"Grunge Bold V2.ttf",
	"Grunge Bold V2.otf",
	"Grunge_Bold_V2.ttf",
	"Grunge_Bold_V2.otf",
]

## Найденный шрифт (ищется один раз за запуск); null — файла нет.
static var _cached: Font = null
static var _looked_up := false


## Шрифт для надписи: override из инспектора, иначе шрифт проекта,
## иначе системная заглушка.
static func resolve(override: Font = null) -> Font:
	if override != null:
		return override
	var project_font := project_font()
	return project_font if project_font != null else ThemeDB.fallback_font


## Шрифт проекта из [constant FONT_DIR]; null, если файла ещё нет.
static func project_font() -> Font:
	if _looked_up:
		return _cached
	_looked_up = true
	for name in FONT_NAMES:
		var path: String = FONT_DIR + name
		if ResourceLoader.exists(path):
			_cached = load(path) as Font
			if _cached != null:
				return _cached
	return null
