-- Calm Mind (Equip Spell)
-- Equip only to a Spellcaster or Fiend Pokemon monster.
-- Once per turn, during your Standby Phase: Place 1 C-Counter on this card.
-- The equipped monster gains 500 ATK for each C-Counter on this card.
-- If the equipped monster would be destroyed by battle or card effect, you can send this card (with 1 or more
-- C-Counters) to the GY instead.
local s,id=GetID()
function s.initial_effect(c)
	aux.AddEquipProcedure(c,nil,function(tc) return tc:IsSetCard(SET_POKEMON) and tc:IsRace(RACE_SPELLCASTER|RACE_FIEND) end)
	-- +500 ATK per counter on this card
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_EQUIP)
	e1:SetCode(EFFECT_UPDATE_ATTACK)
	e1:SetValue(function(e) return e:GetHandler():GetCounter(COUNTER_C)*500 end)
	c:RegisterEffect(e1)
	-- Your Standby Phase: +1 counter (mandatory)
	local e2=Effect.CreateEffect(c)
	e2:SetCategory(CATEGORY_COUNTER)
	e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_F)
	e2:SetCode(EVENT_PHASE+PHASE_STANDBY)
	e2:SetRange(LOCATION_SZONE)
	e2:SetCountLimit(1)
	e2:SetCondition(function(e,tp) return Duel.IsTurnPlayer(tp) and e:GetHandler():GetEquipTarget() end)
	e2:SetOperation(function(e)
		local c=e:GetHandler()
		if c:IsRelateToEffect(e) then c:AddCounter(COUNTER_C,1) end
	end)
	c:RegisterEffect(e2)
	-- Protection: send this card instead
	local e3=Effect.CreateEffect(c)
	e3:SetType(EFFECT_TYPE_EQUIP+EFFECT_TYPE_CONTINUOUS)
	e3:SetCode(EFFECT_DESTROY_REPLACE)
	e3:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		local c=e:GetHandler()
		local tc=c:GetEquipTarget()
		if chk==0 then return tc and tc:IsReason(REASON_BATTLE|REASON_EFFECT) and not tc:IsReason(REASON_REPLACE)
			and c:GetCounter(COUNTER_C)>0 and c:IsAbleToGrave() and not c:IsStatus(STATUS_DESTROY_CONFIRMED) end
		return Duel.SelectEffectYesNo(tp,c,96)
	end)
	e3:SetOperation(function(e) Duel.SendtoGrave(e:GetHandler(),REASON_EFFECT|REASON_REPLACE) end)
	c:RegisterEffect(e3)
end
s.counter_place_list={COUNTER_C}
