# res://Scripts/Characters/Vera.gd
extends PersonagemBase

# BATLE_ROOT JÁ EXISTE NO PERSONAGEMBASE 

func use_ability(ability_name: String, target_node: CharacterBody2D):
	super.use_ability(ability_name, target_node)

	if not cannot_use_ability:
		if ability_name == "Ataque Reprimido":
			# Se for um ataque inicial, ela é tímida
			if batle_root.party_tension < 50:
				batle_root.trigger_battle_talk(self, "(Vera ataca timidamente.)")
				batle_root.aumentar_tensao(5)
			else:
				 # O ataque dela é forte (exemplo de lógica de dano alto/consequência)
				batle_root.trigger_battle_talk(self, "NÃO ME IRRITEM!", 1.5)
		
		if ability_name == "Corte Profano":
			batle_root.aumentar_tensao(10)
			batle_root.trigger_battle_talk(self, "Só... some logo de uma vez...")
			play_sfx("res://Sound_Effects/sword-slash-and-swing-185432.mp3", "SFX")
		
		if ability_name == "Override de Fúria":
			batle_root.trigger_battle_talk(self, "Droga! MORRE LOGO!")
			play_sfx("res://Sound_Effects/sword-slash-with-metallic-impact-185435.mp3", "SFX")
	else:
		batle_root.trigger_battle_talk(self, "Não posso usar agora...")
