-- Zapdos (Ritual)
-- You can Ritual Summon this card with "Legendary Bird Trio".
-- If this card is Ritual Summoned: Your opponent discards 2 random cards. You can only activate this effect of
-- "Zapdos" once per turn.
-- Your opponent cannot target this card with card effects.
-- Once per turn: You can destroy 1 card on the field.
local s,id=GetID()
s.listed_names={1900000222}
function s.initial_effect(c)
	c:EnableReviveLimit()
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,1))
	e1:SetCategory(CATEGORY_HANDES)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_F)
	e1:SetCode(EVENT_SPSUMMON_SUCCESS)
	e1:SetCountLimit(1,id)
	e1:SetCondition(function(e) return e:GetHandler():IsRitualSummoned() end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_HANDES,nil,0,1-tp,2)
	end)
	e1:SetOperation(function(e,tp)
		local g=Duel.GetFieldGroup(tp,0,LOCATION_HAND)
		if #g==0 then return end
		local sg=g:RandomSelect(1-tp,math.min(2,#g))
		Duel.SendtoGrave(sg,REASON_EFFECT|REASON_DISCARD)
	end)
	c:RegisterEffect(e1)
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE)
	e2:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e2:SetRange(LOCATION_MZONE)
	e2:SetCode(EFFECT_CANNOT_BE_EFFECT_TARGET)
	e2:SetValue(aux.tgoval)
	c:RegisterEffect(e2)
	local e3=Effect.CreateEffect(c)
	e3:SetDescription(aux.Stringid(id,0))
	e3:SetCategory(CATEGORY_DESTROY)
	e3:SetType(EFFECT_TYPE_IGNITION)
	e3:SetRange(LOCATION_MZONE)
	e3:SetCountLimit(1)
	e3:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(aux.TRUE,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,1,nil) end
		Duel.SetOperationInfo(0,CATEGORY_DESTROY,nil,1,0,0)
	end)
	e3:SetOperation(function(e,tp)
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_DESTROY)
		local g=Duel.SelectMatchingCard(tp,aux.TRUE,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,1,1,nil)
		if #g>0 then Duel.HintSelection(g) Duel.Destroy(g,REASON_EFFECT) end
	end)
	c:RegisterEffect(e3)
end
