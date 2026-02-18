extends CanvasLayer

## Pantalla de victoria que se superpone sobre el mapa como overlay.
##
## Se instancia desde MapaController para que el fondo sea transparente
## y se vea el estado final de la partida detrás.

# === CONSTANTES ===
const RUTA_MENU_INICIO: String = "res://scenes/ui/MenuInicio.tscn"
const RUTA_SELECCION: String = "res://scenes/ui/CharacterSelect.tscn"

# === NODOS ===
@onready var _label_ganador: Label = $Control/VBoxCentral/MarcoTexto/MargenMarco/VBoxInfo/LabelGanador
@onready var _label_marcador: Label = $Control/VBoxCentral/MarcoTexto/MargenMarco/VBoxInfo/LabelMarcador
@onready var _btn_revancha: TextureButton = $Control/VBoxCentral/BotonesContainer/BtnRevancha

# === MÉTODOS DE CICLO DE VIDA ===

func _ready() -> void:
	get_tree().paused = false
	_mostrar_resultado()
	_btn_revancha.grab_focus()

# === MÉTODOS PRIVADOS ===

func _mostrar_resultado() -> void:
	var id_ganador := Global.ultimo_ganador
	var p1 := Global.obtener_puntuacion(1)
	var p2 := Global.obtener_puntuacion(2)
	_label_ganador.text = "Jugador %d gana!" % id_ganador
	_label_marcador.text = "%d  -  %d" % [p1, p2]

# === SEÑALES DE BOTONES ===

func _on_btn_volver_menu_pressed() -> void:
	Global.reiniciar_puntuaciones()
	get_tree().change_scene_to_file(RUTA_MENU_INICIO)

func _on_btn_revancha_pressed() -> void:
	Global.reiniciar_puntuaciones()
	get_tree().change_scene_to_file(RUTA_SELECCION)
