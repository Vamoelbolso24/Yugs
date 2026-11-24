-- Jynx
-- When you Ritual Summon 1 WATER monster, you can banish this card from your field or GY as the entire Tribute.
-- If this card is Normal Summoned: You can add 1 "Electabuzz" from your Deck to your hand.
-- If this Tribute Summoned card inflicts battle damage to your opponent: Excavate the top card of your Deck, and if
-- it is a WATER Pokemon monster, your opponent cannot activate Spell cards during their next turn, also shuffle it back into the Deck.
-- (Jynx, Electabuzz and Magmar share their code: Pokemon.AddRitualTrio in custom_utility.lua.)
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddRitualTrio(c,ATTRIBUTE_WATER,1900000194)
end
s.listed_names={1900000194}
