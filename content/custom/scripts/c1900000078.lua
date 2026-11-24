-- Diglett
-- Cards your opponent controls or in their hand cannot be Tributed.
-- PATTERN: "cannot be Tributed" = EFFECT_UNRELEASABLE_SUM (for a Tribute Summon) + EFFECT_UNRELEASABLE_NONSUM
-- (for anything else, like costs). Shared with Dugtrio: Pokemon.AddNoTributeLock in custom_utility.lua.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddNoTributeLock(c)
end
