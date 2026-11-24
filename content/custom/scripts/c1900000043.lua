-- Nidoran Female
-- If this card is Summoned: You can add 1 "Nidoran" monster from your Deck to your hand.
-- You can only use this effect of "Nidoran Female" once per turn.
-- PATTERN: an archetype ("Nidoran" monsters) = a subtype in cards.txt, checked with IsSetCard(SET_NIDORAN).
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddSummonSearch(c,0,function(tc) return tc:IsSetCard(SET_NIDORAN) end)
end
