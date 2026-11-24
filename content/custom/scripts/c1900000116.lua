-- Max Repel (Normal Spell)
-- Target 1 Pokemon monster you control, then target 1 monster with a lower Level than the first target; return
-- the second target to the hand, then its owner can Special Summon 1 Level 4 or lower monster from their hand
-- in Defense Position. You can only activate 1 "Max Repel" per turn.
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_TOHAND+CATEGORY_SPECIAL_SUMMON)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e1:SetCountLimit(1,id,EFFECT_COUNT_CODE_OATH)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
-- a monster with a lower Level than lv that can go back to the hand
function s.lowfilter(c,lv) return c:IsFaceup() and c:HasLevel() and c:GetLevel()<lv and c:IsAbleToHand() end
function s.pokefilter(c)
	return c:IsFaceup() and c:IsSetCard(SET_POKEMON) and c:HasLevel()
		and Duel.IsExistingTarget(s.lowfilter,0,LOCATION_MZONE,LOCATION_MZONE,1,c,c:GetLevel())
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	if chkc then return false end
	if chk==0 then return Duel.IsExistingTarget(s.pokefilter,tp,LOCATION_MZONE,0,1,nil) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TARGET)
	local tc1=Duel.SelectTarget(tp,s.pokefilter,tp,LOCATION_MZONE,0,1,1,nil):GetFirst()
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_RTOHAND)
	local tc2=Duel.SelectTarget(tp,s.lowfilter,tp,LOCATION_MZONE,LOCATION_MZONE,1,1,tc1,tc1:GetLevel()):GetFirst()
	e:SetLabelObject(tc2)                       -- the one to return
	Duel.SetOperationInfo(0,CATEGORY_TOHAND,tc2,1,0,0)
end
function s.spfilter(c,e,p) return c:IsLevelBelow(4) and c:IsCanBeSpecialSummoned(e,0,p,false,false,POS_FACEUP_DEFENSE) end
function s.activate(e,tp)
	local tc=e:GetLabelObject()
	if not (tc and tc:IsRelateToEffect(e)) then return end
	local p=tc:GetOwner()
	if Duel.SendtoHand(tc,nil,REASON_EFFECT)==0 or not tc:IsLocation(LOCATION_HAND) then return end
	-- its owner may Special Summon a Level 4 or lower monster from their hand
	if Duel.GetLocationCount(p,LOCATION_MZONE)<=0
		or not Duel.IsExistingMatchingCard(s.spfilter,p,LOCATION_HAND,0,1,nil,e,p) then return end
	if not Duel.SelectYesNo(p,aux.Stringid(id,0)) then return end
	Duel.BreakEffect()
	Duel.Hint(HINT_SELECTMSG,p,HINTMSG_SPSUMMON)
	local g=Duel.SelectMatchingCard(p,s.spfilter,p,LOCATION_HAND,0,1,1,nil,e,p)
	if #g>0 then Duel.SpecialSummon(g,0,p,p,false,false,POS_FACEUP_DEFENSE) end
end
