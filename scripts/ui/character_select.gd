extends Control

const RUTA_MENU_INICIO: String = "res://scenes/ui/MenuInicio.tscn"
const RUTA_AJUSTES: String = "res://scenes/ui/Ajustes.tscn"
const RUTA_SELECCION: String = "res://scenes/ui/CharacterSelect.tscn"

signal partida_iniciada()

var _p1_indice: int = 0
var _p2_indice: int = 1
var _retratos_cacheados: Dictionary = {}

@onready var _p1_preview: TextureRect = $MargenPrincipal/VBoxPrincipal/PanelesJugadores/panel_p1/MarginContainer/VBoxContainer/VistaPrevia
@onready var _p2_preview: TextureRect = $MargenPrincipal/VBoxPrincipal/PanelesJugadores/panel_p2/MarginContainer/VBoxContainer/VistaPrevia
@onready var _label_vida: Label = $MargenPrincipal/VBoxPrincipal/PanelesJugadores/ContenedorReglas/FilaVidas/MarcoVidas/LabelVida
@onready var _label_puntos: Label = $MargenPrincipal/VBoxPrincipal/PanelesJugadores/ContenedorReglas/FilaPuntos/MarcoPuntos/LabelPuntos

# Inicializa cache de retratos y actualiza la UI
func _ready() -> void:
	_precargar_retratos()
	_actualizar_vistas_personajes()
	_actualizar_ui_reglas()

# Precarga todas las texturas de personajes en cache
func _precargar_retratos() -> void:
	for datos_personaje in Global.catalogo_personajes:
		var ruta_retrato: String = datos_personaje.get("retrato", "")
		if ruta_retrato.is_empty():
			continue

		if not ResourceLoader.exists(ruta_retrato):
			push_warning("Retrato no encontrado: %s" % ruta_retrato)
			continue

		var textura := load(ruta_retrato) as Texture2D
		if textura:
			_retratos_cacheados[ruta_retrato] = textura

# Actualiza las vistas previas de ambos jugadores
func _actualizar_vistas_personajes() -> void:
	_actualizar_vista_jugador(1, _p1_indice)
	_actualizar_vista_jugador(2, _p2_indice)

# Actualiza la vista previa de un jugador especifico
func _actualizar_vista_jugador(id_jugador: int, indice: int) -> void:
	var catalogo := Global.catalogo_personajes

	if catalogo.is_empty():
		push_error("Catálogo de personajes vacío")
		return

	if indice < 0 or indice >= catalogo.size():
		push_error("Índice de personaje inválido: %d" % indice)
		return

	var datos_personaje: Dictionary = catalogo[indice]
	var ruta_retrato: String = datos_personaje.get("retrato", "")
	var textura: Texture2D = _retratos_cacheados.get(ruta_retrato)

	if textura == null and not ruta_retrato.is_empty():
		push_warning("Retrato no cacheado para: %s" % datos_personaje.get("nombre", "?"))

	if id_jugador == 1:
		_p1_preview.texture = textura
		Global.p1_seleccion = datos_personaje
	else:
		_p2_preview.texture = textura
		Global.p2_seleccion = datos_personaje

# Actualiza los labels de vida y puntos
func _actualizar_ui_reglas() -> void:
	_label_vida.text = str(Global.vida_maxima)
	_label_puntos.text = str(Global.puntos_ganar)

# Navega por el catalogo de personajes con wrap circular
func _navegar_personaje(id_jugador: int, direccion: int) -> void:
	var tamano_catalogo := Global.catalogo_personajes.size()
	if tamano_catalogo == 0:
		return

	if id_jugador == 1:
		_p1_indice = (_p1_indice + direccion + tamano_catalogo) % tamano_catalogo
	else:
		_p2_indice = (_p2_indice + direccion + tamano_catalogo) % tamano_catalogo

	_actualizar_vistas_personajes()

# Boton anterior jugador 1
func _on_anterior_p1_pressed() -> void:
	_navegar_personaje(1, -1)

# Boton siguiente jugador 1
func _on_siguiente_p1_pressed() -> void:
	_navegar_personaje(1, 1)

# Boton anterior jugador 2
func _on_anterior_p2_pressed() -> void:
	_navegar_personaje(2, -1)

# Boton siguiente jugador 2
func _on_siguiente_p2_pressed() -> void:
	_navegar_personaje(2, 1)

# Suma una vida maxima
func _on_btn_vida_mas_pressed() -> void:
	Global.vida_maxima += 1
	_actualizar_ui_reglas()

# Resta una vida maxima
func _on_btn_vida_menos_pressed() -> void:
	Global.vida_maxima -= 1
	_actualizar_ui_reglas()

# Suma un punto para ganar
func _on_btn_puntos_mas_pressed() -> void:
	Global.puntos_ganar += 1
	_actualizar_ui_reglas()

# Resta un punto para ganar
func _on_btn_puntos_menos_pressed() -> void:
	Global.puntos_ganar -= 1
	_actualizar_ui_reglas()

# Vuelve al menu principal
func _on_btn_volver_pressed() -> void:
	get_tree().change_scene_to_file(RUTA_MENU_INICIO)

# Abre la pantalla de ajustes
func _on_btn_ajustes_pressed() -> void:
	var ajustes_script := preload("res://scripts/ui/ajustes.gd")
	ajustes_script.escena_origen = RUTA_SELECCION
	ajustes_script.es_overlay = false
	get_tree().change_scene_to_file(RUTA_AJUSTES)

# Inicia la partida con un mapa aleatorio
func _on_partida_pressed() -> void:
	partida_iniciada.emit()

	var mapa_aleatorio: String = Global.obtener_mapa_aleatorio()
	if mapa_aleatorio.is_empty():
		push_error("No se pudo obtener un mapa")
		return

	get_tree().change_scene_to_file(mapa_aleatorio)
