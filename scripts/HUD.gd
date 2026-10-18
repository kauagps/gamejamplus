extends CanvasLayer

# =====================================================================
# HUD.gd — Godot 4.x
#
# Lembrete de sintaxe (Godot 4): para conectar um SINAL use só o
# Callable, sem `self` e sem aspas:
#     Status.vida_alterada.connect(_on_Status_vida_alterada)
# =====================================================================

# Sinal que o Main escuta para saber qual construção o jogador pediu
# (regra do projeto: "call down, signal up" — o HUD só PEDE, o Main cria)
signal construcao_solicitada(tipo: String)

# Sinal que o Main escuta quando o jogador clica num slot do inventário
signal slot_usado(slot_index: int)


# --- BARRAS (cada frame do sprite = uma porcentagem) ------------------
@onready var barra_vida: AnimatedSprite2D = $ContainerPrincipal/BarraVida
@onready var barra_fome: AnimatedSprite2D = $ContainerPrincipal/BarraFome
@onready var barra_sanidade: AnimatedSprite2D = $ContainerPrincipal/BarraSanidade

# --- CONTADOR DE DIAS (frames "DIA 1" ... "DIA 10") -------------------
@onready var sprite_dias: AnimatedSprite2D = $ContainerPrincipal/Dias

# --- SLOTS DE INVENTÁRIO ----------------------------------------------
@onready var slots_container: Node = $ContainerPrincipal/SlotsInventario
var slots: Array[TextureRect] = []

# --- BOTÕES DE CONSTRUÇÃO ---------------------------------------------
@onready var btn_fogueira: Button = $ContainerPrincipal/BotoesConstrucao/BtnFogueira
@onready var btn_cama: Button = $ContainerPrincipal/BotoesConstrucao/BtnCama
@onready var btn_abrigo: Button = $ContainerPrincipal/BotoesConstrucao/BtnAbrigo

# Ícones dos botões (placeholders — troque o caminho quando tiver a arte)
const ICONE_FOGUEIRA := preload("res://assets/items/placeholder.png")
const ICONE_ABRIGO := preload("res://assets/mapa/House_Yellow.png")

# --- ÍCONES DOS ITENS -------------------------------------------------
# Vêm do scripts/CatalogoItens.gd (fonte única de verdade: o mesmo lugar
# onde o Item.tscn busca o sprite do chão)

# Aviso na tela (ex: "Faltam materiais!"), criado por código
var label_aviso: Label
var timer_aviso: Timer

# Pensamento do personagem (ex: "Está anoitecendo, preciso dormir.").
# É um texto SEPARADO do aviso, com outro estilo e em outro lugar da tela:
# o jogador aprende que dourado no topo = aviso do sistema, azulado no
# rodapé = o personagem pensando.
var label_pensamento: Label
var timer_pensamento: Timer


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
		jogador.dica_interacao.connect(_on_Player_dica_interacao)
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

	# -----------------------------------------------------------------
	# 4) CLIQUE NO SLOT (usar o item: comer, etc.)
	# -----------------------------------------------------------------
	for i in slots.size():
		slots[i].mouse_filter = Control.MOUSE_FILTER_STOP
		slots[i].gui_input.connect(_on_slot_gui_input.bind(i))

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
	# -----------------------------------------------------------------
	_atualizar_barra_discreta(barra_vida, Status.vida, Status.vida_maximo)
	_atualizar_barra_discreta(barra_fome, Status.fome, Status.fome_maximo)
	_atualizar_barra_discreta(barra_sanidade, Status.sanidade, Status.sanidade_maximo)

	# -----------------------------------------------------------------
	# 5) CONTADOR DE DIAS COMEÇA NO "DIA 1"
	# -----------------------------------------------------------------
	atualizar_contador_dias(1)

	# -----------------------------------------------------------------
	# 6) BOTÕES DE CONSTRUÇÃO (só Fogueira e Abrigo são construíveis)
	#    A cama NÃO entra no craft (decisão do time) — deixamos o nó
	#    escondido; se quiser removê-lo de vez, apague no HUD.tscn.
	# -----------------------------------------------------------------
	btn_cama.visible = false

	btn_fogueira.icon = ICONE_FOGUEIRA
	btn_fogueira.expand_icon = true
	btn_fogueira.tooltip_text = "Fogueira (2 madeira)"
	btn_fogueira.pressed.connect(_on_btn_fogueira_pressed)

	btn_abrigo.icon = ICONE_ABRIGO
	btn_abrigo.expand_icon = true
	btn_abrigo.tooltip_text = "Abrigo (2 madeira + 1 pedra)"
	btn_abrigo.pressed.connect(_on_btn_abrigo_pressed)

	_criar_aviso()
	_criar_pensamento()
	_criar_caixa_dialogo()


