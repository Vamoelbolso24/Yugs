-- Nidorina
-- (This card can be targeted by the effects of "Moon Stone".)
-- Evolution Summon from "Nidoran Female" (hard once per turn).
-- "Nido" monsters you control, except "Nidorina", gain 300 ATK/DEF.
-- If this card is Summoned: You can add 1 "Nidorino" from your Deck to your hand.
-- You can only use this effect of "Nidorina" once per turn.
-- The two "once per turn"s are separate limits (one for the Evolution Summon, one for the search),
-- so both are needed: each has its own counter.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000043)   -- from Nidoran Female
	Pokemon.AddNidoBoost(c)
	Pokemon.AddSummonSearch(c,0,function(tc) return tc:IsCode(1900000048) end)   -- Nidorino
end
s.listed_names={1900000046,1900000043,1900000048}   -- Moon Stone, Nidoran Female, Nidorino
