class_name GamePaths
extends RefCounted
## Scene and content paths that more than one script needs to know.
##
## Keeping them here means moving a scene is one edit, not a hunt through the
## codebase for string literals.

const MAIN_MENU := "res://scenes/menus/main_menu.tscn"
const PAUSE_MENU := "res://scenes/menus/pause_menu.tscn"
const SETTINGS_MENU := "res://scenes/menus/settings_menu.tscn"

## Where a brand new game begins.
const NEW_GAME_SCENE := "res://scenes/rooms/precinct.tscn"
const NEW_GAME_SPAWN := "entrance"

## Generic close-up conversation scene, driven entirely by its payload.
const CONVERSATION := "res://scenes/conversations/conversation.tscn"

const DIALOGUE_DIR := "res://content/dialogue"

## Where the player types their name, and where a life is actually played.
## A new game goes to NAME_ENTRY, which hands off to JOURNEY_VIEW.
const NAME_ENTRY := "res://scenes/journey/name_entry.tscn"
const JOURNEY_VIEW := "res://scenes/journey/journey_view.tscn"

## The nationality a new game starts on. The others exist as datasets and have
## no authored conversations yet.
const DEFAULT_RUN := "iran"


## Path to a `.dlg` file for the current language, falling back to English so a
## partly-translated build still plays.
static func dialogue(file_name: String) -> String:
	var name := file_name if file_name.ends_with(".dlg") else file_name + ".dlg"
	var locale := TranslationServer.get_locale().get_slice("_", 0)
	var localised := "%s/%s/%s" % [DIALOGUE_DIR, locale, name]
	if ResourceLoader.exists(localised) or FileAccess.file_exists(localised):
		return localised
	return "%s/en/%s" % [DIALOGUE_DIR, name]
