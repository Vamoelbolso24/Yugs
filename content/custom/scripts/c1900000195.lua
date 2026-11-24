-- Magmar
-- When you Ritual Summon 1 FIRE monster, you can banish this card from your field or GY as the entire Tribute.
-- If this card is Normal Summoned: You can add 1 "Jynx" from your Deck to your hand.
-- If this Tribute Summoned card inflicts battle damage to your opponent: Excavate the top card of your Deck, and if
-- it is a FIRE Pokemon monster, your opponent cannot activate Trap cards until the end of your next turn, also shuffle it back into the Deck.
-- (Jynx, Electabuzz and Magmar share their code: Pokemon.AddRitualTrio in custom_utility.lua.)
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddRitualTrio(c,ATTRIBUTE_FIRE,1900000193)
end
s.listed_names={1900000193}
