# res://Scripts/UI/BattleTalk.gd
extends Control

@onready var speech_bubble = $MarginContainer/SpeechBubble
@onready var dialogue_text = $MarginContainer/MarginContainer/DialogueText

const MAX_TEXT_WIDTH = 200 # Largura máxima desejada para o texto

func start_talk(text: String, duration: float = 3.0):
	dialogue_text.text = text

	# Obtém a fonte do Label
	var font = dialogue_text.get_theme_font("font")
	var font_size = dialogue_text.get_theme_font_size("font_size")

	# Calcula o tamanho do texto sem quebra de linha
	var text_width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

	# Determina a largura do Label e se o autowrap_mode deve ser ativado
	var final_label_width = text_width
	if text_width > MAX_TEXT_WIDTH:
		final_label_width = MAX_TEXT_WIDTH
		dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD # Ativa o autowrap
	else:
		dialogue_text.autowrap_mode = TextServer.AUTOWRAP_OFF # Garante que está desativado se o texto for menor

	# Define o tamanho mínimo do Label para a largura calculada
	# Isso garante que a caixa de texto se adapte ao conteúdo
	dialogue_text.set_custom_minimum_size(Vector2(final_label_width, 0))

	# Força o Label a recalcular seu tamanho com base no novo texto e largura mínima
	dialogue_text.call_deferred("add_theme_font_size_override", "font_size", font_size) # Truque para forçar o update imediato

	await get_tree().process_frame # Espera um frame para o layout ser atualizado


	# Define a posição inicial (pode ser ajustado para flutuar de um ponto específico)
	var initial_pos = position
	var final_pos = initial_pos - Vector2(0, 50) # Flutua 50 pixels para cima

	 # 2. CRIAÇÃO DO TWEEN (A Solução para o erro)
	var dialogue_tween = create_tween()
	dialogue_tween.set_trans(Tween.TRANS_SINE) # Opcional: define a curva de animação

	# 3. Sequência de Animação: FADE IN -> FLUTUAR -> ESPERA -> FADE OUT

	# [FASE 1: FADE IN] Torna o balão visível
	dialogue_tween.tween_property(self, "modulate:a", 1.0, 0.2)

	# [FASE 2: FLUTUAR]
	dialogue_tween.tween_property(self, "position", final_pos, 0.5)

	# [FASE 3: ESPERA] Espera o tempo restante da duração
	dialogue_tween.tween_interval(duration - 0.5) 

	# [FASE 4: FADE OUT] Começa a desaparecer
	dialogue_tween.tween_property(self, "modulate:a", 0.0, 0.5)

	# 4. Remove a cena após o término de TODAS as animações
	dialogue_tween.chain().tween_callback(queue_free)
