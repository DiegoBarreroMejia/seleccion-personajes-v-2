extends Control

## Pantalla de selección de personajes y configuración de partida
##
## Permite a los jugadores elegir su personaje y configurar las reglas del juego

# === SEÑALES ===
signal partida_iniciada()

# === VARIABLES PRIVADAS ===
var _p1_indice: int = 0
var _p2_indice: int = 1
var _retratos_cacheados: Dictionary = {}  # Cache de texturas

# === NODOS ===
@onready var _p1_preview: TextureRect = $panel_p1/VistaPrevia
@onready var _p2_preview: TextureRect = $panel_p2/VistaPrevia
@onready var _label_vida: Label = $ContenedorReglas/FilaVidas/LabelVida
@onready var _label_puntos: Label = $ContenedorReglas/FilaPuntos/LabelPuntos

# === MÉTODOS DE CICLO DE VIDA ===

func _ready() -> void:
	_precargar_retratos()
	_actualizar_vistas_personajes()
	_actualizar_ui_reglas()

# === CONFIGURACIÓN INICIAL ===

func _precargar_retratos() -> void:
	"""Precarga todas las texturas de personajes para evitar lag"""
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

# === ACTUALIZACIÓN DE UI ===

func _actualizar_vistas_personajes() -> void:
	"""Actualiza las vistas previas de ambos jugadores"""
	_actualizar_vista_jugador(1, _p1_indice)
	_actualizar_vista_jugador(2, _p2_indice)

func _actualizar_vista_jugador(id_jugador: int, indice: int) -> void:
	"""Actualiza la vista previa de un jugador específico"""
	var catalogo := Global.catalogo_personajes
	
	if indice < 0 or indice >= catalogo.size():
		push_error("Índice de personaje inválido: %d" % indice)
		return
	
	var datos_personaje: Dictionary = catalogo[indice]
	var ruta_retrato: String = datos_personaje.get("retrato", "")
	var textura: Texture2D = _retratos_cacheados.get(ruta_retrato)
	
	if id_jugador == 1:
		_p1_preview.texture = textura
		Global.p1_seleccion = datos_personaje
	else:
		_p2_preview.texture = textura
		Global.p2_seleccion = datos_personaje

func _actualizar_ui_reglas() -> void:
	"""Actualiza los labels de configuración de reglas"""
	_label_vida.text = str(Global.vida_maxima)
	_label_puntos.text = str(Global.puntos_ganar)

# === NAVEGACIÓN DE PERSONAJES ===

func _navegar_personaje(id_jugador: int, direccion: int) -> void:
	"""Navega por el catálogo de personajes
	
	Args:
		id_jugador: 1 o 2
		direccion: -1 para anterior, 1 para siguiente
	"""
	var tamano_catalogo := Global.catalogo_personajes.size()
	if tamano_catalogo == 0:
		return
	
	if id_jugador == 1:
		_p1_indice = (_p1_indice + direccion + tamano_catalogo) % tamano_catalogo
	else:
		_p2_indice = (_p2_indice + direccion + tamano_catalogo) % tamano_catalogo
	
	_actualizar_vistas_personajes()

# === SEÑALES DE BOTONES - PERSONAJES ===

func _on_anterior_p1_pressed() -> void:
	_navegar_personaje(1, -1)

func _on_siguiente_p1_pressed() -> void:
	_navegar_personaje(1, 1)

func _on_anterior_p2_pressed() -> void:
	_navegar_personaje(2, -1)

func _on_siguiente_p2_pressed() -> void:
	_navegar_personaje(2, 1)

# === SEÑALES DE BOTONES - REGLAS ===

func _on_btn_vida_mas_pressed() -> void:
	Global.vida_maxima += 1
	_actualizar_ui_reglas()

func _on_btn_vida_menos_pressed() -> void:
	Global.vida_maxima -= 1
	_actualizar_ui_reglas()

func _on_btn_puntos_mas_pressed() -> void:
	Global.puntos_ganar += 1
	_actualizar_ui_reglas()

func _on_btn_puntos_menos_pressed() -> void:
	Global.puntos_ganar -= 1
	_actualizar_ui_reglas()

# === INICIO DE PARTIDA ===

func _on_partida_pressed() -> void:
	"""Inicia la partida con los personajes y configuración seleccionados"""
	var nombre_p1: String = Global.p1_seleccion.get("nombre", "Desconocido")
	var nombre_p2: String = Global.p2_seleccion.get("nombre", "Desconocido")
	
	print("=== INICIANDO PARTIDA ===")
	print("J1: %s" % nombre_p1)
	print("J2: %s" % nombre_p2)
	print("Vidas: %d" % Global.vida_maxima)
	print("Puntos para ganar: %d" % Global.puntos_ganar)
	print("========================")
	
	partida_iniciada.emit()
	
	var mapa_aleatorio: String = Global.obtener_mapa_aleatorio()
	if mapa_aleatorio.is_empty():
		push_error("No se pudo obtener un mapa")
		return
	
	get_tree().change_scene_to_file(mapa_aleatorio)
