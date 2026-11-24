-- Poliwhirl
-- Evolution Summon from "Poliwag" (hard once per turn).
-- Cannot be destroyed by battle with, or targeted by the effects of, WATER monsters.
-- While "Rain Dance" is on the field: Once per turn, if this card destroys a monster by battle: It can make a
-- second attack in a row. (Same as Pikachu's, c1900000034.lua.)
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000098)   -- from Poliwag
	Pokemon.AddWaterProtection(c)

	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e1:SetCode(EVENT_BATTLE_DESTROYING)
	e1:SetCountLimit(1)
	e1:SetCondition(function(e)
		local c=e:GetHandler()
		return Pokemon.IsOnField(CARD_RAIN_DANCE) and aux.bdcon(e) and c:CanChainAttack()
	end)
	e1:SetOperation(function() Duel.ChainAttack() end)
	c:RegisterEffect(e1)
end
s.listed_names={1900000098,CARD_RAIN_DANCE}
