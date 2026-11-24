-- Team Rocket - Scientist (Normal Spell)
-- Banish 2 "Team Rocket" cards from your GY; add 1 Spell from your GY to your hand.
-- You can only activate 1 "Team Rocket - Scientist" per turn.
-- PATTERN: a cost that must leave something for the effect = aux.SelectUnselectGroup with a "rescon"
-- check (here: after banishing these 2, is there still a Spell in the GY to add?).
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_TOHAND)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetCountLimit(1,id,EFFECT_COUNT_CODE_OATH)
	e1:SetCost(s.cost)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end         -- checked in the cost
		Duel.SetOperationInfo(0,CATEGORY_TOHAND,nil,1,tp,LOCATION_GRAVE)
	end)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
function s.costfilter(c) return c:IsSetCard(SET_TEAM_ROCKET) and c:IsAbleToRemoveAsCost() end
function s.thfilter(c) return c:IsSpell() and c:IsAbleToHand() end
-- the 2 chosen cards must leave at least 1 Spell behind
function s.rescon(sg,e,tp,mg)
	return Duel.IsExistingMatchingCard(s.thfilter,tp,LOCATION_GRAVE,0,1,sg)
end
function s.cost(e,tp,eg,ep,ev,re,r,rp,chk)
	local g=Duel.GetMatchingGroup(s.costfilter,tp,LOCATION_GRAVE,0,nil)
	if chk==0 then return aux.SelectUnselectGroup(g,e,tp,2,2,s.rescon,0) end
	local sg=aux.SelectUnselectGroup(g,e,tp,2,2,s.rescon,1,tp,HINTMSG_REMOVE)
	Duel.Remove(sg,POS_FACEUP,REASON_COST)
end
function s.activate(e,tp)
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_ATOHAND)
	local g=Duel.SelectMatchingCard(tp,s.thfilter,tp,LOCATION_GRAVE,0,1,1,nil)
	if #g>0 then
		Duel.SendtoHand(g,nil,REASON_EFFECT)
		Duel.ConfirmCards(1-tp,g)
	end
end
