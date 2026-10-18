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
@onready var barra_fome: AnimatedSprite2D = $ContainerPrincipal/BarraFome
@onready var barra_sanidade: AnimatedSprite2D = $ContainerPrincipal/BarraSanidade

# --- CONTADOR DE DIAS (frames "DIA 1" ... "DIA 10") -------------------
@onready var sprite_dias: AnimatedSprite2D = $ContainerPrincipal/Dias

# --- SLOTS DE INVENTÁRIO ----------------------------------------------
# É um GridContainer: tingir ELE pinta o conjunto (fundo + ícones), que é o
# que o modo largar precisa (tingir só o ícone quase não aparecia).
@onready var slots_container: GridContainer = $ContainerPrincipal/SlotsInventario
var slots: Array[TextureRect] = []

# --- BOTÕES DE CONSTRUÇÃO ---------------------------------------------
@onready var btn_fogueira: Button = $ContainerPrincipal/BotoesConstrucao/BtnFogueira
@onready var btn_cama: Button = $ContainerPrincipal/BotoesConstrucao/BtnCama
@onready var btn_abrigo: Button = $ContainerPrincipal/BotoesConstrucao/BtnAbrigo

# Ícones dos botões (placeholders — troque o caminho quando tiver a arte)
const ICONE_FOGUEIRA := preload("res://assets/items/placeholder.png")
const ICONE_ABRIGO := preload("res://assets/mapa/House_Yellow.png")

# --- PREÇO DAS CONSTRUÇÕES (a linha embaixo de cada botão) ------------
# Os botões são só ícones: sem o PREÇO e sem dizer que ali é o menu de
# construção, o jogador não descobre. Tudo aqui é criado por CÓDIGO (igual
# ao aviso, ao pensamento e ao painel do barco), então mexer no preço não
# exige abrir o HUD.tscn.
#
# A HUD NÃO conhece as receitas: quem manda nome + custo de cada construção
# é a Main (dona do RECEITAS), no _ready dela — ver definir_custo_de_construcao.
const TITULO_DA_CONSTRUCAO: String = "CONSTRUIR"
const TAMANHO_ICONE_PRECO: float = 26.0
const COR_DO_PRECO_OK: Color = Color(0.95, 0.96, 1.0)
const COR_DO_PRECO_FALTA: Color = Color(1.0, 0.5, 0.5)
const COR_DO_BOTAO_SEM_MATERIAL: Color = Color(0.62, 0.62, 0.68)

# tipo da construção -> Button (o "tipo" é o mesmo do sinal construcao_solicitada)
var _botoes_de_construcao: Dictionary = {}
# tipo -> lista das peças do preço: {"item", "precisa", "numero", "icone"}
var _pecas_do_preco: Dictionary = {}

# --- ÍCONES DOS ITENS -------------------------------------------------
# Vêm do scripts/CatalogoItens.gd (fonte única de verdade: o mesmo lugar
# onde o Item.tscn busca o sprite do chão)

# Aviso na tela (ex: "Faltam materiais!"), criado por código
var label_aviso: Label
var timer_aviso: Timer

# Pensamento do personagem (ex: "Está anoitecendo, preciso dormir.").
# É um texto SEPARADO do aviso, com outro estilo e em outro lugar da tela:
# o jogador aprende que dourado no topo = aviso do sistema, e azulado em
# cima da cabeça do John = o personagem pensando.
var label_pensamento: Label
var timer_pensamento: Timer

# A HUD precisa do jogador pra saber ONDE colocar o pensamento (ele fica em
# cima da cabeça, acompanhando a câmera — ver _posicionar_pensamento).
var jogador: Node2D = null

# A "caixa invisível" do pensamento. O texto é centralizado na horizontal e
# cresce pra CIMA (daí o alinhamento embaixo), como um balão de fala.
const LARGURA_PENSAMENTO: float = 700.0
const ALTURA_PENSAMENTO: float = 90.0

# Altura (em pixels do MUNDO, não da tela) do fundo do balão acima dos pés
# do John. O sprite dele ocupa de -31 (topo da cabeça) até +1, então 80
# deixa o texto bem acima da cabeça, com um vão confortável.
const ALTURA_ACIMA_DA_CABECA: float = 80.0

