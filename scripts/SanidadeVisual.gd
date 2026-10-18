class_name SanidadeVisual
extends CanvasLayer

# =====================================================================
# SANIDADE NA TELA — o mundo "adoece" junto com a cabeça do John.
#
# Estrutura: esta CanvasLayer tem UM filho, um ColorRect que cobre a tela e
# carrega o shader assets/shaders/sanidade.gdshader. O shader LÊ o que já
# foi desenhado embaixo (a tela do jogo) e redesenha com três estragos —
# bordas fechando, ondulação e granulado — todos crescendo com a
# "intensidade" que a Main manda.
#
# Por que ele fica ANTES da HUD na árvore, com o mesmo layer dela: quando
# dois CanvasLayer têm o mesmo layer, quem manda é a ordem na árvore. Assim
# a HUD é desenhada DEPOIS e fica limpa — no meio de um surto o jogador
# ainda precisa conseguir ler a própria barra de sanidade.
#
# O TREMOR mora aqui também, mas ele não encosta em nenhum nó do mundo: ele
# escreve no `offset` do Camera2D. O offset é somado POR CIMA do "seguir o
# jogador", então dá pra tremer a tela sem quebrar a câmera e sem precisar
# mexer no Player.tscn.
#
# Regra do projeto: este nó não decide nada. Quem calcula a severidade é a
# Main, porque só ela sabe quando o mundo está parado numa cena.
# =====================================================================

## Tremor máximo da câmera (em pixels), com a sanidade já zerando.
@export var tremor_maximo: float = 7.0

@onready var tela: ColorRect = $Tela

var _material: ShaderMaterial
var _severidade: float = 0.0
var _tempo: float = 0.0


func _ready() -> void:
	_material = tela.material as ShaderMaterial
	_aplicar()             # nasce limpo (senão o 1º frame já vem torto)
	_soltar_a_camera()


func _process(delta: float) -> void:
	_tempo += delta
	_aplicar()
	_tremer()


## 0.0 = cabeça boa (nada acontece) ... 1.0 = sanidade zerando.
## A Main chama isto TODO FRAME, enquanto o mundo estiver correndo.
func definir_severidade(valor: float) -> void:
	_severidade = clampf(valor, 0.0, 1.0)


func _aplicar() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("intensidade", _severidade)
	_material.set_shader_parameter("tempo", _tempo)


# O tremor cresce com a severidade, e a FREQUÊNCIA também: é um sorteio novo
# a cada frame (60 por segundo), então quanto maior a força, mais "elétrico"
# o mundo fica. Com a cabeça sã a câmera volta pro lugar exato (offset
# zero) — importante pra não sobrar um tremorzinho pra sempre.
func _tremer() -> void:
	if _severidade <= 0.0:
		_soltar_a_camera()
		return

	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null:
		return

	var forca: float = _severidade * tremor_maximo
	camera.offset = Vector2(randf_range(-forca, forca), randf_range(-forca, forca))


# Devolve a câmera ao lugar (só age se ela estiver fora do lugar, pra não
# ficar escrevendo no offset todo frame à toa)
func _soltar_a_camera() -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera != null and camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO
