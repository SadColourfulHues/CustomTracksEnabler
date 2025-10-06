@tool
extends EditorPlugin

var p_plugin: __SCHCustomTracksHelperActualPlugin

#region Plugin

func _enter_tree() -> void:
	p_plugin = __SCHCustomTracksHelperActualPlugin.new()

	add_context_menu_plugin(
		EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM,
		p_plugin
	)


func _exit_tree() -> void:
	remove_context_menu_plugin(p_plugin)

#endregion
