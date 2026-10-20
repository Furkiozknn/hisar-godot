extends Node
## Turkish / English text lookup. Strings live in res://data/strings.tres.

signal language_changed

var _table: LocaleTable


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_table = load("res://data/strings.tres") as LocaleTable
	Settings.changed.connect(func(key: StringName) -> void:
		if key == &"language":
			language_changed.emit())


func lang() -> String:
	return Settings.language


## Text for key in the current language; {name} placeholders are filled from vars.
func t(key: String, vars: Dictionary = {}) -> String:
	var dict: Dictionary = _table.en_text if Settings.language == "en" else _table.tr_text
	var s: String = String(dict.get(key, _table.tr_text.get(key, key)))
	for k: Variant in vars:
		s = s.replace("{%s}" % str(k), str(vars[k]))
	return s


func has_key(key: String) -> bool:
	return _table.tr_text.has(key) and _table.en_text.has(key)


func toggle() -> void:
	Settings.set_value(&"language", "tr" if Settings.language == "en" else "en")
