-- Solar Beam (Continuous Spell)
-- Target 1 Plant monster you control; it cannot attack while this card is on the field, also destroy this
-- card if that monster leaves the field.
-- During your next Standby Phase after this card's activation, or during your Main Phase if
-- "Weather Condition - Sunny Day" is on the field: Send this card to the GY, and if you do, inflict damage
-- to your opponent equal to the original Level of the targeted monster x 400.
-- PATTERN: a Continuous Spell that keeps a target = c:SetCardTarget(tc) when it resolves; other effects
-- check it with e:GetHandler():GetFirstCardTarget().
local s,id=GetID()
function s.initial_effect(c)
	-- Activate: target a Plant you control
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e1:SetTarget(s.acttg)
	e1:SetOperation(s.actop)
	c:RegisterEffect(e1)
	-- The targeted monster can't attack
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_FIELD)
	e2:SetCode(EFFECT_CANNOT_ATTACK)
	e2:SetRange(LOCATION_SZONE)
	e2:SetTargetRange(LOCATION_MZONE,0)
	e2:SetTarget(function(e,tc) return e:GetHandler():IsHasCardTarget(tc) end)
	c:RegisterEffect(e2)
	-- Destroy this card if the targeted monster leaves the field
	local e3=Effect.CreateEffect(c)
	e3:SetType(EFFECT_TYPE_CONTINUOUS+EFFECT_TYPE_FIELD)
	e3:SetCode(EVENT_LEAVE_FIELD)
	e3:SetRange(LOCATION_SZONE)
	e3:SetCondition(function(e,tp,eg)
		local tc=e:GetHandler():GetFirstCardTarget()
		return tc and eg:IsContains(tc)
	end)
	e3:SetOperation(function(e) Duel.Destroy(e:GetHandler(),REASON_EFFECT) end)
	c:RegisterEffect(e3)
	-- Your next Standby Phase (mandatory)
	local e4=Effect.CreateEffect(c)
	e4:SetCategory(CATEGORY_DAMAGE)
	e4:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_F)
	e4:SetCode(EVENT_PHASE+PHASE_STANDBY)
	e4:SetRange(LOCATION_SZONE)
	e4:SetCountLimit(1)
	e4:SetCondition(function(e,tp)
		local c=e:GetHandler()
		return Duel.IsTurnPlayer(tp) and c:GetFirstCardTarget() and c:GetFlagEffect(id)>0
			and Duel.GetTurnCount()>c:GetFlagEffectLabel(id)   -- after the turn it was activated
	end)
	e4:SetTarget(s.firetg)
	e4:SetOperation(s.fireop)
	c:RegisterEffect(e4)
	-- Your Main Phase, if Sunny Day is on the field (you choose when)
	local e5=Effect.CreateEffect(c)
	e5:SetDescription(aux.Stringid(id,0))
	e5:SetCategory(CATEGORY_DAMAGE)
	e5:SetType(EFFECT_TYPE_IGNITION)
	e5:SetRange(LOCATION_SZONE)
	e5:SetCondition(function(e) return e:GetHandler():GetFirstCardTarget() and Pokemon.IsOnField(CARD_SUNNY_DAY) end)
	e5:SetTarget(s.firetg)
	e5:SetOperation(s.fireop)
	c:RegisterEffect(e5)
end
s.listed_names={CARD_SUNNY_DAY}

function s.filter(c) return c:IsFaceup() and c:IsRace(RACE_PLANT) end
function s.acttg(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	if chkc then return chkc:IsLocation(LOCATION_MZONE) and chkc:IsControler(tp) and s.filter(chkc) end
	if chk==0 then return Duel.IsExistingTarget(s.filter,tp,LOCATION_MZONE,0,1,nil) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TARGET)
	Duel.SelectTarget(tp,s.filter,tp,LOCATION_MZONE,0,1,1,nil)
end
function s.actop(e,tp)
	local c=e:GetHandler()
	local tc=Duel.GetFirstTarget()
	if c:IsRelateToEffect(e) and tc and tc:IsRelateToEffect(e) and tc:IsFaceup() then
		c:SetCardTarget(tc)
		-- remember the activation turn (label) for "your NEXT Standby Phase"
		c:RegisterFlagEffect(id,RESET_EVENT|RESETS_STANDARD,0,1,Duel.GetTurnCount())
	end
end
function s.firetg(e,tp,eg,ep,ev,re,r,rp,chk)
	local tc=e:GetHandler():GetFirstCardTarget()
	if chk==0 then return tc~=nil end
	e:SetLabel(tc:GetOriginalLevel()*400)   -- remember the damage now, before this card leaves
	Duel.SetOperationInfo(0,CATEGORY_DAMAGE,nil,0,1-tp,e:GetLabel())
end
function s.fireop(e,tp)
	local c=e:GetHandler()
	if c:IsRelateToEffect(e) and Duel.SendtoGrave(c,REASON_EFFECT)>0 and c:IsLocation(LOCATION_GRAVE) then
		Duel.Damage(1-tp,e:GetLabel(),REASON_EFFECT)
	end
end