# --- PAINEL DO BARCO (flutuante, em cima dele) ------------------------
# Mostra o que ainda falta pra consertar (ícone + quantidade, com as MESMAS
# artes do inventário) e se o John tem o que entregar. É criado por código,
# como o aviso e o pensamento, e se posiciona pela conversão mundo -> tela.
# A HUD não decide nada: a Main manda os números, a posição e o estado.
const ALTURA_ACIMA_DO_BARCO: float = 108.0  # vão entre a base do barco e o painel
const TAMANHO_ICONE_BARCO: float = 46.0     # lado do ícone de madeira/pedra

var painel_barco: PanelContainer
var estilo_painel_barco: StyleBoxFlat
var label_falta_madeira: Label
var label_falta_pedra: Label
var label_instrucao_barco: Label
var _posicao_do_barco: Vector2 = Vector2.ZERO
var _painel_do_barco_na_tela: bool = false


func _ready() -> void:
	# -----------------------------------------------------------------
	# 1) SINAIS DO AUTOLOAD "STATUS" (vida, fome, sanidade)
	
	Status.fome_alterada.connect(_on_Status_fome_alterada)
	Status.sanidade_alterada.connect(_on_Status_sanidade_alterada)

	# -----------------------------------------------------------------
	# 2) SINAL DO JOGADOR (inventário alterado)
	# -----------------------------------------------------------------
	jogador = get_tree().get_first_node_in_group("jogador")
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

	# De qual construção é cada botão. É este mapa que permite a Main mandar
	# o preço só pelo TIPO ("fogueira") e a HUD saber onde escrever. O tooltip
	# e a linha de preço de verdade chegam depois, da Main (ver
	# definir_custo_de_construcao): aqui só o que não depende da receita.
	_botoes_de_construcao = {
		"fogueira": btn_fogueira,
		"abrigo": btn_abrigo,
	}

	btn_fogueira.icon = ICONE_FOGUEIRA
	btn_fogueira.expand_icon = true
	btn_fogueira.pressed.connect(_on_btn_fogueira_pressed)

	btn_abrigo.icon = ICONE_ABRIGO
	btn_abrigo.expand_icon = true
	btn_abrigo.pressed.connect(_on_btn_abrigo_pressed)

	# O título que avisa que estes botões do topo são pra CONSTRUIR
	_criar_titulo_da_construcao()

	_criar_aviso()
	_criar_pensamento()
	_criar_caixa_dialogo()
	_criar_painel_barco()


# =====================================================================
# BOTÕES DE CONSTRUÇÃO
# =====================================================================
func _on_btn_fogueira_pressed() -> void:
	construcao_solicitada.emit("fogueira")

func _on_btn_abrigo_pressed() -> void:
	construcao_solicitada.emit("abrigo")


# =====================================================================
# PREÇO DAS CONSTRUÇÕES (embaixo dos botões do topo)
# =====================================================================
# A Main chama isto no _ready dela, uma vez por receita do RECEITAS. A partir
# daí a HUD sabe o nome, o preço e a descrição de cada botão — e repinta tudo
# sozinha quando o inventário muda (ver _on_Player_inventario_alterado).
#
#   tipo  = a mesma chave do sinal construcao_solicitada ("fogueira")
#   nome  = como o jogador conhece a construção ("Fogueira")
#   custo = lista de nomes de item, COM repetição: ["madeira","madeira","pedra"]
func definir_custo_de_construcao(tipo: String, nome: String, custo: Array) -> void:
	if not _botoes_de_construcao.has(tipo):
		# Construção nova no RECEITAS sem botão aqui: melhor avisar do que
		# ficar em silêncio e o preço nunca aparecer.
		push_warning("HUD: não tenho botão pra construção '%s'" % tipo)
		return

	var botao: Button = _botoes_de_construcao[tipo]

	# Agrupa material repetido: ["madeira","madeira","pedra"] vira
	# [(madeira, 2), (pedra, 1)] — assim aparece "2 madeira" em vez de dois
	# ícones de madeira lado a lado.
	var agrupado: Array = []  # Array de [nome_item, quantidade]
	for item in custo:
		var achou: bool = false
		for par in agrupado:
			if par[0] == item:
				par[1] += 1
				achou = true
				break
		if not achou:
			agrupado.append([item, 1])

	# A linha de preço: [ícone]2   [ícone]1
	var linha := HBoxContainer.new()
	linha.name = "Preco" + tipo.capitalize()
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	linha.add_theme_constant_override("separation", 10)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var pecas: Array = []
	for par in agrupado:
		pecas.append(_criar_peca_do_preco(linha, par[0], par[1]))
	_pecas_do_preco[tipo] = pecas

	# Entra no MESMO VBox do botão, logo DEPOIS dele: assim o preço anda
	# junto se você reordenar os botões no editor (e o BtnCama, escondido,
	# não atrapalha — container ignora filho invisível).
	botao.get_parent().add_child(linha)
	botao.get_parent().move_child(linha, botao.get_index() + 1)

	# A descrição (tooltip) sai do MESMO custo: uma fonte só de verdade —
	# mudar o RECEITAS no Main muda o preço e o texto de uma vez.
	botao.tooltip_text = "%s — %s.\nClique pra construir: a prévia aparece à sua frente, E confirma e Esc cancela." % [nome, _texto_do_custo(agrupado)]

	_atualizar_precos()


