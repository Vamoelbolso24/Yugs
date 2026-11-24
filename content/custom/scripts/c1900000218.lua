-- Leftovers (Equip Spell)
-- Equip only to a Pokemon monster with 3000 or more DEF.
-- Once per turn, if the equipped monster would be destroyed by a card effect while in Defense Position, you can draw
-- 1 card instead, but if you do, during the End Phase, place 1 card from your hand on the bottom of the Deck,
-- otherwise destroy this card and lose 1000 LP.
local s,id=GetID()
function s.initial_effect(c)
	aux.AddEquipProcedure(c,0,function(tc) return tc:IsSetCard(SET_POKEMON) and tc:IsDefenseAbove(3000) end)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_EQUIP+EFFECT_TYPE_CONTINUOUS)
	e1:SetCode(EFFECT_DESTROY_REPLACE)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		local c=e:GetHandler()
		local tc=c:GetEquipTarget()
		if chk==0 then return tc and c:GetFlagEffect(id)==0 and tc:IsDefensePos() and tc:IsReason(REASON_EFFECT)
			and not tc:IsReason(REASON_REPLACE) and Duel.IsPlayerCanDraw(tp,1) end
		return Duel.SelectEffectYesNo(tp,c,aux.Stringid(id,0))
	end)
	e1:SetOperation(function(e,tp)
		local c=e:GetHandler()
		c:RegisterFlagEffect(id,RESET_EVENT|RESETS_STANDARD|RESET_PHASE|PHASE_END,0,1)
		Duel.Hint(HINT_CARD,0,id)
		Duel.Draw(tp,1,REASON_EFFECT)
		-- the price, in this turn's End Phase
		local e2=Effect.CreateEffect(c)
		e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
		e2:SetCode(EVENT_PHASE+PHASE_END)
		e2:SetCountLimit(1)
		e2:SetReset(RESET_PHASE|PHASE_END)
		e2:SetOperation(function(ef,p)
			Duel.Hint(HINT_CARD,0,id)
			-- Not optional: if you can place a card, you must; only if you can't, Leftovers goes and you lose 1000 LP
			local hand=Duel.GetMatchingGroup(Card.IsAbleToDeck,p,LOCATION_HAND,0,nil)
			local placed=false
			if #hand>0 then
				Duel.Hint(HINT_SELECTMSG,p,aux.Stringid(id,1))
				local g=hand:Select(p,1,1,nil)
				placed=Duel.SendtoDeck(g,nil,SEQ_DECKBOTTOM,REASON_EFFECT)>0
			end
			if not placed then
				if c:IsOnField() and c:GetFieldID()==ef:GetLabel() then Duel.Destroy(c,REASON_EFFECT) end
				Duel.SetLP(p,math.max(0,Duel.GetLP(p)-1000))
			end
		end)
		e2:SetLabel(c:GetFieldID())
		Duel.RegisterEffect(e2,tp)
		return true
	end)
	e1:SetValue(function(e,tc) return tc==e:GetHandler():GetEquipTarget() end)
	c:RegisterEffect(e1)
end
