@tool
extends EditorPlugin

var p_plugin: __SCHCustomTracksHelperActualPlugin

#region Plugin

func _enter_tree() -> void:
	var fs := get_editor_interface().get_resource_filesystem()

	p_plugin = __SCHCustomTracksHelperActualPlugin.new()
	p_plugin.refresh_requested.connect(fs.scan_sources)

	add_context_menu_plugin(
		EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM,
		p_plugin
	)


func _exit_tree() -> void:
	var fs := get_editor_interface().get_resource_filesystem()

	p_plugin.refresh_requested.disconnect(fs.scan_sources)
	remove_context_menu_plugin(p_plugin)

#endregion
