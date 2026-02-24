extends Node

const RUTA_MENU_PAUSA: String = "res://scenes/ui/MenuPausa.tscn"
const RUTA_AJUSTES: String = "res://scenes/ui/Ajustes.tscn"

const ESCENAS_SIN_PAUSA: Array[String] = [
	"MenuInicio",
	"CharacterSelect",
	"Ajustes",
	"Victoria"
]

var _sfx_pausar: AudioStream = preload("res://assets/sonidos/ui/sonido_cauando_pausas.ogg")
var _sfx_reanudar: AudioStream = preload("res://assets/sonidos/ui/sonido_cuando_quitas_pausa.ogg")

var _menu_pausa_instancia: CanvasLayer = null
var _ajustes_instancia: CanvasLayer = null
var _esta_pausado: bool = false
var _sfx_player: AudioStreamPlayer = null

# Crea reproductor de sfx para pausa
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_sfx_player.bus = "SFX"
	add_child(_sfx_player)

# Detecta tecla de pausa
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pausa"):
		if _ajustes_instancia:
			return
		if _puede_pausar():
			alternar_pausa()

# Verifica si la escena actual permite pausar
func _puede_pausar() -> bool:
	var escena_actual := get_tree().current_scene
	if not escena_actual:
		return false

	var nombre_escena := escena_actual.name
	return nombre_escena not in ESCENAS_SIN_PAUSA

# Instancia el menu de pausa
func _instanciar_menu_pausa() -> void:
	if _menu_pausa_instancia:
		return

	var menu_pausa_scene := load(RUTA_MENU_PAUSA) as PackedScene
	if not menu_pausa_scene:
		push_error("PauseManager: No se pudo cargar MenuPausa.tscn")
		return

	_menu_pausa_instancia = menu_pausa_scene.instantiate() as CanvasLayer
	if not _menu_pausa_instancia:
		push_error("PauseManager: No se pudo instanciar MenuPausa")
		return

	get_tree().root.add_child(_menu_pausa_instancia)

# Destruye el menu de pausa
func _eliminar_menu_pausa() -> void:
	if _menu_pausa_instancia:
		_menu_pausa_instancia.queue_free()
		_menu_pausa_instancia = null

# Alterna entre pausado y no pausado
func alternar_pausa() -> void:
	if _esta_pausado:
		reanudar()
	else:
		pausar()

# Pausa el juego y muestra el menu
func pausar() -> void:
	if _esta_pausado:
		return

	_esta_pausado = true
	get_tree().paused = true
	_instanciar_menu_pausa()
	_sfx_player.stream = _sfx_pausar
	_sfx_player.play()

# Reanuda el juego y oculta el menu
func reanudar() -> void:
	if not _esta_pausado:
		return

	_esta_pausado = false
	get_tree().paused = false
	_eliminar_menu_pausa()
	_sfx_player.stream = _sfx_reanudar
	_sfx_player.play()

# Sale al menu principal
func salir_al_menu() -> void:
	_esta_pausado = false
	get_tree().paused = false
	_eliminar_menu_pausa()

	Global.reiniciar_puntuaciones()

	get_tree().change_scene_to_file("res://scenes/ui/MenuInicio.tscn")

# Abre ajustes como overlay sobre el menu de pausa
func abrir_ajustes() -> void:
	if _ajustes_instancia:
		return

	var ajustes_script := preload("res://scripts/ui/ajustes.gd")
	ajustes_script.es_overlay = true

	var ajustes_scene := load(RUTA_AJUSTES) as PackedScene
	if not ajustes_scene:
		push_error("PauseManager: No se pudo cargar Ajustes.tscn")
		return

	_ajustes_instancia = CanvasLayer.new()
	_ajustes_instancia.layer = 101
	_ajustes_instancia.process_mode = Node.PROCESS_MODE_ALWAYS

	var ajustes_control := ajustes_scene.instantiate()
	_ajustes_instancia.add_child(ajustes_control)

	get_tree().root.add_child(_ajustes_instancia)

	_ajustes_instancia.tree_exited.connect(_on_ajustes_cerrado)

# Limpia referencia al cerrar ajustes
func _on_ajustes_cerrado() -> void:
	_ajustes_instancia = null

# Devuelve si el juego esta pausado
func esta_pausado() -> bool:
	return _esta_pausado
