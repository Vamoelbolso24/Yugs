-- Fossil Pkmn - Omanyte
-- Cannot be Normal Summoned/Set. Must first be Special Summoned (from your hand) by banishing 2 WATER monsters from
-- your GY.
-- Once per turn, while "Rain Dance" is on the field (Quick Effect): You can change this card's battle position.
local s,id=GetID()
s.listed_names={CARD_RAIN_DANCE}
function s.initial_effect(c)
	Pokemon.AddFossilSummon(c,"banish",function(x) return x:IsMonster() and x:IsAttribute(ATTRIBUTE_WATER) end,2)
	Pokemon.AddRainPositionChange(c,0)
end
