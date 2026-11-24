-- Water Stone (Normal Spell)

local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddStoneEffect(c,function(tc) return tc:IsAttribute(ATTRIBUTE_WATER) end)
end
