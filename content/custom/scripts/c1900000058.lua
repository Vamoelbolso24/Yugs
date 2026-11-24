-- Zubat
-- If your opponent targets this card for an attack: Toss a coin and call it. If you call it right,
-- negate the attack, and if you do, inflict damage to your opponent equal to half the attacking monster's ATK.
-- PATTERN: "targeted for an attack" = EVENT_BE_BATTLE_TARGET. Mandatory (no "You can") = TRIGGER_F.
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_COIN+CATEGORY_DAMAGE)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_F)
	e1:SetCode(EVENT_BE_BATTLE_TARGET)
	e1:SetCondition(function(e,tp) return Duel.GetAttacker():IsControler(1-tp) end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_COIN,nil,0,tp,1)
	end)
	e1:SetOperation(function(e,tp)
		local a=Duel.GetAttacker()
		if not Duel.CallCoin(tp) then return end
		local atk=a and a:GetAttack() or 0
		if Duel.NegateAttack() then
			Duel.Damage(1-tp,math.floor(atk/2),REASON_EFFECT)
		end
	end)
	c:RegisterEffect(e1)
end
s.toss_coin=true
