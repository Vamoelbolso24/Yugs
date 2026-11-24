-- Nidoking
-- Evolution Summon from "Nidorino" (hard once per turn).
-- "Nido" monsters you control, except "Nidoking", are unaffected by your opponent's Spell effects.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000048)   -- from Nidorino
	Pokemon.AddNidoImmunity(c,TYPE_SPELL)
end
s.listed_names={1900000048}
