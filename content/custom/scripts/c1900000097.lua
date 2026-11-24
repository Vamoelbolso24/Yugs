-- Golduck
-- Evolution Summon from "Psyduck" (hard once per turn).
-- Same effects as Psyduck (c1900000096.lua).
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000096)   -- from Psyduck
	Pokemon.AddCloudNine(c)
	Pokemon.AddDestroyNegate(c,0)
end
s.listed_names={1900000096}
s.listed_series={SET_WEATHER}