# Uma peça do preço: o ícone do material (a MESMA arte do slot do inventário)
# e quanto precisa. Devolve o dicionário que o _atualizar_precos repinta.
func _criar_peca_do_preco(pai: HBoxContainer, item: String, quantidade: int) -> Dictionary:
	var grupo := HBoxContainer.new()
	grupo.add_theme_constant_override("separation", 2)
	pai.add_child(grupo)

	var icone := TextureRect.new()
	icone.texture = _recortar_arte(CatalogoItens.icone(item))
	icone.custom_minimum_size = Vector2(TAMANHO_ICONE_PRECO, TAMANHO_ICONE_PRECO)
	icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icone.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grupo.add_child(icone)

	var numero := Label.new()
	numero.text = str(quantidade)
	numero.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	numero.add_theme_font_size_override("font_size", 22)
	numero.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.09, 0.95))
	numero.add_theme_constant_override("outline_size", 6)
	grupo.add_child(numero)

	return {"item": item, "precisa": quantidade, "numero": numero, "icone": icone}


# "2 madeira + 1 pedra" (o custo já agrupado, sem repetição)
func _texto_do_custo(agrupado: Array) -> String:
	var partes := PackedStringArray()
	for par in agrupado:
		partes.append("%d %s" % [par[1], par[0]])
	return " + ".join(partes)


# O título que diz o que aqueles botões do topo fazem. Entra como PRIMEIRO
# filho do VBox pra empurrar os botões pra baixo dele.
func _criar_titulo_da_construcao() -> void:
	var botoes: Control = btn_fogueira.get_parent()

	var titulo := Label.new()
	titulo.name = "TituloConstruir"  # nome só pra achar no Remote inspector
	titulo.text = TITULO_DA_CONSTRUCAO
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Mesmo esquema do pensamento: cor clara + contorno escuro, pra ler em
	# cima do mapa (grama, água, árvore) sem precisar de painel atrás.
	titulo.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	titulo.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.09, 0.95))
	titulo.add_theme_constant_override("outline_size", 8)
	titulo.add_theme_font_size_override("font_size", 24)
	botoes.add_child(titulo)
	botoes.move_child(titulo, 0)


# Repinta o preço conforme a MOCHILA: o material que o John tem fica claro, o
# que falta fica vermelho e com o ícone apagado — e o botão inteiro escurece
# um pouco quando não dá pra construir nada. É o que responde "será que eu já
# posso?" sem o jogador precisar clicar.
#
# O botão continua CLICÁVEL de propósito: é o clique que faz a Main mostrar o
# aviso dourado ("Faltam materiais para X!"), e é assim que o jogador
# descobre o que ainda falta juntar.
func _atualizar_precos() -> void:
	for tipo in _pecas_do_preco:
		var pode: bool = true

		for peca in _pecas_do_preco[tipo]:
			# Quem conta a mochila é o Player (quantos_do_tipo), não a HUD:
			# nada de duas contagens diferentes no projeto.
			var tenho: int = jogador.quantos_do_tipo(peca["item"]) if jogador else 0
			var suficiente: bool = tenho >= int(peca["precisa"])

			peca["numero"].add_theme_color_override(
				"font_color", COR_DO_PRECO_OK if suficiente else COR_DO_PRECO_FALTA)
			peca["icone"].modulate = Color.WHITE if suficiente else Color(0.55, 0.55, 0.6)

			if not suficiente:
				pode = false

		var botao: Button = _botoes_de_construcao[tipo]
		botao.modulate = Color.WHITE if pode else COR_DO_BOTAO_SEM_MATERIAL


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

