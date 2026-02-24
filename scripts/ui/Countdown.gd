extends CanvasLayer

signal countdown_terminado

const INTERVALO: float = 0.8
const ALTO_DESEADO: float = 200.0

const SFX_YA: AudioStream = preload("res://assets/sonidos/partida/sonido_YA.wav")

const SPRITES: Array[String] = [
	"res://assets/sprites/partida/3.png",
	"res://assets/sprites/partida/2.png",
	"res://assets/sprites/partida/1.png",
	"res://assets/sprites/partida/YA.png",
]

@onready var _sprite: Sprite2D = $Sprite2D

# Oculta sprite e inicia la cuenta regresiva
func _ready() -> void:
	_sprite.visible = false
	_iniciar()

# Muestra 3, 2, 1, YA con sfx y emite senal al terminar
func _iniciar() -> void:
	for ruta in SPRITES:
		var textura := load(ruta) as Texture2D
		if not textura:
			push_error("Countdown: No se pudo cargar %s" % ruta)
			continue

		_sprite.texture = textura
		var factor := ALTO_DESEADO / textura.get_height()
		_sprite.scale = Vector2(factor, factor)
		_sprite.visible = true

		if ruta == SPRITES[-1]:
			var sfx := AudioStreamPlayer.new()
			sfx.stream = SFX_YA
			sfx.bus = "SFX"
			add_child(sfx)
			sfx.play()

		await get_tree().create_timer(INTERVALO).timeout

		if not is_inside_tree():
			return

	countdown_terminado.emit()
	queue_free()
