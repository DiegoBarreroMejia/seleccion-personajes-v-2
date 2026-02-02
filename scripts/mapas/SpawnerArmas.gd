extends Marker2D
class_name SpawnerArmas

## Spawner que genera armas aleatorias periódicamente
##
## Cuando un jugador recoge el arma, inicia un cooldown antes de generar una nueva

# === SEÑALES ===
signal arma_generada(arma: Node2D)
signal arma_recogida()

# === CONSTANTES ===
const TIEMPO_RESPAWN_DEFECTO: float = 5.0
const TIEMPO_RESPAWN_MIN: float = 1.0
const TIEMPO_RESPAWN_MAX: float = 30.0

# === VARIABLES EXPORTADAS ===
@export var lista_armas: Array[PackedScene] = []
@export var tiempo_respawn: float = TIEMPO_RESPAWN_DEFECTO:
	set(value):
		tiempo_respawn = clampf(value, TIEMPO_RESPAWN_MIN, TIEMPO_RESPAWN_MAX)
@export var generar_al_inicio: bool = true

# === VARIABLES PRIVADAS ===
var _arma_actual: Node2D = null  # Puede ser ArmaBase o ArmaMeleeBase
var _esperando: bool = false
var _temporizador_respawn: Timer

# === MÉTODOS DE CICLO DE VIDA ===

func _ready() -> void:
	_configurar_temporizador_respawn()
	
	if generar_al_inicio and lista_armas.size() > 0:
		spawn_arma()

# === CONFIGURACIÓN ===

func _configurar_temporizador_respawn() -> void:
	_temporizador_respawn = Timer.new()
	_temporizador_respawn.one_shot = true
	_temporizador_respawn.timeout.connect(_on_temporizador_respawn_timeout)
	add_child(_temporizador_respawn)

# === SPAWNING ===

## Genera un arma aleatoria en este spawner
func spawn_arma() -> void:
	if lista_armas.is_empty():
		push_warning("SpawnerArmas: lista_armas está vacía en %s" % name)
		return
	
	if _arma_actual != null:
		push_warning("SpawnerArmas: Intento de spawn con arma existente")
		return
	
	var escena_arma := lista_armas.pick_random() as PackedScene
	if not escena_arma:
		return
	
	_arma_actual = escena_arma.instantiate() as Node2D
	if not _arma_actual:
		push_error("SpawnerArmas: No se pudo instanciar arma")
		return
	
	add_child(_arma_actual)
	_arma_actual.position = Vector2.ZERO
	
	# Conectar señal del arma para saber cuándo la recogen
	# Soporta tanto ArmaBase como ArmaMeleeBase
	if _arma_actual.has_signal("arma_recogida"):
		_arma_actual.arma_recogida.connect(_on_arma_fue_recogida)
	
	arma_generada.emit(_arma_actual)
	_esperando = false
	
	print("SpawnerArmas: Arma generada en %s" % name)

func _on_arma_fue_recogida(_id_jugador: int) -> void:
	# Desconectar señal para evitar llamadas futuras si el arma es soltada y recogida de nuevo
	if _arma_actual and _arma_actual.has_signal("arma_recogida"):
		if _arma_actual.arma_recogida.is_connected(_on_arma_fue_recogida):
			_arma_actual.arma_recogida.disconnect(_on_arma_fue_recogida)
	_arma_actual = null
	arma_recogida.emit()
	_iniciar_cooldown_respawn()
	
	print("SpawnerArmas: Arma recogida, iniciando cooldown de %.1fs" % tiempo_respawn)

func _iniciar_cooldown_respawn() -> void:
	if _esperando:
		return
	
	_esperando = true
	_temporizador_respawn.start(tiempo_respawn)

func _on_temporizador_respawn_timeout() -> void:
	spawn_arma()

# === MÉTODOS PÚBLICOS ===

## Cambia el pool de armas disponibles
func establecer_pool_armas(nuevo_pool: Array[PackedScene]) -> void:
	lista_armas = nuevo_pool

## Fuerza un spawn inmediato eliminando el arma actual
func forzar_spawn() -> void:
	if _arma_actual:
		_arma_actual.queue_free()
		_arma_actual = null
	
	_esperando = false
	_temporizador_respawn.stop()
	spawn_arma()

## Elimina el arma actual sin generar una nueva
func limpiar_arma() -> void:
	if _arma_actual:
		_arma_actual.queue_free()
		_arma_actual = null
	
	_esperando = false
	_temporizador_respawn.stop()

## Verifica si hay un arma actualmente en el spawner
func tiene_arma() -> bool:
	return _arma_actual != null
