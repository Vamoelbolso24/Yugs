-- Haunter
-- Evolution Summon from "Gastly" (hard once per turn).
-- If this card inflicts battle damage to your opponent: Your opponent discards 1 random card.
-- You can only use this effect of "Haunter" once per turn.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000149)   -- from Gastly
	Pokemon.AddRandomDiscardOnDamage(c,id)
end
s.listed_names={1900000149}
