extends Control

const RUTA_SELECCION_PERSONAJES: String = "res://scenes/ui/CharacterSelect.tscn"
const RUTA_AJUSTES: String = "res://scenes/ui/Ajustes.tscn"
const RUTA_MENU_INICIO: String = "res://scenes/ui/MenuInicio.tscn"

# Asegura que el juego no este pausado al entrar
func _ready() -> void:
	get_tree().paused = false

# Navega a la seleccion de personajes
func _on_btn_jugar_pressed() -> void:
	get_tree().change_scene_to_file(RUTA_SELECCION_PERSONAJES)

# Abre la pantalla de ajustes
func _on_btn_ajustes_pressed() -> void:
	var ajustes_script := preload("res://scripts/ui/ajustes.gd")
	ajustes_script.escena_origen = RUTA_MENU_INICIO
	ajustes_script.es_overlay = false
	get_tree().change_scene_to_file(RUTA_AJUSTES)

# Reproduce sfx de cierre y sale del juego
func _on_btn_salir_pressed() -> void:
	SFXManager.reproducir("cerrar_juego")
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()
