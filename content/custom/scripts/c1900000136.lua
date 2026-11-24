-- Magnemite
-- Your opponent cannot Special Summon Machine monsters.
-- The first time this card would be destroyed by battle each turn, it is not.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddNoMachineSummon(c)
	Pokemon.AddBattleSurvive(c)
end
