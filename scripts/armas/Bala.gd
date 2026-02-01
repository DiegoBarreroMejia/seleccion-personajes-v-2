extends Area2D
class_name Bala

## Proyectil básico que se mueve en línea recta
##
## Se autodestruye al impactar con un cuerpo o al salir de pantalla

# === CONSTANTES ===
const VELOCIDAD_DEFECTO: float = 900.0
const TIEMPO_VIDA_DEFECTO: float = 5.0

# === VARIABLES EXPORTADAS ===
@export var velocidad: float = VELOCIDAD_DEFECTO
@export var dano: int = 1
@export var tiempo_vida: float = TIEMPO_VIDA_DEFECTO

# === VARIABLES PRIVADAS ===
var _velocidad_vector: Vector2 = Vector2.ZERO
var _temporizador_vida: Timer
var _id_jugador_dueno: int = 0
var _destruida: bool = false

# === MÉTODOS PÚBLICOS ===

func establecer_dueno(id_jugador: int) -> void:
	_id_jugador_dueno = id_jugador

# === MÉTODOS DE CICLO DE VIDA ===

func _ready() -> void:
	_configurar_velocidad()
	_configurar_temporizador_vida()
	_conectar_senales()

func _physics_process(delta: float) -> void:
	if _destruida:
		return
	position += _velocidad_vector * delta

# === CONFIGURACIÓN INICIAL ===

func _configurar_velocidad() -> void:
	_velocidad_vector = Vector2.RIGHT.rotated(rotation) * velocidad

func _configurar_temporizador_vida() -> void:
	_temporizador_vida = Timer.new()
	_temporizador_vida.one_shot = true
	_temporizador_vida.wait_time = tiempo_vida
	add_child(_temporizador_vida)
	_temporizador_vida.timeout.connect(_on_tiempo_vida_agotado)
	_temporizador_vida.start()

func _conectar_senales() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	if has_node("VisibleOnScreenNotifier2D"):
		var notificador := $VisibleOnScreenNotifier2D as VisibleOnScreenNotifier2D
		if not notificador.screen_exited.is_connected(_on_screen_exited):
			notificador.screen_exited.connect(_on_screen_exited)

# === COLISIONES ===

func _on_body_entered(body: Node2D) -> void:
	if _destruida:
		return
	
	# Ignorar al jugador que disparó
	if "player_id" in body and body.player_id == _id_jugador_dueno:
		return
	
	# Colisión con paredes/suelo
	if body is TileMap or body is StaticBody2D:
		_destruir()
		return
	
	# Colisión con personaje
	if body.has_method("recibir_dano"):
		body.recibir_dano(dano)
		_destruir()

func _on_screen_exited() -> void:
	_destruir()

func _on_tiempo_vida_agotado() -> void:
	_destruir()

# === DESTRUCCIÓN ===

func _destruir() -> void:
	if _destruida:
		return
	
	_destruida = true
	set_physics_process(false)
	
	# Aquí puedes añadir partículas de impacto en el futuro:
	# var particulas = PARTICULAS_IMPACTO.instantiate()
	# particulas.global_position = global_position
	# get_tree().root.add_child(particulas)
	
	queue_free()
