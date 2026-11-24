-- Lickitung
-- You can toss 2 coins, and if the result is 2 Heads, your opponent skips their next Battle Phase.
-- You can only use this effect of "Lickitung" once per turn.
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_COIN)
	e1:SetType(EFFECT_TYPE_IGNITION)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCountLimit(1,id)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_COIN,nil,0,tp,2)
	end)
	e1:SetOperation(function(e,tp)
		local c1,c2=Duel.TossCoin(tp,2)
		if c1==COIN_HEADS and c2==COIN_HEADS then
			local e2=Effect.CreateEffect(e:GetHandler())
			e2:SetType(EFFECT_TYPE_FIELD)
			e2:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
			e2:SetCode(EFFECT_SKIP_BP)
			e2:SetTargetRange(0,1)
			e2:SetReset(RESET_PHASE|PHASE_END|RESET_OPPO_TURN)   -- their next turn
			Duel.RegisterEffect(e2,tp)
		end
	end)
	c:RegisterEffect(e1)
end
s.toss_coin=true
