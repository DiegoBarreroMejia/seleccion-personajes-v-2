extends Control

## Pantalla de ajustes (placeholder)
##
## Por ahora solo permite volver al menú principal.
## Aquí se añadirán opciones de volumen, controles, etc. en el futuro.

# === CONSTANTES ===
const RUTA_MENU_INICIO: String = "res://scenes/ui/MenuInicio.tscn"

# === SEÑALES DE BOTONES ===

func _on_btn_volver_pressed() -> void:
	get_tree().change_scene_to_file(RUTA_MENU_INICIO)
