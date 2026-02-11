extends Control

## Pantalla de inicio del juego
##
## Presenta las opciones principales: Jugar, Ajustes y Salir

# === CONSTANTES ===
const RUTA_SELECCION_PERSONAJES: String = "res://scenes/ui/CharacterSelect.tscn"
const RUTA_AJUSTES: String = "res://scenes/ui/Ajustes.tscn"
const RUTA_MENU_INICIO: String = "res://scenes/ui/MenuInicio.tscn"

# === MÉTODOS DE CICLO DE VIDA ===

func _ready() -> void:
	# Asegurar que el juego no esté pausado al entrar al menú
	get_tree().paused = false

# === SEÑALES DE BOTONES ===

func _on_btn_jugar_pressed() -> void:
	get_tree().change_scene_to_file(RUTA_SELECCION_PERSONAJES)

func _on_btn_ajustes_pressed() -> void:
	# Preload del script para acceder a las variables estáticas
	var ajustes_script := preload("res://scripts/ui/ajustes.gd")
	ajustes_script.escena_origen = RUTA_MENU_INICIO
	ajustes_script.es_overlay = false
	get_tree().change_scene_to_file(RUTA_AJUSTES)

func _on_btn_salir_pressed() -> void:
	get_tree().quit()
