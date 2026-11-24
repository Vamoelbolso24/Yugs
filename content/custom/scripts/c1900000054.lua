-- Fire Stone (Normal Spell)
-- Tribute 1 FIRE Pokemon monster you control to Special Summon from your Deck 1 monster that mentions the
-- Tributed monster's name. For the rest of the turn, you cannot Summon monsters with the same name as the
-- monster Special Summoned by this effect.
-- (Vulpix -> Ninetales. Charmander -> Charmeleon works too: Charmeleon mentions Charmander.)
-- The whole effect is in Pokemon.AddStoneEffect (custom_utility.lua); this line only says which monsters
-- can be Tributed.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddStoneEffect(c,function(tc) return tc:IsAttribute(ATTRIBUTE_FIRE) end)
end
