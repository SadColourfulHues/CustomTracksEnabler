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
            # GLTF & other Model files
            # Main Processing Function
            &"PackedScene":
                if path.get_extension() == &"tscn":
                    continue

                add_context_menu_item(
                    &"Enable Custom Tracks",
                    _on_process_assets,
                    ICON
                )


func _on_process_assets(paths: PackedStringArray) -> void:
    var fs := EditorInterface.get_resource_filesystem()
    var fs_dock := EditorInterface.get_file_system_dock()

    var folder_colours: Dictionary = (
        ProjectSettings.get_setting(&"file_customization/folder_colors", {})
    )

    for path: String in paths:
        if fs.get_file_type(path) != &"PackedScene":
            continue

        # Create sample scene for processing #
        var template: PackedScene = load(path)
        assert(
            is_instance_valid(template) && template.can_instantiate(),
            "CustomTracksEnabler: invalid 3D asset file!"
        )

        var sample: Node = template.instantiate()
        assert(is_instance_valid(sample), "CustomTracksEnabler: instantiated sample scene invalid.")

        # /path/to/file.ext -> file|.|ext -> [0] -> file
        var filename := path.get_file().get_slicec(ord('.'), 0)
        var base_dir := path.get_base_dir()

        print(&"CustomTracksEnabler: process \"%s\"" % path)

        # Init paths #
        var path_sub := base_dir.path_join(&"Subresources")
        var path_anims := path_sub.path_join(&"Animations")

        # It apparently also needs a '/', or else it doesn't work
        folder_colours[&"%s/" % path_sub] = &"orange"

        __init_dirs(
            path_anims,
        )

        var anim_paths: Dictionary[StringName, StringName] = {}

        # Process Main #
        __extract_animations(filename, sample, anim_paths, path_anims, path_sub)

        # Finalise #
        sample.free.call_deferred()
        __finalise_import_file(path, anim_paths)

    # Finalise folder colours update #
    # based from https://github.com/godotengine/godot/blob/c01c7b800d26c158e740e1e8e4cd30c9e4b00993/editor/docks/filesystem_dock.cpp#L3209
    ProjectSettings.set_setting(&"file_customization/folder_colors", folder_colours)
    ProjectSettings.save()
    fs_dock.folder_color_changed.emit()

    # Finalise the rest #
    fs.scan_sources()

#endregion

#region Utils

func __init_dirs(...paths: Array) -> void:
    for path: String in paths:
        if DirAccess.dir_exists_absolute(path):
            continue

        DirAccess.make_dir_recursive_absolute(path)


func __extract_animations(name: String,
                          root: Node,
                          anim_paths: Dictionary[StringName, StringName],
                          path_anims: String,
                          path_libs: String) -> void:

    var player: AnimationPlayer = root.get_node_or_null(^"AnimationPlayer")

    if player == null:
        print("CustomTracksEnabler: 3D asset \"%s\" has no data" % name)
        return

    for library_id: StringName in player.get_animation_library_list():
        var library := player.get_animation_library(library_id)
        var new_library := AnimationLibrary.new()

        # Extract animations #
        for animation_id: StringName in library.get_animation_list():
            var animation := library.get_animation(animation_id)
            var save_path := path_anims.path_join(&"anim_%s.anim" % animation_id)

            ResourceSaver.save(animation, save_path)
            new_library.add_animation(animation_id, load(save_path))

            anim_paths[animation_id] = save_path

        # Finalise library extraction #
        var library_save_path: String

        if library_id.is_empty():
            library_save_path = path_libs.path_join(&"alib_%s.tres" % name)
        else:
            library_save_path = path_libs.path_join(&"alib_%s%s.tres" % [name, library_id])

        ResourceSaver.save(new_library, library_save_path)

        player.remove_animation_library(library_id)
        player.add_animation_library(library_id, load(library_save_path))


# NOTE: These functions may break if the .import file format changes,
# but since there's no available or documented available API for this,
# this is the best I could work with for now
# (Currently works on Godot 4.5)

func __finalise_import_file(path: String,
                            paths: Dictionary[StringName, StringName]) -> void:

    var path_import_file := &"%s.import" % path

    if !FileAccess.file_exists(path_import_file):
        return

    print("CustomTracksEnabler: Applying changes to \"%s\"" % path_import_file)

    var new_import_file = FileAccess.open(path_import_file, FileAccess.WRITE)
    var lines := FileAccess.get_file_as_string(path_import_file).split(&"\n")
    var last_id := &""

    var format: Array[StringName]
    format.resize(2)
    format.fill(&"")

    var sr_mode := false
    var depth := 0

    var subresource_str := &"{"

    for line: StringName in lines:
        # Look for subresources dict #
        if !sr_mode && line.begins_with(&"_subresources"):
            # Check for empty subresources dict
            # (Happens with new imports with no configuration)
            if line.ends_with(&"}"):
                __finalise_subresources_write(new_import_file, &"{}", paths)
                continue

            # subresources has data, begin accumulation
            depth = 1
            sr_mode = true
            continue

        # Accumulate until we're out of the subresources dictionary section #
        # (This will only run, if there's actually any stored data in the dict)
        elif sr_mode:
            if line.begins_with(&"\"slice_"):
                continue

            if line.ends_with(&"{"):
                depth += 1
            elif line.begins_with(&"}") || line.ends_with(&"}"):
                depth -= 1

            # Since "subresources" is a dictionary in JSON form, we can check if
            # we're still within it if the line starts with a quoted key string
            if line.begins_with(&"}") || line.begins_with(&"\""):
                format[0] = subresource_str
                format[1] = line

                subresource_str = &"%s\n%s" % format
                continue

            if depth > 0:
                subresource_str += &"}".repeat(depth)

            __finalise_subresources_write(
                new_import_file,
                subresource_str,
                paths
            )

            sr_mode = false
            continue

        # Passthrough non-essential lines
        new_import_file.store_line(line)

    new_import_file.close()


func __finalise_subresources_write(file: FileAccess,
                                   accum_str: String,
                                   paths: Dictionary[StringName, StringName]) -> void:

    var subresources_dict: Dictionary = JSON.parse_string(accum_str)
    assert(subresources_dict != null, "CustomTracksEnabler: malformed subresources dictionary")

    var former_data: Dictionary = subresources_dict.get(&"animations", {})
    var animations_dict: Dictionary[StringName, Dictionary] = {}

    var anim_ids: Array[StringName] = paths.keys()
    var path_anim: Array[StringName] = paths.values()

    for i: int in range(anim_ids.size()):
        var id := anim_ids[i]
        var path : = path_anim[i]

        # Try to reuse stored preference data if possible
        # json["animations"][animation_id][loop_mode]
        var stored_anim_data: Dictionary = former_data.get(id, {})
        var loop_mode: int = stored_anim_data.get(&"settings/loop_mode", 0)

        animations_dict[id] = {
            &"save_to_file/enabled": true,
            &"save_to_file/fallback_path": path,
            &"save_to_file/keep_custom_tracks": true,
            &"save_to_file/path": ResourceUID.path_to_uid(path),
            &"settings/loop_mode": loop_mode
        }

    # Finalise write #

    subresources_dict[&"animations"] = animations_dict

    file.store_string(
        &"_subresources=%s" % JSON.stringify(subresources_dict, &"", false)
    )