# "duracao" é o tempo que ele fica na tela. O padrão (2s) é o dos recados de
# modo, que a Main RENOVA enquanto o modo durar — por isso são curtos. As
# dicas de primeira vez pedem mais tempo: quem não repetiu, some e acabou.
func mostrar_aviso(texto: String, duracao: float = 2.0) -> void:
	label_aviso.text = texto
	label_aviso.visible = true
	timer_aviso.start(duracao)

func _esconder_aviso() -> void:
	esconder_aviso()


# Esconde o aviso NA HORA (e cancela o tempo que faltava). A Main usa quando
# um modo acaba: o recado dourado ("E constrói · Esc desiste") não vale mais
# depois do E/Esc, e sem isto ele ficaria 2s na tela dizendo o contrário.
func esconder_aviso() -> void:
	timer_aviso.stop()
	label_aviso.visible = false


# =====================================================================
# PENSAMENTO DO PERSONAGEM (acima da cabeça, criado por código igual ao aviso)
# =====================================================================
func _criar_pensamento() -> void:
	label_pensamento = Label.new()
	label_pensamento.name = "Pensamento"  # nome só pra achar no Remote inspector
	label_pensamento.visible = false
	label_pensamento.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_pensamento.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label_pensamento.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_pensamento.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Azul-claro com CONTORNO escuro: assim o texto fica legível em cima do
	# mapa (grama, água, árvore) sem precisar de painel/fundo atrás.
	label_pensamento.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0))
	label_pensamento.add_theme_color_override("font_outline_color", Color(0.06, 0.07, 0.14, 0.9))
	label_pensamento.add_theme_constant_override("outline_size", 8)
	label_pensamento.add_theme_font_size_override("font_size", 26)
	# Âncora no canto (0,0) da tela: daqui pra frente quem manda na posição é
	# o _process, que converte a posição do John no mundo pra coordenada de
	# tela (é o que faz o balão "seguir" o jogador e a câmera).
	label_pensamento.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	label_pensamento.size = Vector2(LARGURA_PENSAMENTO, ALTURA_PENSAMENTO)
	add_child(label_pensamento)

	timer_pensamento = Timer.new()
	timer_pensamento.one_shot = true
	timer_pensamento.timeout.connect(_esconder_pensamento)
	add_child(timer_pensamento)


func _process(_delta: float) -> void:
	# Só recalcula enquanto está aparecendo (barato, mas sem desperdício)
	if label_pensamento.visible:
		_posicionar_pensamento()
	if _painel_do_barco_na_tela:
		_posicionar_painel_do_barco()


# Joga o balão pra cima da cabeça do John. O pulo do gato é a
# canvas_transform: ela converte a posição do MUNDO pra coordenada de TELA
# (a mesma em que a HUD vive), então o texto acompanha a câmera sozinho.
func _posicionar_pensamento() -> void:
	if jogador == null:
		return

	var na_tela: Vector2 = get_viewport().get_canvas_transform() * jogador.global_position
	label_pensamento.position = Vector2(
		na_tela.x - LARGURA_PENSAMENTO * 0.5,
		na_tela.y - ALTURA_ACIMA_DA_CABECA - ALTURA_PENSAMENTO
	)

