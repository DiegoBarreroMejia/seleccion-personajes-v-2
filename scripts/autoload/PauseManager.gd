extends Node

## Gestor global de pausa del juego
##
## Se encarga de:
## - Detectar la tecla de pausa (ESC)
## - Mostrar/ocultar el menú de pausa
## - Pausar/reanudar el árbol de escenas
##
## Funciona como autoload para estar disponible en todo el juego.

# === CONSTANTES ===
const RUTA_MENU_PAUSA: String = "res://scenes/ui/MenuPausa.tscn"
const RUTA_AJUSTES: String = "res://scenes/ui/Ajustes.tscn"

## Escenas donde NO se debe activar la pausa (menús)
const ESCENAS_SIN_PAUSA: Array[String] = [
	"MenuInicio",
	"CharacterSelect",
	"Ajustes",
	"Victoria"
]

# === VARIABLES ===
var _menu_pausa_instancia: CanvasLayer = null
var _ajustes_instancia: CanvasLayer = null
var _esta_pausado: bool = false

# === MÉTODOS DE CICLO DE VIDA ===

func _ready() -> void:
	# Permite procesar input incluso cuando el juego está pausado
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pausa"):
		# Si Ajustes está abierto como overlay, no hacer nada (ESC se maneja en ajustes.gd)
		if _ajustes_instancia:
			return
		if _puede_pausar():
			alternar_pausa()

# === MÉTODOS PRIVADOS ===

func _puede_pausar() -> bool:
	## Verifica si la escena actual permite pausar
	var escena_actual := get_tree().current_scene
	if not escena_actual:
		return false

	var nombre_escena := escena_actual.name
	return nombre_escena not in ESCENAS_SIN_PAUSA

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

	# Añadir al árbol como hijo del root para que esté encima de todo
	get_tree().root.add_child(_menu_pausa_instancia)

func _eliminar_menu_pausa() -> void:
	if _menu_pausa_instancia:
		_menu_pausa_instancia.queue_free()
		_menu_pausa_instancia = null

# === MÉTODOS PÚBLICOS ===

## Alterna entre pausado y no pausado
func alternar_pausa() -> void:
	if _esta_pausado:
		reanudar()
	else:
		pausar()

## Pausa el juego y muestra el menú de pausa
func pausar() -> void:
	if _esta_pausado:
		return

	_esta_pausado = true
	get_tree().paused = true
	_instanciar_menu_pausa()
	print("Juego pausado")

## Reanuda el juego y oculta el menú de pausa
func reanudar() -> void:
	if not _esta_pausado:
		return

	_esta_pausado = false
	get_tree().paused = false
	_eliminar_menu_pausa()
	print("Juego reanudado")

## Sale al menú principal
func salir_al_menu() -> void:
	_esta_pausado = false
	get_tree().paused = false
	_eliminar_menu_pausa()

	# Reiniciar puntuaciones al salir de la partida
	Global.reiniciar_puntuaciones()

	get_tree().change_scene_to_file("res://scenes/ui/MenuInicio.tscn")
	print("Volviendo al menú principal")

## Abre los ajustes como overlay encima del menú de pausa
func abrir_ajustes() -> void:
	if _ajustes_instancia:
		return

	# Configurar ajustes para modo overlay
	var ajustes_script := preload("res://scripts/ui/ajustes.gd")
	ajustes_script.es_overlay = true

	var ajustes_scene := load(RUTA_AJUSTES) as PackedScene
	if not ajustes_scene:
		push_error("PauseManager: No se pudo cargar Ajustes.tscn")
		return

	# Envolver en CanvasLayer para que esté encima del menú de pausa
	_ajustes_instancia = CanvasLayer.new()
	_ajustes_instancia.layer = 101  # Encima del menú de pausa (layer 100)
	_ajustes_instancia.process_mode = Node.PROCESS_MODE_ALWAYS

	var ajustes_control := ajustes_scene.instantiate()
	_ajustes_instancia.add_child(ajustes_control)

	get_tree().root.add_child(_ajustes_instancia)

	# Conectar para limpiar referencia cuando se destruya
	_ajustes_instancia.tree_exited.connect(_on_ajustes_cerrado)
	print("Ajustes abiertos desde pausa")

func _on_ajustes_cerrado() -> void:
	_ajustes_instancia = null

## Devuelve si el juego está pausado
func esta_pausado() -> bool:
	return _esta_pausado
