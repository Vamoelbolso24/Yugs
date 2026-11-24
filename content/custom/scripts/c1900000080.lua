-- Dig (Normal Spell)
-- Target 1 Level 4 or lower EARTH monster you control that hasn't declared an attack this turn; banish it
-- until your next Battle Phase. When it returns, until the end of that turn it gains 500 ATK and can attack
-- directly, also if it battles, your opponent cannot activate cards or effects until the end of the Damage Step.
-- (Same idea as Fly, c1900000026.lua. If that Battle Phase is skipped it comes back in the End Phase.)
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_REMOVE)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
function s.filter(c)
	return c:IsFaceup() and c:IsLevelBelow(4) and c:IsAttribute(ATTRIBUTE_EARTH)
		and c:GetAttackAnnouncedCount()==0 and c:IsAbleToRemove()
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	if chkc then return chkc:IsLocation(LOCATION_MZONE) and chkc:IsControler(tp) and s.filter(chkc) end
	if chk==0 then return Duel.IsExistingTarget(s.filter,tp,LOCATION_MZONE,0,1,nil) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_REMOVE)
	local g=Duel.SelectTarget(tp,s.filter,tp,LOCATION_MZONE,0,1,1,nil)
	Duel.SetOperationInfo(0,CATEGORY_REMOVE,g,1,0,0)
end
function s.activate(e,tp)
	local tc=Duel.GetFirstTarget()
	if not (tc and tc:IsRelateToEffect(e)) then return end
	if Duel.Remove(tc,POS_FACEUP,REASON_EFFECT+REASON_TEMPORARY)==0 then return end
	tc:RegisterFlagEffect(id,RESET_EVENT|RESETS_STANDARD,0,1)
	local turn=Duel.GetTurnCount()
	local e1=Effect.CreateEffect(e:GetHandler())
	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e1:SetCode(EVENT_PHASE+PHASE_BATTLE_START)
	e1:SetCountLimit(1)
	e1:SetCondition(function() return Duel.IsTurnPlayer(tp) and Duel.GetTurnCount()~=turn and tc:GetFlagEffect(id)>0 end)
	e1:SetOperation(function(ef) s.comeback(ef,tc,true) end)
	e1:SetReset(RESET_PHASE|PHASE_END|RESET_SELF_TURN,2)
	Duel.RegisterEffect(e1,tp)
	local e2=e1:Clone()
	e2:SetCode(EVENT_PHASE+PHASE_END)
	e2:SetOperation(function(ef) s.comeback(ef,tc,false) end)
	Duel.RegisterEffect(e2,tp)
end
function s.comeback(e,tc,boost)
	if tc:GetFlagEffect(id)==0 then return end
	tc:ResetFlagEffect(id)
	if not (Duel.ReturnToField(tc) and boost) then return end
	local c=e:GetHandler()
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetCode(EFFECT_UPDATE_ATTACK)
	e1:SetValue(500)
	e1:SetReset(RESETS_STANDARD_PHASE_END)
	tc:RegisterEffect(e1)
	local e2=e1:Clone()
	e2:SetCode(EFFECT_DIRECT_ATTACK)
	tc:RegisterEffect(e2)
	-- While it battles: the opponent can't activate anything
	local e3=Effect.CreateEffect(c)
	e3:SetType(EFFECT_TYPE_FIELD)
	e3:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
	e3:SetCode(EFFECT_CANNOT_ACTIVATE)
	e3:SetTargetRange(0,1)
	e3:SetValue(1)
	e3:SetCondition(function() return tc:IsOnField() and (Duel.GetAttacker()==tc or Duel.GetAttackTarget()==tc) end)
	e3:SetReset(RESET_PHASE|PHASE_END)
	Duel.RegisterEffect(e3,tc:GetControler())
end