# =====================================================================
# BOTÕES DE CONSTRUÇÃO
# =====================================================================
func _on_btn_fogueira_pressed() -> void:
	construcao_solicitada.emit("fogueira")

func _on_btn_abrigo_pressed() -> void:
	construcao_solicitada.emit("abrigo")


# =====================================================================
# AVISO NA TELA (criado por código pra não precisar editar o HUD.tscn)
# =====================================================================
func _criar_aviso() -> void:
	label_aviso = Label.new()
	label_aviso.name = "Aviso"  # nome só pra ficar achável no Remote inspector
	label_aviso.visible = false
	label_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_aviso.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	label_aviso.add_theme_font_size_override("font_size", 30)
	label_aviso.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label_aviso.offset_top = 140.0
	label_aviso.offset_bottom = 180.0
	add_child(label_aviso)

	timer_aviso = Timer.new()
	timer_aviso.one_shot = true
	timer_aviso.timeout.connect(_esconder_aviso)
	add_child(timer_aviso)

func mostrar_aviso(texto: String) -> void:
	label_aviso.text = texto
	label_aviso.visible = true
	timer_aviso.start(2.0)

func _esconder_aviso() -> void:
	label_aviso.visible = false


# =====================================================================
# PENSAMENTO DO PERSONAGEM (rodapé, criado por código igual ao aviso)
# =====================================================================
func _criar_pensamento() -> void:
	label_pensamento = Label.new()
	label_pensamento.name = "Pensamento"  # nome só pra achar no Remote inspector
	label_pensamento.visible = false
	label_pensamento.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Azul-claro com CONTORNO escuro: assim o texto fica legível em cima do
	# mapa (grama, água, árvore) sem precisar de painel/fundo atrás.
	label_pensamento.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0))
	label_pensamento.add_theme_color_override("font_outline_color", Color(0.06, 0.07, 0.14, 0.9))
	label_pensamento.add_theme_constant_override("outline_size", 8)
	label_pensamento.add_theme_font_size_override("font_size", 26)
	# Fica no rodapé (o aviso do sistema fica no topo): é o que separa
	# visualmente "o personagem pensando" de "o jogo te avisando".
	label_pensamento.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	label_pensamento.offset_top = -140.0
	label_pensamento.offset_bottom = -100.0
	add_child(label_pensamento)

	timer_pensamento = Timer.new()
	timer_pensamento.one_shot = true
	timer_pensamento.timeout.connect(_esconder_pensamento)
	add_child(timer_pensamento)

# O Main chama isso quando o personagem "pensa" algo (o aviso de que a noite
# está chegando). Fica na tela por alguns segundos e some sozinho.
func mostrar_pensamento(texto: String, duracao: float = 4.0) -> void:
	# Durante uma conversa o pensamento apareceria ATRÁS da caixa de diálogo
	# (os dois ficam no rodapé). Ele é interrompido: a Main insiste de novo
	# quando for a hora.
	if caixa_dialogo != null and caixa_dialogo.visible:
		return

	label_pensamento.text = texto
	label_pensamento.visible = true
	timer_pensamento.start(duracao)

func _esconder_pensamento() -> void:
	label_pensamento.visible = false

