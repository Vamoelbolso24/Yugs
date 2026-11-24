-- Machop
-- When this card destroys a monster by battle: Inflict 300 damage to your opponent.
local s,id=GetID()
function s.initial_effect(c)

	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_DAMAGE)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_F)
	e1:SetCode(EVENT_BATTLE_DESTROYING)
	e1:SetCondition(aux.bdocon)          -- it destroyed an opponent's monster by battle
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_DAMAGE,nil,0,1-tp,300)
	end)
	e1:SetOperation(function(e,tp) Duel.Damage(1-tp,300,REASON_EFFECT) end)
	c:RegisterEffect(e1)
end

