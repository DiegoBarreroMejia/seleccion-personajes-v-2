extends Control

## Pantalla de victoria que se muestra al finalizar la partida
##
## Muestra el ganador, marcador final y opciones para continuar

# === CONSTANTES ===
const RUTA_MENU_INICIO: String = "res://scenes/ui/MenuInicio.tscn"
const RUTA_SELECCION: String = "res://scenes/ui/CharacterSelect.tscn"

# === NODOS ===
@onready var _label_ganador: Label = $ContenedorCentral/LabelGanador
@onready var _label_marcador: Label = $ContenedorCentral/LabelMarcador
@onready var _btn_volver_menu: Button = $ContenedorCentral/BtnVolverMenu

# === MÉTODOS DE CICLO DE VIDA ===

func _ready() -> void:
	# Asegurar que el juego no esté pausado
	get_tree().paused = false

	_mostrar_resultado()
	_btn_volver_menu.grab_focus()

# === MÉTODOS PRIVADOS ===

func _mostrar_resultado() -> void:
	var id_ganador := Global.ultimo_ganador
	var p1 := Global.obtener_puntuacion(1)
	var p2 := Global.obtener_puntuacion(2)

	_label_ganador.text = "Jugador %d gana!" % id_ganador
	_label_marcador.text = "Marcador final: %d - %d" % [p1, p2]

# === SEÑALES DE BOTONES ===

func _on_btn_volver_menu_pressed() -> void:
	Global.reiniciar_puntuaciones()
	get_tree().change_scene_to_file(RUTA_MENU_INICIO)

func _on_btn_revancha_pressed() -> void:
	Global.reiniciar_puntuaciones()
	get_tree().change_scene_to_file(RUTA_SELECCION)
