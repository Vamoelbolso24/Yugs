-- Bonemerang (Normal Spell)
-- Target 1 "Marowak" monster you control; it can make a second attack during each Battle Phase this turn.
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
		if chkc then return chkc:IsLocation(LOCATION_MZONE) and chkc:IsControler(tp) and s.filter(chkc) end
		if chk==0 then return Duel.IsExistingTarget(s.filter,tp,LOCATION_MZONE,0,1,nil) end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TARGET)
		Duel.SelectTarget(tp,s.filter,tp,LOCATION_MZONE,0,1,1,nil)
	end)
	e1:SetOperation(function(e)
		local tc=Duel.GetFirstTarget()
		if not (tc and tc:IsRelateToEffect(e) and tc:IsFaceup()) then return end
		local e1=Effect.CreateEffect(e:GetHandler())
		e1:SetType(EFFECT_TYPE_SINGLE)
		e1:SetCode(EFFECT_EXTRA_ATTACK)
		e1:SetValue(1)
		e1:SetReset(RESETS_STANDARD_PHASE_END)
		tc:RegisterEffect(e1)
	end)
	c:RegisterEffect(e1)
end
s.listed_series={SET_MAROWAK}
function s.filter(c) return c:IsFaceup() and c:IsSetCard(SET_MAROWAK) end