# Dica que o Player manda quando ele chega perto de um item ou da casa
func _on_Player_dica_interacao(texto: String) -> void:
	mostrar_aviso(texto)


# =====================================================================
# CAIXA DE DIÁLOGO (rodapé) — conversa com NPC
# =====================================================================
# Construída por código, igual ao aviso e ao pensamento, pra não precisar
# editar o HUD.tscn. Ela tem três informações:
#
#   [ retrato ]   o próprio quadro do sheet do NPC, ampliado 4x
#   Nome          quem está falando
#   Texto         a fala, saindo LETRA POR LETRA (máquina de escrever)
#
# A HUD não decide nada: a Main (dona do dia_atual) escolhe as falas e
# chama abrir_dialogo(). A HUD só desenha e responde se ainda tem página.

# Quantas letras por segundo a máquina de escrever mostra
const VELOCIDADE_DA_ESCRITA: float = 45.0

var caixa_dialogo: PanelContainer
var retrato_dialogo: TextureRect
var nome_dialogo: Label
var texto_dialogo: Label
var indicador_dialogo: Label

var _falas_do_dialogo: Array = []
var _pagina_atual: int = 0
var _tween_texto: Tween = null
var _tween_indicador: Tween = null


func _criar_caixa_dialogo() -> void:
	# --- O painel ---
	caixa_dialogo = PanelContainer.new()
	caixa_dialogo.name = "CaixaDialogo"  # nome só pra achar no Remote inspector
	caixa_dialogo.visible = false
	# Ela não é clicável (avança com E). IGNORE garante que, em outra
	# resolução, ela nunca roube o clique dos botões ou dos slots.
	caixa_dialogo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa_dialogo.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	caixa_dialogo.offset_left = 180.0
	caixa_dialogo.offset_right = -180.0
	caixa_dialogo.offset_top = -290.0
	caixa_dialogo.offset_bottom = -50.0

	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.05, 0.06, 0.12, 0.92)
	fundo.border_color = Color(0.55, 0.6, 0.78, 0.9)
	fundo.set_border_width_all(2)
	fundo.set_corner_radius_all(10)
	fundo.set_content_margin_all(18.0)
	caixa_dialogo.add_theme_stylebox_override("panel", fundo)
	add_child(caixa_dialogo)

	# --- De dentro: [retrato] | [nome / fala / indicador] ---
	var linha := HBoxContainer.new()
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.add_theme_constant_override("separation", 18)
	caixa_dialogo.add_child(linha)

	retrato_dialogo = TextureRect.new()
	retrato_dialogo.name = "Retrato"
	retrato_dialogo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	retrato_dialogo.custom_minimum_size = Vector2(128, 128)
	retrato_dialogo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	retrato_dialogo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# É um quadro de 32x32 do sheet esticado 4x: com Nearest cada pixel
	# vira um quadrado duro (aí o sheet "vira vetor" no olho).
	retrato_dialogo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	linha.add_child(retrato_dialogo)

	var coluna := VBoxContainer.new()
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(coluna)

	nome_dialogo = Label.new()
	nome_dialogo.name = "Nome"
	nome_dialogo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nome_dialogo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	nome_dialogo.add_theme_font_size_override("font_size", 30)
	coluna.add_child(nome_dialogo)

	texto_dialogo = Label.new()
	texto_dialogo.name = "Texto"
	texto_dialogo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texto_dialogo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Fala longa quebra linha sozinha em vez de vazar da caixa
	texto_dialogo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto_dialogo.add_theme_color_override("font_color", Color(0.93, 0.95, 1.0))
	texto_dialogo.add_theme_font_size_override("font_size", 26)
	coluna.add_child(texto_dialogo)

	indicador_dialogo = Label.new()
	indicador_dialogo.name = "Indicador"
	indicador_dialogo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicador_dialogo.visible = false
	indicador_dialogo.text = "▼  aperte E"
	indicador_dialogo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	indicador_dialogo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	indicador_dialogo.add_theme_font_size_override("font_size", 20)
	coluna.add_child(indicador_dialogo)


