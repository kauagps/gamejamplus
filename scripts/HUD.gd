extends CanvasLayer

# =====================================================================
# HUD.gd — Godot 4.x
#
# ATENÇÃO: a causa dos seus erros de connect era a SINTAXE:
#
#   ERRADO (sintaxe de Godot 3):
#       Status.vida_alterada.connect(self, "_on_Status_vida_alterada")
#
#   CERTO (sintaxe de Godot 4):
#       Status.vida_alterada.connect(_on_Status_vida_alterada)
#
# No Godot 4, o connect() de um SINAL recebe SOMENTE um Callable.
# Escrever apenas o nome do método (sem aspas e sem o self) já cria
# um Callable apontando para este script.
# =====================================================================


# --- BARRAS (cada frame do sprite = uma porcentagem) ------------------
# Cada barra usa a animação que está definida NO PRÓPRIO NÓ dentro do
# HUD.tscn (BarraFome -> "fome", BarraSanidade -> "sanidade", etc.),
# por isso o código não precisa do nome da animação aqui.
@onready var barra_vida: AnimatedSprite2D = $ContainerPrincipal/BarraVida
@onready var barra_fome: AnimatedSprite2D = $ContainerPrincipal/BarraFome
@onready var barra_sanidade: AnimatedSprite2D = $ContainerPrincipal/BarraSanidade

# --- CONTADOR DE DIAS (frames "DIA 1" ... "DIA 10") -------------------
@onready var sprite_dias: AnimatedSprite2D = $ContainerPrincipal/Dias

# --- SLOTS DE INVENTÁRIO ----------------------------------------------
@onready var slots_container: Node = $ContainerPrincipal/SlotsInventario
var slots: Array[TextureRect] = []

# --- ÍCONES DOS ITENS -------------------------------------------------
# W_Idle = tronco (madeira) | M_Idle = carne (comida) | placeholder = cinza
var item_icons: Dictionary = {
	"madeira": preload("res://assets/items/W_Idle.png"),
	"comida": preload("res://assets/items/M_Idle.png"),
	"pedra": preload("res://assets/items/placeholder.png"),
}


func _ready() -> void:
	# -----------------------------------------------------------------
	# 1) SINAIS DO AUTOLOAD "STATUS" (vida, fome, sanidade)
	# -----------------------------------------------------------------
	Status.vida_alterada.connect(_on_Status_vida_alterada)
	Status.fome_alterada.connect(_on_Status_fome_alterada)
	Status.sanidade_alterada.connect(_on_Status_sanidade_alterada)

	# -----------------------------------------------------------------
	# 2) SINAL DO JOGADOR (inventário alterado)
	# -----------------------------------------------------------------
	var jogador: Node2D = get_tree().get_first_node_in_group("jogador")
	if jogador:
		jogador.inventario_alterado.connect(_on_Player_inventario_alterado)
	else:
		push_error("HUD: Jogador não encontrado no grupo 'jogador'!")

	# -----------------------------------------------------------------
	# 3) COLETAR OS 3 SLOTS DE INVENTÁRIO (TextureRect)
	#    (os "FundoSlot" são Sprite2D, então o filtro abaixo os ignora)
	# -----------------------------------------------------------------
	if slots_container:
		for child in slots_container.get_children():
			if child is TextureRect:
				slots.append(child)
		if slots.size() != 3:
			push_error("HUD: esperava 3 slots TextureRect, encontrou ", slots.size())
	else:
		push_error("HUD: não achei '$ContainerPrincipal/SlotsInventario'")

	for slot in slots:
		# Ícone 64x64 centralizado dentro do slot de 80x80
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# O GridContainer dos slots está girado -90° (barra vertical);
		# giramos cada slot +90° em volta do centro para o ícone ficar
		# "em pé". Se preferir ajustar isso direto no editor, apague
		# as 2 linhas abaixo.
		slot.pivot_offset = slot.custom_minimum_size / 2.0
		slot.rotation = PI / 2.0

	# -----------------------------------------------------------------
	# 4) PINTAR O ESTADO ATUAL DAS BARRAS
	#    (o Status só emite sinal quando o valor MUDA; sem este bloco
	#    as barras ficariam no frame 0 até a primeira alteração)
	# -----------------------------------------------------------------
	_atualizar_barra_discreta(barra_vida, Status.vida, Status.vida_maximo)
	_atualizar_barra_discreta(barra_fome, Status.fome, Status.fome_maximo)
	_atualizar_barra_discreta(barra_sanidade, Status.sanidade, Status.sanidade_maximo)

	# -----------------------------------------------------------------
	# 5) CONTADOR DE DIAS COMEÇA NO "DIA 1"
	# -----------------------------------------------------------------
	atualizar_contador_dias(1)


# =====================================================================
# BARRAS DE VIDA / FOME / SANIDADE
# =====================================================================
func _on_Status_vida_alterada(valor_atual: float, valor_maximo: float) -> void:
	_atualizar_barra_discreta(barra_vida, valor_atual, valor_maximo)

func _on_Status_fome_alterada(valor_atual: float, valor_maximo: float) -> void:
	_atualizar_barra_discreta(barra_fome, valor_atual, valor_maximo)

func _on_Status_sanidade_alterada(valor_atual: float, valor_maximo: float) -> void:
	_atualizar_barra_discreta(barra_sanidade, valor_atual, valor_maximo)

# Escolhe o frame certo da barra. Nos seus sprites o frame 0 é "cheio"
# (100%) e o último frame é "vazio" (0%), por isso o (1.0 - ratio).
func _atualizar_barra_discreta(barra: AnimatedSprite2D, valor_atual: float, valor_maximo: float) -> void:
	if valor_maximo <= 0.0:
		return  # proteção contra divisão por zero

	var frame_count: int = barra.sprite_frames.get_frame_count(barra.animation)
	if frame_count == 0:
		push_warning("HUD: a barra '%s' está sem frames configurados!" % barra.name)
		return

	var ratio: float = clamp(valor_atual / valor_maximo, 0.0, 1.0)
	var indice: int = clampi(int(round((1.0 - ratio) * (frame_count - 1))), 0, frame_count - 1)

	# ATENÇÃO à ordem: stop() reseta o frame para 0, então paramos
	# PRIMEIRO e só depois definimos o frame que queremos mostrar.
	barra.stop()
	barra.frame = indice


# =====================================================================
# CONTADOR DE DIAS
# O Main.gd chama esta função quando amanhece (ou depois de dormir).
# =====================================================================
func atualizar_contador_dias(dia: int) -> void:
	var frame_count: int = sprite_dias.sprite_frames.get_frame_count(sprite_dias.animation)
	if frame_count == 0:
		push_warning("HUD: o sprite 'Dias' está sem frames configurados!")
		return

	# frame 0 = "DIA 1" -> subtrai 1. Depois do DIA 10 o sprite fica
	# travado no último frame (quando tiver mais arte, é só adicionar
	# mais frames na animação "dias" do ui.tres).
	var indice: int = clampi(dia - 1, 0, frame_count - 1)

	sprite_dias.stop()
	sprite_dias.frame = indice


# =====================================================================
# INVENTÁRIO
# =====================================================================
func _on_Player_inventario_alterado(slot_index: int, item_name: String) -> void:
	if slot_index >= slots.size():
		push_error("HUD: índice de slot inválido: ", slot_index)
		return

	var slot: TextureRect = slots[slot_index]
	if item_icons.has(item_name):
		slot.texture = item_icons[item_name]
	else:
		# Item sem ícone cadastrado -> cinza provisório
		slot.texture = preload("res://assets/items/placeholder.png")
