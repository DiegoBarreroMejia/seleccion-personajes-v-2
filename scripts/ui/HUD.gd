extends CanvasLayer

## HUD del juego - Muestra puntuación y munición de ambos jugadores
##
## Se conecta a las señales de puntuación (Global) y a las señales
## de arma equipada/desequipada de cada personaje para mostrar munición.

# === NODOS ===
@onready var _label_puntuacion: Label = $MarginContainer/VBoxContainer/LabelPuntuacion
@onready var _label_municion_j1: Label = $MarginContainer/ContenedorMunicion/PanelJ1/MargenJ1/LabelMunicionJ1
@onready var _label_municion_j2: Label = $MarginContainer/ContenedorMunicion/PanelJ2/MargenJ2/LabelMunicionJ2

# === ESTADO INTERNO ===
# Referencia a las armas actualmente equipadas para desconectar señales al cambiar
var _arma_j1: Node2D = null
var _arma_j2: Node2D = null

# === CICLO DE VIDA ===

func _ready() -> void:
	Global.puntuacion_cambiada.connect(_on_puntuacion_cambiada)
	_actualizar_texto_puntuacion()
	_actualizar_municion_label(1, -1, -1)
	_actualizar_municion_label(2, -1, -1)

	# Buscar jugadores ya spawneados y conectar señales
	# Usar call_deferred para esperar a que el árbol esté listo
	call_deferred("_conectar_jugadores")

func _conectar_jugadores() -> void:
	for nodo in get_tree().get_nodes_in_group("jugadores"):
		if nodo is CharacterBody2D and "player_id" in nodo:
			_conectar_senales_jugador(nodo)

func _conectar_senales_jugador(personaje: CharacterBody2D) -> void:
	if personaje.has_signal("arma_equipada"):
		if not personaje.arma_equipada.is_connected(_on_jugador_arma_equipada.bind(personaje.player_id)):
			personaje.arma_equipada.connect(_on_jugador_arma_equipada.bind(personaje.player_id))

	if personaje.has_signal("arma_desequipada"):
		if not personaje.arma_desequipada.is_connected(_on_jugador_arma_desequipada.bind(personaje.player_id)):
			personaje.arma_desequipada.connect(_on_jugador_arma_desequipada.bind(personaje.player_id))

# === PUNTUACIÓN ===

func _on_puntuacion_cambiada(_id_jugador: int, _nueva_puntuacion: int) -> void:
	_actualizar_texto_puntuacion()

func _actualizar_texto_puntuacion() -> void:
	var p1 := Global.obtener_puntuacion(1)
	var p2 := Global.obtener_puntuacion(2)
	var objetivo := Global.puntos_ganar
	_label_puntuacion.text = "J1: %d | J2: %d | Objetivo: %d" % [p1, p2, objetivo]

# === MUNICIÓN ===

func _on_jugador_arma_equipada(arma: Node2D, id_jugador: int) -> void:
	# Desconectar arma anterior si existía
	_desconectar_arma(id_jugador)

	# Guardar referencia y conectar señal de munición
	if id_jugador == 1:
		_arma_j1 = arma
	else:
		_arma_j2 = arma

	if arma is ArmaBase:
		if not arma.municion_cambiada.is_connected(_on_municion_cambiada.bind(id_jugador)):
			arma.municion_cambiada.connect(_on_municion_cambiada.bind(id_jugador))
		# Solicitar estado inicial
		arma.emitir_estado_municion()
	else:
		# Arma melee: mostrar indicador de melee
		_mostrar_arma_melee(id_jugador)

func _on_jugador_arma_desequipada(id_jugador: int) -> void:
	_desconectar_arma(id_jugador)
	_actualizar_municion_label(id_jugador, -1, -1)

func _desconectar_arma(id_jugador: int) -> void:
	var arma_ref: Node2D = _arma_j1 if id_jugador == 1 else _arma_j2

	if is_instance_valid(arma_ref) and arma_ref is ArmaBase:
		if arma_ref.municion_cambiada.is_connected(_on_municion_cambiada.bind(id_jugador)):
			arma_ref.municion_cambiada.disconnect(_on_municion_cambiada.bind(id_jugador))

	if id_jugador == 1:
		_arma_j1 = null
	else:
		_arma_j2 = null

func _on_municion_cambiada(actual: int, maxima: int, id_jugador: int) -> void:
	_actualizar_municion_label(id_jugador, actual, maxima)

func _actualizar_municion_label(id_jugador: int, actual: int, maxima: int) -> void:
	var label: Label = _label_municion_j1 if id_jugador == 1 else _label_municion_j2
	if not label:
		return

	var prefijo := "J%d: " % id_jugador

	if actual < 0:
		# Munición infinita o sin arma
		var arma_ref: Node2D = _arma_j1 if id_jugador == 1 else _arma_j2
		if is_instance_valid(arma_ref) and arma_ref is ArmaBase:
			label.text = prefijo + "INF"
		else:
			label.text = prefijo + "---"
	else:
		# Mostrar: balas_restantes / balas_maximas (maxima es FIJO)
		label.text = prefijo + "%d / %d" % [actual, maxima]

func _mostrar_arma_melee(id_jugador: int) -> void:
	var label: Label = _label_municion_j1 if id_jugador == 1 else _label_municion_j2
	if label:
		label.text = "J%d: MELEE" % id_jugador