# A Main chama isto quando a conversa começa.
# "paginas" é a lista de falas (cada uma é uma tela da conversa).
func abrir_dialogo(nome: String, paginas: Array, retrato: Texture2D) -> void:
	_falas_do_dialogo = paginas
	_pagina_atual = 0

	nome_dialogo.text = nome
	retrato_dialogo.texture = retrato
	retrato_dialogo.visible = (retrato != null)

	# O pensamento do rodapé ficaria atrás da caixa: some enquanto fala
	_esconder_pensamento()

	caixa_dialogo.visible = true
	_mostrar_pagina()


# Avança uma página. Devolve false quando a conversa acabou — aí quem
# fecha a caixa é a Main.
func avancar_dialogo() -> bool:
	if not caixa_dialogo.visible or _falas_do_dialogo.is_empty():
		return false

	# Ainda está escrevendo? Então o E só completa a frase (clássico):
	# o jogador que lê rápido não é obrigado a esperar.
	if texto_dialogo.visible_characters < _texto_da_pagina().length():
		_completar_escrita()
		return true

	if _pagina_atual + 1 < _falas_do_dialogo.size():
		_pagina_atual += 1
		_mostrar_pagina()
		return true

	return false


func fechar_dialogo() -> void:
	caixa_dialogo.visible = false
	indicador_dialogo.visible = false
	_falas_do_dialogo = []
	_pagina_atual = 0
	if _tween_texto != null:
		_tween_texto.kill()
	if _tween_indicador != null:
		_tween_indicador.kill()


func dialogo_aberto() -> bool:
	return caixa_dialogo.visible


func _texto_da_pagina() -> String:
	if _falas_do_dialogo.is_empty():
		return ""
	return str(_falas_do_dialogo[_pagina_atual])


func _mostrar_pagina() -> void:
	var texto: String = _texto_da_pagina()
	texto_dialogo.text = texto
	texto_dialogo.visible_characters = 0
	indicador_dialogo.visible = false

	if _tween_texto != null:
		_tween_texto.kill()

	# A duração sai do tamanho da fala: frase curta não fica arrastada e
	# frase longa não sai de uma vez.
	var duracao: float = maxf(0.2, texto.length() / VELOCIDADE_DA_ESCRITA)
	_tween_texto = create_tween()
	_tween_texto.tween_property(texto_dialogo, "visible_characters", texto.length(), duracao)
	_tween_texto.finished.connect(_on_pagina_escrita)


func _on_pagina_escrita() -> void:
	indicador_dialogo.visible = true
	if _tween_indicador != null:
		_tween_indicador.kill()
	indicador_dialogo.modulate.a = 1.0
	_tween_indicador = create_tween().set_loops()
	_tween_indicador.tween_property(indicador_dialogo, "modulate:a", 0.2, 0.5)
	_tween_indicador.tween_property(indicador_dialogo, "modulate:a", 1.0, 0.5)


func _completar_escrita() -> void:
	if _tween_texto != null:
		_tween_texto.kill()  # killed não emite "finished"
	texto_dialogo.visible_characters = _texto_da_pagina().length()
	_on_pagina_escrita()


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
	# travado no último frame.
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

	if item_name == "":
		# Slot esvaziado (ex: item gasto numa construção)
		slot.texture = null
		return

	var icone: Texture2D = CatalogoItens.icone(item_name)
	if icone == null:
		# Item fora do catálogo -> cinza provisório + aviso no log
		push_warning("HUD: o item '%s' não está no CatalogoItens!" % item_name)
		icone = preload("res://assets/items/placeholder.png")
	slot.texture = icone

# Clique com o botão esquerdo num slot = "usar este item".
# A HUD não decide nada: ela só avisa o Main (regra call down, signal up).
func _on_slot_gui_input(evento: InputEvent, indice: int) -> void:
	if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		slot_usado.emit(indice)
