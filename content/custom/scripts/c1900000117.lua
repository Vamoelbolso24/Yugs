-- Repel (Continuous Spell)
-- Destroy this card during your 4th Standby Phase after its activation.
-- Once per turn, during your Draw Phase, if you draw a monster for your normal draw: You can reveal it;
-- place it on the bottom of the Deck, and if you do, draw 1 card.
local s,id=GetID()
function s.initial_effect(c)
	-- Activate + countdown (your Standby Phases)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		local c=e:GetHandler()
		c:SetTurnCounter(0)
		local e2=Effect.CreateEffect(c)
		e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
		e2:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
		e2:SetCode(EVENT_PHASE+PHASE_STANDBY)
		e2:SetRange(LOCATION_SZONE)
		e2:SetCountLimit(1)
		e2:SetCondition(function(e,tp) return Duel.IsTurnPlayer(tp) end)
		e2:SetOperation(function(e)
			local c=e:GetHandler()
			local ct=c:GetTurnCounter()+1
			c:SetTurnCounter(ct)
			if ct>=4 then Duel.Destroy(c,REASON_RULE) end
		end)
		e2:SetReset(RESET_EVENT|RESETS_STANDARD)
		c:RegisterEffect(e2)
	end)
	c:RegisterEffect(e1)
	-- Normal draw was a monster: put it on the bottom, draw again
	local e3=Effect.CreateEffect(c)
	e3:SetDescription(aux.Stringid(id,0))
	e3:SetCategory(CATEGORY_DRAW)
	e3:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_O)
	e3:SetCode(EVENT_DRAW)
	e3:SetRange(LOCATION_SZONE)
	e3:SetCountLimit(1)
	e3:SetCondition(function(e,tp,eg,ep,ev,re,r)
		return ep==tp and r==REASON_RULE and Duel.GetCurrentPhase()==PHASE_DRAW   -- the normal draw
			and eg:IsExists(Card.IsMonster,1,nil)
	end)
	e3:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsPlayerCanDraw(tp,1) end
		local tc=eg:Filter(Card.IsMonster,nil):GetFirst()
		Duel.SetTargetCard(tc)
		Duel.SetOperationInfo(0,CATEGORY_DRAW,nil,0,tp,1)
	end)
	e3:SetOperation(function(e,tp)
		local tc=Duel.GetFirstTarget()
		if not (e:GetHandler():IsRelateToEffect(e) and tc and tc:IsLocation(LOCATION_HAND)) then return end
		Duel.ConfirmCards(1-tp,tc)                -- reveal it
		Duel.ShuffleHand(tp)
		if Duel.SendtoDeck(tc,nil,SEQ_DECKBOTTOM,REASON_EFFECT)>0 and tc:IsLocation(LOCATION_DECK) then
			Duel.Draw(tp,1,REASON_EFFECT)
		end
	end)
	c:RegisterEffect(e3)
end
