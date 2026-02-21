extends CanvasLayer

## Muestra el temporizador 3 → 2 → 1 → YA antes de iniciar la partida.
##
## Cuando termina emite la señal countdown_terminado para que MapaController
## desbloquee a los jugadores.

signal countdown_terminado

const INTERVALO: float = 0.8   # Segundos entre cada número
const ALTO_DESEADO: float = 200.0  # Altura en píxeles a la que se normalizan todos los sprites

const SPRITES: Array[String] = [
	"res://assets/sprites/partida/3.png",
	"res://assets/sprites/partida/2.png",
	"res://assets/sprites/partida/1.png",
	"res://assets/sprites/partida/YA.png",
]

@onready var _sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	_sprite.visible = false
	_iniciar()

func _iniciar() -> void:
	for ruta in SPRITES:
		var textura := load(ruta) as Texture2D
		if not textura:
			push_error("Countdown: No se pudo cargar %s" % ruta)
			continue

		_sprite.texture = textura
		# Escalar para que todos los sprites tengan el mismo alto
		var factor := ALTO_DESEADO / textura.get_height()
		_sprite.scale = Vector2(factor, factor)
		_sprite.visible = true

		await get_tree().create_timer(INTERVALO).timeout

		if not is_inside_tree():
			return

	countdown_terminado.emit()
	queue_free()
