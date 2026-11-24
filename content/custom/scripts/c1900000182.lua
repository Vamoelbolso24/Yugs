-- Pokemon Center (Normal Spell)
-- If you have 6 or more Pokemon monsters in your GY: You can target 3 of them; add them to your hand.
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_TOHAND)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e1:SetCondition(function(e,tp) return Duel.GetMatchingGroupCount(s.poke,tp,LOCATION_GRAVE,0,nil)>=6 end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
		if chkc then return chkc:IsLocation(LOCATION_GRAVE) and chkc:IsControler(tp) and s.filter(chkc) end
		if chk==0 then return Duel.IsExistingTarget(s.filter,tp,LOCATION_GRAVE,0,3,nil) end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_ATOHAND)
		local g=Duel.SelectTarget(tp,s.filter,tp,LOCATION_GRAVE,0,3,3,nil)
		Duel.SetOperationInfo(0,CATEGORY_TOHAND,g,3,0,0)
	end)
	e1:SetOperation(function(e,tp)
		local g=Duel.GetTargetCards(e)
		if #g>0 then Duel.SendtoHand(g,nil,REASON_EFFECT) Duel.ConfirmCards(1-tp,g) end
	end)
	c:RegisterEffect(e1)
end
function s.poke(c) return c:IsSetCard(SET_POKEMON) and c:IsMonster() end
function s.filter(c) return s.poke(c) and c:IsAbleToHand() end
