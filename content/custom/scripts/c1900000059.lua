-- Golbat
-- You can Special Summon this card (from your hand) by discarding 1 card.
-- This card cannot declare an attack the turn it is Summoned.
-- PATTERN: a built-in Special Summon with a cost, like The Tricky = EFFECT_SPSUMMON_PROC.
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_SPSUMMON_PROC)
	e1:SetProperty(EFFECT_FLAG_UNCOPYABLE)
	e1:SetRange(LOCATION_HAND)
	e1:SetCondition(function(e,c)
		if c==nil then return true end
		local tp=c:GetControler()
		return Duel.GetLocationCount(tp,LOCATION_MZONE)>0
			and Duel.IsExistingMatchingCard(Card.IsDiscardable,tp,LOCATION_HAND,0,1,c)
	end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,c)
		local g=Duel.GetMatchingGroup(Card.IsDiscardable,tp,LOCATION_HAND,0,c)
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_DISCARD)
		local sg=g:Select(tp,1,1,nil)
		if #sg==0 then return false end
		sg:KeepAlive()
		e:SetLabelObject(sg)
		return true
	end)
	e1:SetOperation(function(e,tp,eg,ep,ev,re,r,rp,c)
		local sg=e:GetLabelObject()
		Duel.SendtoGrave(sg,REASON_COST|REASON_DISCARD)
		sg:DeleteGroup()
	end)
	c:RegisterEffect(e1)
	-- No attack the turn it is Summoned (any way)
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_CONTINUOUS)
	e2:SetCode(EVENT_SUMMON_SUCCESS)
	e2:SetOperation(function(e)
		local e3=Effect.CreateEffect(e:GetHandler())
		e3:SetType(EFFECT_TYPE_SINGLE)
		e3:SetCode(EFFECT_CANNOT_ATTACK_ANNOUNCE)
		e3:SetReset(RESETS_STANDARD_PHASE_END)
		e:GetHandler():RegisterEffect(e3)
	end)
	c:RegisterEffect(e2)
	local e4=e2:Clone() e4:SetCode(EVENT_SPSUMMON_SUCCESS) c:RegisterEffect(e4)
	local e5=e2:Clone() e5:SetCode(EVENT_FLIP_SUMMON_SUCCESS) c:RegisterEffect(e5)
end
