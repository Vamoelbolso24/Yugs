-- Nidorino
-- (This card can be targeted by the effects of "Moon Stone".)
-- Evolution Summon from "Nidoran Male" (hard once per turn).
-- "Nido" monsters you control, except "Nidorino", gain 300 ATK/DEF.
-- If this card is Summoned: You can add 1 "Nidorina" from your Deck to your hand.
-- You can only use this effect of "Nidorino" once per turn.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000047)   -- from Nidoran Male
	Pokemon.AddNidoBoost(c)
	Pokemon.AddSummonSearch(c,0,function(tc) return tc:IsCode(1900000044) end)   -- Nidorina
end
s.listed_names={1900000046,1900000047,1900000044}   -- Moon Stone, Nidoran Male, Nidorina
