extends Area2D

const VELOCIDAD_DEFECTO: float = 600.0
const TIEMPO_VIDA_DEFECTO: float = 5.0
const ANIMACION_FPS: float = 30.0

const SPRITES_FUEGO: Array[Texture2D] = [
	preload("res://assets/sprites/armas/bola_fuego/2.png"),
	preload("res://assets/sprites/armas/bola_fuego/3.png"),
	preload("res://assets/sprites/armas/bola_fuego/4.png"),
	preload("res://assets/sprites/armas/bola_fuego/5.png"),
	preload("res://assets/sprites/armas/bola_fuego/6.png"),
	preload("res://assets/sprites/armas/bola_fuego/7.png"),
	preload("res://assets/sprites/armas/bola_fuego/8.png"),
	preload("res://assets/sprites/armas/bola_fuego/9.png"),
	preload("res://assets/sprites/armas/bola_fuego/10.png"),
	preload("res://assets/sprites/armas/bola_fuego/11.png"),
	preload("res://assets/sprites/armas/bola_fuego/12.png"),
	preload("res://assets/sprites/armas/bola_fuego/13.png"),
	preload("res://assets/sprites/armas/bola_fuego/14.png"),
	preload("res://assets/sprites/armas/bola_fuego/15.png"),
	preload("res://assets/sprites/armas/bola_fuego/16.png"),
	preload("res://assets/sprites/armas/bola_fuego/17.png"),
	preload("res://assets/sprites/armas/bola_fuego/18.png"),
	preload("res://assets/sprites/armas/bola_fuego/19.png"),
	preload("res://assets/sprites/armas/bola_fuego/20.png"),
	preload("res://assets/sprites/armas/bola_fuego/21.png"),
	preload("res://assets/sprites/armas/bola_fuego/22.png"),
	preload("res://assets/sprites/armas/bola_fuego/23.png"),
	preload("res://assets/sprites/armas/bola_fuego/24.png"),
	preload("res://assets/sprites/armas/bola_fuego/25.png"),
	preload("res://assets/sprites/armas/bola_fuego/26.png"),
	preload("res://assets/sprites/armas/bola_fuego/27.png"),
	preload("res://assets/sprites/armas/bola_fuego/28.png"),
	preload("res://assets/sprites/armas/bola_fuego/29.png"),
	preload("res://assets/sprites/armas/bola_fuego/30.png"),
	preload("res://assets/sprites/armas/bola_fuego/31.png"),
	preload("res://assets/sprites/armas/bola_fuego/32.png"),
	preload("res://assets/sprites/armas/bola_fuego/33.png"),
	preload("res://assets/sprites/armas/bola_fuego/34.png"),
	preload("res://assets/sprites/armas/bola_fuego/35.png"),
	preload("res://assets/sprites/armas/bola_fuego/36.png"),
	preload("res://assets/sprites/armas/bola_fuego/37.png"),
	preload("res://assets/sprites/armas/bola_fuego/38.png"),
	preload("res://assets/sprites/armas/bola_fuego/39.png"),
	preload("res://assets/sprites/armas/bola_fuego/40.png"),
	preload("res://assets/sprites/armas/bola_fuego/41.png"),
	preload("res://assets/sprites/armas/bola_fuego/42.png"),
	preload("res://assets/sprites/armas/bola_fuego/43.png"),
	preload("res://assets/sprites/armas/bola_fuego/44.png"),
	preload("res://assets/sprites/armas/bola_fuego/45.png"),
	preload("res://assets/sprites/armas/bola_fuego/46.png"),
	preload("res://assets/sprites/armas/bola_fuego/47.png"),
	preload("res://assets/sprites/armas/bola_fuego/48.png"),
	preload("res://assets/sprites/armas/bola_fuego/49.png"),
	preload("res://assets/sprites/armas/bola_fuego/50.png"),
	preload("res://assets/sprites/armas/bola_fuego/51.png"),
	preload("res://assets/sprites/armas/bola_fuego/52.png"),
	preload("res://assets/sprites/armas/bola_fuego/53.png"),
	preload("res://assets/sprites/armas/bola_fuego/54.png"),
	preload("res://assets/sprites/armas/bola_fuego/55.png"),
	preload("res://assets/sprites/armas/bola_fuego/56.png"),
	preload("res://assets/sprites/armas/bola_fuego/57.png"),
	preload("res://assets/sprites/armas/bola_fuego/58.png"),
	preload("res://assets/sprites/armas/bola_fuego/59.png"),
	preload("res://assets/sprites/armas/bola_fuego/60.png"),
]

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

# Configura animacion, velocidad, temporizador y senales
func _ready() -> void:
	_configurar_animacion()
	_configurar_velocidad()
	_configurar_temporizador_vida()
	_conectar_senales()

# Mueve el proyectil en linea recta
func _physics_process(delta: float) -> void:
	if _destruida:
		return
	position += _velocidad_vector * delta

# Crea los sprite frames de la animacion de fuego
func _configurar_animacion() -> void:
	var sprite_frames := SpriteFrames.new()
	sprite_frames.remove_animation(&"default")
	sprite_frames.add_animation(&"fuego")
	sprite_frames.set_animation_speed(&"fuego", ANIMACION_FPS)
	sprite_frames.set_animation_loop(&"fuego", true)

	for textura in SPRITES_FUEGO:
		sprite_frames.add_frame(&"fuego", textura)

	$AnimatedSprite2D.sprite_frames = sprite_frames
	$AnimatedSprite2D.play(&"fuego")

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

# Destruye el proyectil
func _destruir() -> void:
	if _destruida:
		return

	_destruida = true
	set_physics_process(false)
	queue_free()
