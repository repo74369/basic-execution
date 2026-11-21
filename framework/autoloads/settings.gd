extends Node

var setting_data:SettingsResource
var SETTING_DATA_PATH:String = "user://settings.res"

signal settings_reset
signal settings_saved
signal settings_changed(new_values:SettingsResource)

# Save / Load / Reset
func load_settings_resource() -> SettingsResource:
    if ResourceLoader.exists(SETTING_DATA_PATH):
        var res = ResourceLoader.load(SETTING_DATA_PATH)
        if res is SettingsResource:
            return res
    return SettingsResource.new()


func save_settings() -> void:
    if setting_data:
        ResourceSaver.save(setting_data, SETTING_DATA_PATH)
        settings_saved.emit()


func reset_to_defaults() -> void:
    setting_data = SettingsResource.new()
    save_settings()
    # apply_all_settings()s
    settings_reset.emit()

func _ready() -> void:
    setting_data = load_settings_resource() as SettingsResource
    