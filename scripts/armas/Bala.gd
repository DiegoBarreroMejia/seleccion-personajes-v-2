extends Area2D
class_name Bala

const VELOCIDAD_DEFECTO: float = 1200.0
const TIEMPO_VIDA_DEFECTO: float = 5.0

@export var velocidad: float = VELOCIDAD_DEFECTO
@export var dano: int = 1
@export var tiempo_vida: float = TIEMPO_VIDA_DEFECTO

var _velocidad_vector: Vector2 = Vector2.ZERO
var _temporizador_vida: Timer
var _id_jugador_dueno: int = 0
var _destruida: bool = false

# Establece el id del jugador que disparo
func establecer_dueno(id_jugador: int) -> void:
	_id_jugador_dueno = id_jugador

# Configura velocidad, temporizador y senales
func _ready() -> void:
	_configurar_velocidad()
	_configurar_temporizador_vida()
	_conectar_senales()

# Mueve la bala en linea recta
func _physics_process(delta: float) -> void:
	if _destruida:
		return
	position += _velocidad_vector * delta

# Calcula el vector de velocidad segun la rotacion
func _configurar_velocidad() -> void:
	_velocidad_vector = Vector2.RIGHT.rotated(rotation) * velocidad

# Crea el temporizador de vida
func _configurar_temporizador_vida() -> void:
	_temporizador_vida = Timer.new()
	_temporizador_vida.one_shot = true
	_temporizador_vida.wait_time = tiempo_vida
	add_child(_temporizador_vida)
	_temporizador_vida.timeout.connect(_on_tiempo_vida_agotado)
	_temporizador_vida.start()

# Conecta senales de colision y pantalla
func _conectar_senales() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if has_node("VisibleOnScreenNotifier2D"):
		var notificador := $VisibleOnScreenNotifier2D as VisibleOnScreenNotifier2D
		if not notificador.screen_exited.is_connected(_on_screen_exited):
			notificador.screen_exited.connect(_on_screen_exited)

# Aplica dano o se destruye al colisionar
func _on_body_entered(body: Node2D) -> void:
	if _destruida:
		return

	if "player_id" in body and body.player_id == _id_jugador_dueno:
		return

	if body.has_method("recibir_dano"):
		body.recibir_dano(dano, global_position)
		_destruir()
		return

	if body is TileMap or body is StaticBody2D:
		_destruir()
		return

# Se destruye al salir de pantalla
func _on_screen_exited() -> void:
	_destruir()

# Se destruye al agotar tiempo de vida
func _on_tiempo_vida_agotado() -> void:
	_destruir()

# Destruye la bala
func _destruir() -> void:
	if _destruida:
		return

	_destruida = true
	set_physics_process(false)
	queue_free()
