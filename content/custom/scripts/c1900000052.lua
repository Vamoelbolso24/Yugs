-- Vulpix
-- (This card can be targeted by the effects of "Fire Stone".)
-- Once per turn: You can place a Burn Counter on a monster your opponent controls.
-- (A monster with a Burn Counter loses 300 ATK for each Burn Counter on it.)
-- WHERE THE COUNTER IS PLACED: Pokemon.AddBurnCounter in custom_utility.lua, the line
--     tc:AddCounter(COUNTER_BURN,1)
-- The -300 ATK per counter is Pokemon.EnableBurnRule (same file).
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddBurnCounter(c,0)
end
s.listed_names={1900000054}   -- Fire Stone (so Fire Stone can Tribute Vulpix and bring out Ninetales)
