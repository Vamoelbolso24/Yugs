-- Bellsprout
-- During your Standby Phase: You can make this card gain 200 ATK, or 400 ATK instead if "Sunny Day" is on the
-- field. This card cannot declare an attack the turn you activate this effect.
-- (Shared with Weepingbell: Pokemon.AddGrowth in custom_utility.lua.)
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddGrowth(c,0)   -- Prompt 1
end
s.listed_names={CARD_SUNNY_DAY}
