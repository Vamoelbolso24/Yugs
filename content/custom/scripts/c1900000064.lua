-- Leaf Stone (Normal Spell)
-- Tribute 1 Plant Pokemon monster you control to Special Summon from your Deck 1 monster that mentions the
-- Tributed monster's name. For the rest of the turn, you cannot Summon monsters with the same name as the
-- monster Special Summoned by this effect.
-- (Oddish -> Gloom, Gloom -> Vileplume.) Same as Fire Stone, with Plant instead of FIRE.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddStoneEffect(c,function(tc) return tc:IsRace(RACE_PLANT) end)
end
