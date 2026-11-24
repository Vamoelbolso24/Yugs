-- Dewgong
-- Evolution Summon from "Seel" (hard once per turn).
-- While "Rain Dance" is on the field, this card cannot be targeted by your opponent's card effects.
-- Once per turn, during your Standby Phase (Quick Effect): You can target 1 monster your opponent controls; it
-- cannot activate its effects until the end of your opponent's next turn.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000142)   -- from Seel
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCode(EFFECT_CANNOT_BE_EFFECT_TARGET)
	e1:SetCondition(function() return Pokemon.IsOnField(CARD_RAIN_DANCE) end)
	e1:SetValue(aux.tgoval)
	c:RegisterEffect(e1)
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,0))
	e2:SetType(EFFECT_TYPE_QUICK_O)
	e2:SetCode(EVENT_FREE_CHAIN)
	e2:SetRange(LOCATION_MZONE)
	e2:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e2:SetCountLimit(1)
	e2:SetCondition(function(e,tp) return Duel.IsTurnPlayer(tp) and Duel.GetCurrentPhase()==PHASE_STANDBY end)
	e2:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
		if chkc then return chkc:IsLocation(LOCATION_MZONE) and chkc:IsControler(1-tp) end
		if chk==0 then return Duel.IsExistingTarget(nil,tp,0,LOCATION_MZONE,1,nil) end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TARGET)
		Duel.SelectTarget(tp,nil,tp,0,LOCATION_MZONE,1,1,nil)
	end)
	e2:SetOperation(function(e,tp)
		local tc=Duel.GetFirstTarget()
		if not (tc and tc:IsRelateToEffect(e)) then return end
		-- until the end of the opponent's next turn (this is your Standby, so that's the next turn)
		local e3=Effect.CreateEffect(e:GetHandler())
		e3:SetType(EFFECT_TYPE_SINGLE)
		e3:SetProperty(EFFECT_FLAG_CLIENT_HINT)
		e3:SetDescription(aux.Stringid(id,1))
		e3:SetCode(EFFECT_CANNOT_TRIGGER)
		e3:SetReset(RESET_EVENT|RESETS_STANDARD|RESET_PHASE|PHASE_END|RESET_OPPO_TURN,1)
		tc:RegisterEffect(e3)
	end)
	c:RegisterEffect(e2)
end
s.listed_names={1900000142,CARD_RAIN_DANCE}
