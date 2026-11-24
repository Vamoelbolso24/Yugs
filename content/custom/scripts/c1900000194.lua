-- Electabuzz
-- When you Ritual Summon 1 LIGHT monster, you can banish this card from your field or GY as the entire Tribute.
-- If this card is Normal Summoned: You can add 1 "Magmar" from your Deck to your hand.
-- If this Tribute Summoned card inflicts battle damage to your opponent: Excavate the top card of your Deck, and if
-- it is a LIGHT Pokemon monster, your opponent skips their next Battle Phase, also shuffle it back into the Deck.
-- (Jynx, Electabuzz and Magmar share their code: Pokemon.AddRitualTrio in custom_utility.lua.)
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddRitualTrio(c,ATTRIBUTE_LIGHT,1900000195)
end
s.listed_names={1900000195}
