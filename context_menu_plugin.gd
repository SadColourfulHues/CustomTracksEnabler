@tool
class_name __SCHCustomTracksHelperActualPlugin
extends EditorContextMenuPlugin


#region Plugin

func _popup_menu(paths: PackedStringArray) -> void:
    const ICON := preload("res://addons/CustomTracksEnabler/icon.png")
    var fs := EditorInterface.get_resource_filesystem()

    # Check if at least one file is compatible
    for path: String in paths:
        if path == &"res://":
            continue

        match fs.get_file_type(path):
            # Directories & Existing Animation Libraries
            # (Create/Append Animation Library)
            &"", &"AnimationLibrary":
                add_context_menu_item(
                    &"Make/Update AniLibrary",
                    _on_process_create_library,
                    ICON
                )

            # GLTF & other Model files
            # (Enable Custom Tracks)
            &"PackedScene":
                add_context_menu_item(
                    &"Enable Custom Tracks",
                    _on_process_custom_tracks,
                    ICON
                )


func _on_process_custom_tracks(paths: PackedStringArray) -> void:
    var fs := EditorInterface.get_resource_filesystem()

    for path: String in paths:
        if fs.get_file_type(path) != &"PackedScene":
            continue

        print("Enabling custom tracks for: ", path)
        path += &".import"

        if !FileAccess.file_exists(path):
            continue

        __apply_custom_tracks(path)


func _on_process_create_library(paths: PackedStringArray) -> void:
    var fs := EditorInterface.get_resource_filesystem()

    for path: String in paths:
        var library: AnimationLibrary = null

        match fs.get_file_type(path):
            &"":
                print("Creating library from tracks found in \"%s\"" % path)
                pass
            &"AnimationLibrary":
                library = load(path)
                print("Appending new animation tracks to \"%s\"" % path)
            _:
                continue

        __create_library_from_target_dir(path, library)

#endregion

#region Utils

func __apply_custom_tracks(target_path: String) -> bool:
    # TODO: Find a better way of doing this
    const PSTR_UNINITD := &"keep_custom_tracks\": \"\""
    const PSTR_OFF := &"keep_custom_tracks\": false"
    const PSTR_ON := &"keep_custom_tracks\": true"

    var read_file := FileAccess.open(target_path, FileAccess.READ)

    if !read_file.is_open():
        return false

    var contents := read_file.get_as_text()
    read_file.close()

    contents = contents.replace(PSTR_UNINITD, PSTR_ON)
    contents = contents.replace(PSTR_OFF, PSTR_ON)

    var write_file := FileAccess.open(target_path, FileAccess.WRITE)

    if !write_file.is_open():
        return false

    write_file.store_string(contents)
    write_file.close()

    EditorInterface.get_resource_filesystem().scan_sources()
    return true


func __create_library_from_target_dir(target_path: String,
                                      library: AnimationLibrary) -> void:

    var fs := EditorInterface.get_resource_filesystem()
    var append_mode := is_instance_valid(library)

    if append_mode:
        # When appending, override the search path with the library's directory
        target_path = library.resource_path.get_base_dir()
    else:
        # Create new library from the specified directory
        library = AnimationLibrary.new()

    for filename: String in DirAccess.get_files_at(target_path):
        var path := target_path.path_join(filename)

        if fs.get_file_type(path) != &"Animation":
            continue

        # e.g. /path/to/file.extension <- get_file == file|.extension -> idx 0 == file
        var animation_name := path.get_file().get_slicec(ord(&"."), 0)

        if append_mode:
            if library.has_animation(animation_name):
                continue

            print("Adding animation track \"%s\"" % animation_name)
            continue

        library.add_animation(animation_name, load(path))

    ResourceSaver.save(
        library,

        # Overwrite active
        library.resource_path
            # Python-style ternary... ugh...
            if append_mode else
        # Write to new library
        target_path.path_join(&"al_new_animation_library.res")
    )

#endregion
