extends CanvasLayer

const RUTA_MENU_INICIO: String = "res://scenes/ui/MenuInicio.tscn"
const RUTA_SELECCION: String = "res://scenes/ui/CharacterSelect.tscn"
const SFX_VICTORIA: AudioStream = preload("res://assets/sonidos/partida/sonido_victoria.wav")

@onready var _label_ganador: Label = $Control/VBoxCentral/MarcoTexto/MargenMarco/VBoxInfo/LabelGanador
@onready var _label_marcador: Label = $Control/VBoxCentral/MarcoTexto/MargenMarco/VBoxInfo/LabelMarcador
@onready var _btn_revancha: TextureButton = $Control/VBoxCentral/BotonesContainer/BtnRevancha

# Muestra resultado y reproduce sonido de victoria
func _ready() -> void:
	get_tree().paused = false
	_mostrar_resultado()
	_reproducir_sonido_victoria()
	_btn_revancha.grab_focus()

# Reproduce el sfx de victoria
func _reproducir_sonido_victoria() -> void:
	var sfx := AudioStreamPlayer.new()
	sfx.stream = SFX_VICTORIA
	sfx.bus = "SFX"
	add_child(sfx)
	sfx.play()

# Muestra el ganador y marcador final
func _mostrar_resultado() -> void:
	var id_ganador := Global.ultimo_ganador
	var p1 := Global.obtener_puntuacion(1)
	var p2 := Global.obtener_puntuacion(2)
	_label_ganador.text = "Jugador %d gana!" % id_ganador
	_label_marcador.text = "%d  -  %d" % [p1, p2]

# Vuelve al menu principal
func _on_btn_volver_menu_pressed() -> void:
	Global.reiniciar_puntuaciones()
	get_tree().change_scene_to_file(RUTA_MENU_INICIO)

# Reinicia puntuaciones y va a seleccion de personajes
func _on_btn_revancha_pressed() -> void:
	Global.reiniciar_puntuaciones()
	get_tree().change_scene_to_file(RUTA_SELECCION)
