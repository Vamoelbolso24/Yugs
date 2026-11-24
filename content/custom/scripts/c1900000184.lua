-- Horsea
-- Once per turn, if this card is targeted for an attack: You can pay 800 LP; negate that attack.
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e1:SetCode(EVENT_BE_BATTLE_TARGET)
	e1:SetCountLimit(1)
	e1:SetCost(Cost.PayLP(800))
	e1:SetOperation(function() Duel.NegateAttack() end)
	c:RegisterEffect(e1)
end
