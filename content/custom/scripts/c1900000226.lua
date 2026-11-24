-- Pokemon Master - Lance (Normal Spell)
-- Add 1 Level 7 or higher WIND non-Winged Beast Pokemon monster from your Deck to your hand.
-- If a Level 7 or higher WIND non-Winged Beast monster(s) would be destroyed by a card effect, you can banish this
-- card from your GY instead.
-- You can only use 1 "Pokemon Master - Lance" effect per turn, and only once that turn.
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_TOHAND+CATEGORY_SEARCH)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetCost(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.GetFlagEffect(tp,id)==0 end
		Duel.RegisterFlagEffect(tp,id,RESET_PHASE|PHASE_END,0,1)   -- uses this turn's "1 Lance effect"
	end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(s.thfilter,tp,LOCATION_DECK,0,1,nil) end
		Duel.SetOperationInfo(0,CATEGORY_TOHAND,nil,1,tp,LOCATION_DECK)
	end)
	e1:SetOperation(function(e,tp)
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_ATOHAND)
		local g=Duel.SelectMatchingCard(tp,s.thfilter,tp,LOCATION_DECK,0,1,1,nil)
		if #g>0 then Duel.SendtoHand(g,nil,REASON_EFFECT) Duel.ConfirmCards(1-tp,g) end
	end)
	c:RegisterEffect(e1)
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e2:SetCode(EFFECT_DESTROY_REPLACE)
	e2:SetRange(LOCATION_GRAVE)
	e2:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		local c=e:GetHandler()
		if chk==0 then return Duel.GetFlagEffect(tp,id)==0 and c:IsAbleToRemove() and eg:IsExists(s.repfilter,1,nil) end
		if not Duel.SelectEffectYesNo(tp,c,aux.Stringid(id,0)) then return false end
		Duel.RegisterFlagEffect(tp,id,RESET_PHASE|PHASE_END,0,1)
		return true
	end)
	e2:SetValue(function(e,tc) return s.repfilter(tc) end)
	e2:SetOperation(function(e) Duel.Remove(e:GetHandler(),POS_FACEUP,REASON_EFFECT|REASON_REPLACE) end)
	c:RegisterEffect(e2)
end
function s.dragonish(c) return c:IsLevelAbove(7) and c:IsAttribute(ATTRIBUTE_WIND) and not c:IsRace(RACE_WINGEDBEAST) end
function s.thfilter(c) return c:IsMonster() and c:IsSetCard(SET_POKEMON) and s.dragonish(c) and c:IsAbleToHand() end
function s.repfilter(c)
	return c:IsFaceup() and c:IsLocation(LOCATION_MZONE) and s.dragonish(c) and c:IsReason(REASON_EFFECT) and not c:IsReason(REASON_REPLACE)
end
