-- Thunder (Move) (Normal Spell)
-- Pay 1000 LP; toss a coin and call it, and if you call it right, destroy all monsters your opponent controls.
-- If "Rain Dance" is on the field, apply this effect without tossing a coin.
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_DESTROY+CATEGORY_COIN)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetCost(Cost.PayLP(1000))
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		local g=Duel.GetFieldGroup(tp,0,LOCATION_MZONE)
		if chk==0 then return #g>0 end
		Duel.SetOperationInfo(0,CATEGORY_DESTROY,g,#g,0,0)
		if not Pokemon.IsOnField(CARD_RAIN_DANCE) then Duel.SetOperationInfo(0,CATEGORY_COIN,nil,0,tp,1) end
	end)
	e1:SetOperation(function(e,tp)
		-- with Rain Dance (checked when it resolves) there's no coin toss
		if not Pokemon.IsOnField(CARD_RAIN_DANCE) and not Duel.CallCoin(tp) then return end
		Duel.Destroy(Duel.GetFieldGroup(tp,0,LOCATION_MZONE),REASON_EFFECT)
	end)
	c:RegisterEffect(e1)
end
s.listed_names={CARD_RAIN_DANCE}
s.toss_coin=true
