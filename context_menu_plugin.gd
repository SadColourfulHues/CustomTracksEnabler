@tool
class_name __SCHCustomTracksHelperActualPlugin
extends EditorContextMenuPlugin

# Temporary solution!! #
# TODO: Find a better way of doing this
const PSTR_UNINITD := &"keep_custom_tracks\": \"\""
const PSTR_OFF := &"keep_custom_tracks\": false"
const PSTR_ON := &"keep_custom_tracks\": true"

signal refresh_requested()


#region Plugin

func _popup_menu(paths: PackedStringArray) -> void:
    # Check if at least one file is compatible
    for path: String in paths:
        if !path.ends_with(&".glb"):
            continue

        add_context_menu_item(
            &"Enable Custom Tracks",
            _on_process,
            load(^"res://addons/CustomTracksEnabler/icon.png")
        )
        return


func _on_process(paths: PackedStringArray) -> void:
    for path: String in paths:
        if !path.ends_with(&".glb"):
            continue

        path += &".import"

        print(path)

        if !FileAccess.file_exists(path):
            continue

        __apply_custom_tracks(path)

#endregion

#region Utils

func __apply_custom_tracks(target_url: String) -> bool:
    var read_file := FileAccess.open(target_url, FileAccess.READ)

    if !read_file.is_open():
        return false

    var contents := read_file.get_as_text()
    read_file.close()

    contents = contents.replace(PSTR_UNINITD, PSTR_ON)
    contents = contents.replace(PSTR_OFF, PSTR_ON)

    var write_file := FileAccess.open(target_url, FileAccess.WRITE)

    if !write_file.is_open():
        return false

    write_file.store_string(contents)
    write_file.close()

    refresh_requested.emit()
    return true

#endregion
