-- Pikachu
-- (This card is always treated as mentioning "Thunder Stone".)
-- If this card destroys a WATER monster by battle: It can make a second attack in a row.
-- PATTERN: "mentions <card>" = put that card's ID in s.listed_names. Other cards check it with
-- c:ListsCode(<ID>) (see Thunder Stone, c1900000037.lua).
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e1:SetCode(EVENT_BATTLE_DESTROYING)
	e1:SetCondition(s.atcon)
	e1:SetOperation(function() Duel.ChainAttack() end)   -- "make a second attack in a row"
	c:RegisterEffect(e1)
end
s.listed_names={1900000037}   -- Thunder Stone

function s.atcon(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local bc=c:GetBattleTarget()
	return Duel.GetAttacker()==c and aux.bdcon(e,tp,eg,ep,ev,re,r,rp)
		and bc and bc:IsAttribute(ATTRIBUTE_WATER) and c:CanChainAttack()
end