# O Main chama isso quando o personagem "pensa" algo. Fica na tela por alguns
# segundos e some sozinho. O padrão (5s) é o pensamento do dia a dia; a
# abertura do jogo passa um tempo menor, porque lá são várias frases em fila.
func mostrar_pensamento(texto: String, duracao: float = 5.0) -> void:
	# Durante uma conversa o pensamento apareceria ATRÁS da caixa de diálogo.
	# Ele é interrompido: a Main insiste de novo quando for a hora.
	if caixa_dialogo != null and caixa_dialogo.visible:
		return

	label_pensamento.text = texto
	# Posiciona já neste frame: senão o balão pisca 1 frame no lugar antigo
	_posicionar_pensamento()
	label_pensamento.visible = true
	timer_pensamento.start(duracao)

func _esconder_pensamento() -> void:
	label_pensamento.visible = false


# =====================================================================
# PAINEL DO BARCO (flutuante, em cima dele) — "o que falta pro conserto"
# =====================================================================
# Ele responde duas perguntas de uma vez, que é o que o jogador precisa
# saber antes de apertar E:
#   1) o que é necessário  -> ícone de madeira e de pedra + QUANTO FALTA
#   2) dá pra interagir?   -> tudo fica VERDE quando o John tem o que
#                             entregar, e dourado quando ainda não tem
#
# Construído por código, como o aviso e o pensamento. A posição usa a mesma
# conversão mundo -> tela do balão (get_canvas_transform()), então ele fica
# "colado" em cima do barco e não sofre com o y-sort do mapa.
#
# A HUD não decide nada: a Main manda os números, a posição e o estado.

func _criar_painel_barco() -> void:
	painel_barco = PanelContainer.new()
	painel_barco.name = "PainelBarco"  # nome só pra achar no Remote inspector
	painel_barco.visible = false
	# IGNORE: o painel é informação, não botão. Sem isso ele engoliria os
	# cliques dos slots do inventário e dos botões de construção.
	painel_barco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel_barco.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)

	estilo_painel_barco = StyleBoxFlat.new()
	estilo_painel_barco.bg_color = Color(0.06, 0.07, 0.11, 0.86)
	estilo_painel_barco.set_corner_radius_all(10)
	estilo_painel_barco.set_border_width_all(3)
	estilo_painel_barco.set_content_margin_all(10.0)
	painel_barco.add_theme_stylebox_override("panel", estilo_painel_barco)
	add_child(painel_barco)

	var coluna := VBoxContainer.new()
	coluna.alignment = BoxContainer.ALIGNMENT_CENTER
	coluna.add_theme_constant_override("separation", 6)
	painel_barco.add_child(coluna)

	# Título: deixa claro que estes números são DAQUELE barco
	var titulo := Label.new()
	titulo.text = "Barco quebrado"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 22)
	titulo.add_theme_color_override("font_color", Color(0.85, 0.87, 0.95))
	titulo.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.09, 0.9))
	titulo.add_theme_constant_override("outline_size", 6)
	coluna.add_child(titulo)

	# Linha do material: [ícone madeira] 20   [ícone pedra] 10
	var linha := HBoxContainer.new()
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	linha.add_theme_constant_override("separation", 22)
	coluna.add_child(linha)

	label_falta_madeira = _criar_material_do_painel(linha, "madeira")
	label_falta_pedra = _criar_material_do_painel(linha, "pedra")

	# Instrução: é ela que ensina o jogador a interagir
	label_instrucao_barco = Label.new()
	label_instrucao_barco.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_instrucao_barco.add_theme_font_size_override("font_size", 24)
	label_instrucao_barco.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.09, 0.9))
	label_instrucao_barco.add_theme_constant_override("outline_size", 6)
	coluna.add_child(label_instrucao_barco)


# Cria um par [ícone][número] dentro do painel e devolve o Label do número
# (é ele que a Main atualiza a cada entrega). O ícone sai do CatalogoItens:
# é exatamente a mesma arte que o jogador vê no slot do inventário.
func _criar_material_do_painel(pai: HBoxContainer, nome_item: String) -> Label:
	var grupo := HBoxContainer.new()
	grupo.add_theme_constant_override("separation", 4)
	pai.add_child(grupo)

	var icone := TextureRect.new()
	icone.texture = _recortar_arte(CatalogoItens.icone(nome_item))
	icone.custom_minimum_size = Vector2(TAMANHO_ICONE_BARCO, TAMANHO_ICONE_BARCO)
	icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icone.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grupo.add_child(icone)

	var numero := Label.new()
	numero.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	numero.add_theme_font_size_override("font_size", 36)
	numero.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.09, 0.95))
	numero.add_theme_constant_override("outline_size", 8)
	grupo.add_child(numero)
	return numero


