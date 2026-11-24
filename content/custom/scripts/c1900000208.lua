-- Jolteon
-- You can Special Summon this card (from your Deck) by Tributing 1 "Eevee" and discarding 1 "Thunder Stone".
-- You can Special Summon this card from your hand by Tributing 1 "Eevee" from your hand or field, or by banishing
-- 1 "Eevee" from your GY. You can only Special Summon "Jolteon" once per turn.
-- Your opponent cannot target this card with Trap effects.
-- Can attack all LIGHT monsters your opponent controls, once each.
-- Once per turn (Quick Effect): You can return this card to your hand, and if you do, Special Summon 1 Pokemon
-- monster from your hand other than "Jolteon", but it cannot declare an attack this turn.
local s,id=GetID()
s.listed_names={CARD_EEVEE,CARD_THUNDER_STONE}
function s.initial_effect(c)
	Pokemon.AddEeveelution(c,CARD_THUNDER_STONE)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCode(EFFECT_CANNOT_BE_EFFECT_TARGET)
	e1:SetValue(function(e,re,rp) return rp==1-e:GetHandlerPlayer() and re:IsActiveType(TYPE_TRAP) end)
	c:RegisterEffect(e1)
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE)
	e2:SetCode(EFFECT_ATTACK_ALL)
	e2:SetValue(function(e,tc) return tc:IsAttribute(ATTRIBUTE_LIGHT) end)
	c:RegisterEffect(e2)
	local e3=Effect.CreateEffect(c)
	e3:SetDescription(aux.Stringid(id,0))
	e3:SetCategory(CATEGORY_TOHAND+CATEGORY_SPECIAL_SUMMON)
	e3:SetType(EFFECT_TYPE_QUICK_O)
	e3:SetCode(EVENT_FREE_CHAIN)
	e3:SetRange(LOCATION_MZONE)
	e3:SetCountLimit(1)
	e3:SetHintTiming(0,TIMINGS_CHECK_MONSTER|TIMING_END_PHASE)
	e3:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		local c=e:GetHandler()
		if chk==0 then return c:IsAbleToHand() and Duel.GetMZoneCount(tp,c)>0
			and Duel.IsExistingMatchingCard(s.spfilter,tp,LOCATION_HAND,0,1,nil,e,tp) end
		Duel.SetOperationInfo(0,CATEGORY_TOHAND,c,1,0,0)
		Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,tp,LOCATION_HAND)
	end)
	e3:SetOperation(function(e,tp)
		local c=e:GetHandler()
		if not (c:IsRelateToEffect(e) and Duel.SendtoHand(c,nil,REASON_EFFECT)>0 and c:IsLocation(LOCATION_HAND)) then return end
		if Duel.GetLocationCount(tp,LOCATION_MZONE)<=0 then return end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
		local tc=Duel.SelectMatchingCard(tp,s.spfilter,tp,LOCATION_HAND,0,1,1,nil,e,tp):GetFirst()
		if tc and Duel.SpecialSummon(tc,0,tp,tp,false,false,POS_FACEUP)>0 then
			local e1=Effect.CreateEffect(c)
			e1:SetType(EFFECT_TYPE_SINGLE)
			e1:SetCode(EFFECT_CANNOT_ATTACK_ANNOUNCE)
			e1:SetReset(RESETS_STANDARD_PHASE_END)
			tc:RegisterEffect(e1)
		end
	end)
	c:RegisterEffect(e3)
end
function s.spfilter(c,e,tp) return c:IsSetCard(SET_POKEMON) and c:IsMonster() and not c:IsCode(id) and c:IsCanBeSpecialSummoned(e,0,tp,false,false) end
