-- Mother's love (Continuous Trap)
-- Activate this card by discarding 1 card, then target 1 "Marowak" monster in your GY; Special Summon it. It
-- becomes a Zombie monster, it is unaffected by your opponent's monster effects, and it cannot be targeted for an
-- attack, except by Zombie monsters. When this card leaves the field, destroy that monster. When that monster is
-- destroyed, destroy this card.
-- PATTERN: like the real "Call of the Haunted" (the trap and the monster are linked with SetCardTarget).
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_SPECIAL_SUMMON)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e1:SetCost(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(Card.IsDiscardable,tp,LOCATION_HAND,0,1,nil) end
		Duel.DiscardHand(tp,Card.IsDiscardable,1,1,REASON_COST|REASON_DISCARD)
	end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
		if chkc then return chkc:IsLocation(LOCATION_GRAVE) and chkc:IsControler(tp) and s.filter(chkc,e,tp) end
		if chk==0 then return Duel.GetLocationCount(tp,LOCATION_MZONE)>0 and Duel.IsExistingTarget(s.filter,tp,LOCATION_GRAVE,0,1,nil,e,tp) end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
		local g=Duel.SelectTarget(tp,s.filter,tp,LOCATION_GRAVE,0,1,1,nil,e,tp)
		Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,g,1,0,0)
	end)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
	-- This card leaves -> destroy the monster
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_CONTINUOUS)
	e2:SetCode(EVENT_LEAVE_FIELD_P)
	e2:SetOperation(function(e)
		local tc=e:GetHandler():GetFirstCardTarget()
		if tc and tc:IsLocation(LOCATION_MZONE) then e:SetLabelObject(tc) else e:SetLabelObject(nil) end
	end)
	c:RegisterEffect(e2)
	local e3=Effect.CreateEffect(c)
	e3:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_CONTINUOUS)
	e3:SetCode(EVENT_LEAVE_FIELD)
	e3:SetLabelObject(e2)
	e3:SetOperation(function(e)
		local tc=e:GetLabelObject():GetLabelObject()
		if tc and tc:IsLocation(LOCATION_MZONE) then Duel.Destroy(tc,REASON_EFFECT) end
	end)
	c:RegisterEffect(e3)
	-- The monster is destroyed -> destroy this card
	local e4=Effect.CreateEffect(c)
	e4:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e4:SetCode(EVENT_DESTROYED)
	e4:SetRange(LOCATION_SZONE)
	e4:SetCondition(function(e,tp,eg)
		local tc=e:GetHandler():GetFirstCardTarget()
		return tc and eg:IsContains(tc)
	end)
	e4:SetOperation(function(e) Duel.Destroy(e:GetHandler(),REASON_EFFECT) end)
	c:RegisterEffect(e4)
end
s.listed_series={SET_MAROWAK}
function s.filter(c,e,tp) return c:IsSetCard(SET_MAROWAK) and c:IsMonster() and c:IsCanBeSpecialSummoned(e,0,tp,false,false) end
function s.activate(e,tp)
	local c=e:GetHandler()
	local tc=Duel.GetFirstTarget()
	if not (c:IsRelateToEffect(e) and tc and tc:IsRelateToEffect(e)) then return end
	if Duel.SpecialSummonStep(tc,0,tp,tp,false,false,POS_FACEUP) then
		c:SetCardTarget(tc)
		local reset=RESET_EVENT|RESETS_STANDARD
		-- becomes a Zombie
		local e1=Effect.CreateEffect(c)
		e1:SetType(EFFECT_TYPE_SINGLE)
		e1:SetCode(EFFECT_CHANGE_RACE)
		e1:SetValue(RACE_ZOMBIE)
		e1:SetReset(reset)
		tc:RegisterEffect(e1,true)
		-- unaffected by the opponent's monster effects
		local e2=Effect.CreateEffect(c)
		e2:SetType(EFFECT_TYPE_SINGLE)
		e2:SetCode(EFFECT_IMMUNE_EFFECT)
		e2:SetValue(function(ef,te) return te:IsMonsterEffect() and te:GetOwnerPlayer()~=ef:GetHandlerPlayer() end)
		e2:SetReset(reset)
		tc:RegisterEffect(e2,true)
		-- only Zombies can attack it
		local e3=Effect.CreateEffect(c)
		e3:SetType(EFFECT_TYPE_SINGLE)
		e3:SetCode(EFFECT_CANNOT_BE_BATTLE_TARGET)
		e3:SetValue(function(ef,ac) return not ac:IsRace(RACE_ZOMBIE) end)
		e3:SetReset(reset)
		tc:RegisterEffect(e3,true)
	end
	Duel.SpecialSummonComplete()
end
