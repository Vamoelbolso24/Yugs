-- Slowbro
-- Evolution Summon from "Slowpoke" (hard once per turn).
-- Once per turn, during your Standby Phase: You can place 1 C-Counter on this card (max. 4). This card cannot
-- declare an attack the turn you activate this effect.
-- Once per turn: You can target 1 monster your opponent controls; during your next Standby Phase, return it to
-- the hand (even if this card leaves the field).
-- PATTERN: "during your next Standby Phase, do X" = register a delayed effect on the PLAYER (Duel.RegisterEffect),
-- so it still happens if this card is gone. The target is remembered with a flag on it.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000129)   -- from Slowpoke
	Pokemon.AddCCounterStandby(c,0)             -- Prompt 1

	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,1))       -- Prompt 2
	e1:SetType(EFFECT_TYPE_IGNITION)
	e1:SetRange(LOCATION_MZONE)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e1:SetCountLimit(1)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
		if chkc then return chkc:IsLocation(LOCATION_MZONE) and chkc:IsControler(1-tp) end
		if chk==0 then return Duel.IsExistingTarget(nil,tp,0,LOCATION_MZONE,1,nil) end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TARGET)
		Duel.SelectTarget(tp,nil,tp,0,LOCATION_MZONE,1,1,nil)
	end)
	e1:SetOperation(s.operation)
	c:RegisterEffect(e1)
end
s.listed_names={1900000129}
s.counter_place_list={COUNTER_C}
function s.operation(e,tp)
	local tc=Duel.GetFirstTarget()
	if not (tc and tc:IsRelateToEffect(e)) then return end
	-- mark it (the mark disappears if it leaves the field first)
	tc:RegisterFlagEffect(id,RESET_EVENT|RESETS_STANDARD,EFFECT_FLAG_CLIENT_HINT,1,0,aux.Stringid(id,2))
	local turn=Duel.GetTurnCount()
	local e1=Effect.CreateEffect(e:GetHandler())
	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e1:SetCode(EVENT_PHASE+PHASE_STANDBY)
	e1:SetCountLimit(1)
	e1:SetCondition(function() return Duel.IsTurnPlayer(tp) and Duel.GetTurnCount()~=turn end)
	e1:SetOperation(function(ef)
		if tc:GetFlagEffect(id)>0 then
			Duel.Hint(HINT_CARD,0,id)
			Duel.SendtoHand(tc,nil,REASON_EFFECT)
		end
		ef:Reset()
	end)
	e1:SetReset(RESET_PHASE|PHASE_STANDBY|RESET_SELF_TURN,2)
	Duel.RegisterEffect(e1,tp)
end
