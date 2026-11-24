-- Hoenn Route 124 (Field Spell)
-- During your opponent's Standby Phase: You can Special Summon up to 2 "Tentacool" from your hand or GY.
-- During your End Phase: You can return 1 of your banished "Tentacool" or "Tentacruel" to the GY.
local s,id=GetID()
local TENTACOOL,TENTACRUEL=1900000118,1900000119
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	c:RegisterEffect(e1)
	-- Opponent's Standby Phase: up to 2 Tentacool
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,0))
	e2:SetCategory(CATEGORY_SPECIAL_SUMMON)
	e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_O)
	e2:SetCode(EVENT_PHASE+PHASE_STANDBY)
	e2:SetRange(LOCATION_FZONE)
	e2:SetCountLimit(1)
	e2:SetCondition(function(e,tp) return Duel.IsTurnPlayer(1-tp) end)
	e2:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.GetLocationCount(tp,LOCATION_MZONE)>0
			and Duel.IsExistingMatchingCard(s.spfilter,tp,LOCATION_HAND|LOCATION_GRAVE,0,1,nil,e,tp) end
		Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,tp,LOCATION_HAND|LOCATION_GRAVE)
	end)
	e2:SetOperation(function(e,tp)
		if not e:GetHandler():IsRelateToEffect(e) then return end
		local ft=math.min(2,Duel.GetLocationCount(tp,LOCATION_MZONE))
		if ft<=0 then return end
		if Duel.IsPlayerAffectedByEffect(tp,CARD_BLUEEYES_SPIRIT) then ft=1 end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
		local g=Duel.SelectMatchingCard(tp,aux.NecroValleyFilter(s.spfilter),tp,LOCATION_HAND|LOCATION_GRAVE,0,1,ft,nil,e,tp)
		if #g>0 then Duel.SpecialSummon(g,0,tp,tp,false,false,POS_FACEUP) end
	end)
	c:RegisterEffect(e2)
	-- Your End Phase: a banished Tentacool/Tentacruel back to the GY
	local e3=Effect.CreateEffect(c)
	e3:SetDescription(aux.Stringid(id,1))
	e3:SetCategory(CATEGORY_TOGRAVE)
	e3:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_O)
	e3:SetCode(EVENT_PHASE+PHASE_END)
	e3:SetRange(LOCATION_FZONE)
	e3:SetCountLimit(1)
	e3:SetCondition(function(e,tp) return Duel.IsTurnPlayer(tp) end)
	e3:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(s.rmfilter,tp,LOCATION_REMOVED,0,1,nil) end
	end)
	e3:SetOperation(function(e,tp)
		if not e:GetHandler():IsRelateToEffect(e) then return end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
		local g=Duel.SelectMatchingCard(tp,s.rmfilter,tp,LOCATION_REMOVED,0,1,1,nil)
		if #g>0 then Duel.SendtoGrave(g,REASON_EFFECT|REASON_RETURN) end
	end)
	c:RegisterEffect(e3)
end
s.listed_names={TENTACOOL,TENTACRUEL}
function s.spfilter(c,e,tp) return c:IsCode(TENTACOOL) and c:IsCanBeSpecialSummoned(e,0,tp,false,false) end
function s.rmfilter(c) return c:IsFaceup() and c:IsCode(TENTACOOL,TENTACRUEL) end
