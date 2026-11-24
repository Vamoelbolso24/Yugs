-- Fossil Restoration Center (Normal Spell)
-- Special Summon 1 "Fossil Pkmn" monster from your hand or either player's GY, ignoring its Summoning Conditions.
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_SPECIAL_SUMMON)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.GetLocationCount(tp,LOCATION_MZONE)>0
			and Duel.IsExistingMatchingCard(s.spfilter,tp,LOCATION_HAND|LOCATION_GRAVE,LOCATION_GRAVE,1,nil,e,tp) end
		Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,PLAYER_ALL,LOCATION_HAND|LOCATION_GRAVE)
	end)
	e1:SetOperation(function(e,tp)
		if Duel.GetLocationCount(tp,LOCATION_MZONE)<=0 then return end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
		local g=Duel.SelectMatchingCard(tp,aux.NecroValleyFilter(s.spfilter),tp,LOCATION_HAND|LOCATION_GRAVE,LOCATION_GRAVE,1,1,nil,e,tp)
		-- true,true = ignore its Summoning Conditions (including "must first be Special Summoned ...")
		if #g>0 then Duel.SpecialSummon(g,0,tp,tp,true,true,POS_FACEUP) end
	end)
	c:RegisterEffect(e1)
end
function s.spfilter(c,e,tp) return c:IsSetCard(SET_FOSSIL_PKMN) and c:IsMonster() and c:IsCanBeSpecialSummoned(e,0,tp,true,true) end