# A arte de um item vive num canto de uma folha grande e transparente (a
# madeira, por exemplo, é 49x30 dentro de um PNG de 128x128). Num ícone
# pequeno isso viraria um risco ilegível. Aqui a gente recorta SÓ o desenho.
# O recorte é CALCULADO da imagem (get_used_rect), então continua certo
# sozinho se você redesenhar a arte.
func _recortar_arte(textura: Texture2D) -> Texture2D:
	if textura == null:
		return null
	if textura is AtlasTexture:
		return textura  # já vem recortada do catálogo

	var util: Rect2i = textura.get_image().get_used_rect()
	if util.size.x <= 0 or util.size.y <= 0:
		return textura

	var recorte := AtlasTexture.new()
	recorte.atlas = textura
	recorte.region = Rect2(util)
	return recorte


# A Main chama isto a cada frame em que o John está no alcance do barco.
#   falta_madeira / falta_pedra = o que ainda falta pro conserto
#   pode_entregar = o John tem alguma madeira ou pedra na mochila agora?
func mostrar_painel_do_barco(falta_madeira: int, falta_pedra: int, pode_entregar: bool, posicao_no_mundo: Vector2) -> void:
	label_falta_madeira.text = str(falta_madeira)
	label_falta_pedra.text = str(falta_pedra)

	# Verde = dá pra interagir agora. Dourado = ainda não tem o que entregar
	# (mesma cor do aviso do sistema, que o jogador já conhece).
	var destaque: Color = Color(0.45, 1.0, 0.5) if pode_entregar else Color(1.0, 0.85, 0.4)
	label_falta_madeira.add_theme_color_override("font_color", destaque)
	label_falta_pedra.add_theme_color_override("font_color", destaque)
	estilo_painel_barco.border_color = Color(destaque.r, destaque.g, destaque.b, 0.95)
	label_instrucao_barco.add_theme_color_override("font_color", destaque)
	label_instrucao_barco.text = ("Aperte E para entregar material" if pode_entregar
		else "Você não tem madeira nem pedra")

	_posicao_do_barco = posicao_no_mundo
	painel_barco.visible = true
	_painel_do_barco_na_tela = true
	_posicionar_painel_do_barco()


func esconder_painel_do_barco() -> void:
	if painel_barco == null or not painel_barco.visible:
		return
	painel_barco.visible = false
	_painel_do_barco_na_tela = false


# Mesma conta do balão de pensamento: a canvas_transform converte a posição
# do MUNDO pra coordenada de TELA. Daí é só subir o painel pra cima da base
# do barco e centralizar na horizontal.
func _posicionar_painel_do_barco() -> void:
	var na_tela: Vector2 = get_viewport().get_canvas_transform() * _posicao_do_barco
	var tamanho: Vector2 = painel_barco.get_combined_minimum_size()
	painel_barco.position = Vector2(
		na_tela.x - tamanho.x * 0.5,
		na_tela.y - ALTURA_ACIMA_DO_BARCO - tamanho.y
	)


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
	# O preço dos botões de construção depende da mochila: repinta já, ANTES
	# de qualquer saída antecipada (gastar um item pra construir chama aqui
	# com nome vazio e precisa atualizar o preço do mesmo jeito).
	_atualizar_precos()

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
# O Main também usa este mesmo clique pro modo largar (Q).
func _on_slot_gui_input(evento: InputEvent, indice: int) -> void:
	if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		slot_usado.emit(indice)


# Modo largar (Q): o Main liga isto enquanto o jogador escolhe qual item
# jogar fora. O conjunto dos slots fica avermelhado pra ficar óbvio que o
# clique agora LARGA em vez de comer. A HUD não conhece a regra: só obedece.
func destacar_slots_para_largar(ativo: bool) -> void:
	slots_container.modulate = Color(1.0, 0.5, 0.5) if ativo else Color.WHITE
